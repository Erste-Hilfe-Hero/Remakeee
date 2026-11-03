#!/usr/bin/env bash
# Adds (or updates) the Chimora site to another Caddy that already runs on this machine, without
# touching its other sites. It works on the RUNNING config (Caddy admin API), never on files, so
# whatever that proxy has loaded stays exactly as it is. Safety rules:
#   1. Read the live config and keep a copy of it.
#   2. Change only Chimora's own pieces: one route matching DOMAIN on the HTTPS server, and (only
#      if that server already pins TLS policies) one policy matching SNI DOMAIN.
#   3. Load it with `caddy reload` (validated, graceful). If anything fails, load the copy again.
# Running it again replaces Chimora's pieces; when nothing would change it does nothing.
# Usage: PROXY_CONTAINER=name DOMAIN=host bash proxy_site.sh
set -euo pipefail
proxy="${PROXY_CONTAINER:?}"
domain="${DOMAIN:?}"
listen="${PROXY_HTTPS_LISTEN:-:443}"
upstream="${CHIMORA_UPSTREAM:-chimora-gateway:80}"
keep="${PROXY_BACKUP_DIR:-$(cd "$(dirname "$0")" && pwd)/backups}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$keep"

admin() { docker exec "$proxy" wget -qO- "http://127.0.0.1:2019$1"; }
load() {
	docker exec -i "$proxy" sh -c 'cat > /tmp/chimora-load.json' < "$1"
	docker exec "$proxy" caddy reload --config /tmp/chimora-load.json
}

admin /config/ > "$work/live.json"
set +e
python3 - "$work/live.json" "$work/new.json" "$domain" "$listen" "$upstream" > "$work/summary" <<'PY'
import json, sys
live_path, new_path, domain, listen, upstream = sys.argv[1:6]
cfg = json.load(open(live_path))
servers = cfg.get("apps", {}).get("http", {}).get("servers", {})
names = [n for n, s in servers.items() if listen in s.get("listen", []) or any(l.endswith(listen) for l in s.get("listen", []))]
if len(names) != 1:
    print(f"Expected one server listening on {listen}, found {names}.", file=sys.stderr)
    sys.exit(2)
srv = servers[names[0]]

def ours_route(r):
    return r.get("match") == [{"host": [domain]}]
def ours_policy(p):
    return p.get("match") == {"sni": [domain]}

before = json.dumps(cfg, sort_keys=True)
routes = [r for r in srv.get("routes", []) if not ours_route(r)]
routes.insert(0, {
    "match": [{"host": [domain]}],
    "handle": [{"handler": "reverse_proxy", "upstreams": [{"dial": upstream}]}],
    "terminal": True,
})
srv["routes"] = routes
policies = srv.get("tls_connection_policies")
if policies:
    # The server pins its policies; without one for our name a handshake could get the wrong
    # certificate. An empty policy lets Caddy pick the managed certificate for this SNI.
    srv["tls_connection_policies"] = [{"match": {"sni": [domain]}}] + [p for p in policies if not ours_policy(p)]
after = json.dumps(cfg, sort_keys=True)
json.dump(cfg, open(new_path, "w"))
print(f"server {names[0]}: {len(routes) - 1} other routes kept, policies {'pinned' if policies else 'default'}")
sys.exit(0 if before != after else 3)
PY
rc=$?
summary="$(cat "$work/summary" 2>/dev/null || true)"
set -e
if [ "$rc" = 3 ]; then
	[ -n "${QUIET:-}" ] || echo "Proxy already serves $domain. Nothing to do."
	exit 0
fi
[ "$rc" = 0 ] || exit "$rc"
echo "$(date -Is) route for $domain missing or changed, adding it ($summary)"

stamp="$(date +%Y%m%d-%H%M%S)"
cp "$work/live.json" "$keep/proxy-live-before-chimora-$stamp.json"

restore() {
	echo "Restoring the previous proxy config." >&2
	load "$keep/proxy-live-before-chimora-$stamp.json" >/dev/null 2>&1 || true
}
if ! load "$work/new.json"; then
	restore
	exit 1
fi
admin /config/ > "$work/check.json"
if ! python3 - "$work/live.json" "$work/check.json" "$domain" <<'PY'
import json, sys
old, new = (json.load(open(p)) for p in sys.argv[1:3])
domain = sys.argv[3]
def strip(cfg):
    for s in cfg.get("apps", {}).get("http", {}).get("servers", {}).values():
        s["routes"] = [r for r in s.get("routes", []) if r.get("match") != [{"host": [domain]}]]
        if "tls_connection_policies" in s:
            s["tls_connection_policies"] = [p for p in s["tls_connection_policies"] if p.get("match") != {"sni": [domain]}]
    cfg.pop("admin", None)
    return json.dumps(cfg, sort_keys=True)
found = any(r.get("match") == [{"host": [domain]}]
            for s in new.get("apps", {}).get("http", {}).get("servers", {}).values() for r in s.get("routes", []))
sys.exit(0 if found and strip(old) == strip(new) else 1)
PY
then
	echo "The loaded config is not what was planned." >&2
	restore
	exit 1
fi
echo "Proxy now serves $domain (previous live config: $keep/proxy-live-before-chimora-$stamp.json)"
