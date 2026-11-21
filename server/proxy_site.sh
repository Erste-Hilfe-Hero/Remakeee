#!/usr/bin/env bash
# Adds the Chimora site to another Caddy that already runs on this machine, without touching its
# other sites. Two parts:
# A. Running config (Caddy admin API), so Chimora works now even though that proxy's running config
#    differs from its files:
#   1. Read the live config and keep a copy of it.
#   2. Add only Chimora's own pieces: one route matching DOMAIN on the HTTPS server (unless one is
#      there already) and, if that server pins TLS policies, one policy matching SNI DOMAIN.
#   3. Load it with `caddy reload` (validated, graceful). If anything fails, load the copy again.
# B. Its Caddyfile on the host (PROXY_CADDYFILE, optional), so the site survives when that proxy's own
#    deploys load the file again: one block between "# chimora-begin" and "# chimora-end", validated
#    inside the container first, written in place (same inode for the bind mount). The file is NOT
#    loaded here; the other service's deploys do that.
# When nothing would change it does nothing.
# Usage: PROXY_CONTAINER=name DOMAIN=host [PROXY_CADDYFILE=/host/path/Caddyfile] bash proxy_site.sh
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
routes = srv.get("routes", [])
if not any(ours_route(r) for r in routes):
    # A route for DOMAIN may already come from the proxy's Caddyfile (part B); then it stays.
    routes.insert(0, {
        "match": [{"host": [domain]}],
        "handle": [{"handler": "reverse_proxy", "upstreams": [{"dial": upstream}]}],
        "terminal": True,
    })
srv["routes"] = routes
policies = srv.get("tls_connection_policies")
if policies and not any(ours_policy(p) for p in policies):
    # The server pins its policies; without one for our name a handshake could get the wrong
    # certificate. An empty policy lets Caddy pick the managed certificate for this SNI.
    srv["tls_connection_policies"] = [{"match": {"sni": [domain]}}] + policies
after = json.dumps(cfg, sort_keys=True)
json.dump(cfg, open(new_path, "w"))
print(f"server {names[0]}: {len(routes) - 1} other routes kept, policies {'pinned' if policies else 'default'}")
sys.exit(0 if before != after else 3)
PY
rc=$?
summary="$(cat "$work/summary" 2>/dev/null || true)"
set -e
persist_file() {
	local file="${PROXY_CADDYFILE:-}"
	[ -n "$file" ] || return 0
	[ -f "$file" ] || { echo "No Caddyfile at $file, skipping the file part." >&2; return 0; }
	python3 - "$file" "$domain" "$upstream" "$work/file.new" <<'PY'
import re, sys
path, domain, upstream, out = sys.argv[1:5]
text = open(path).read()
base = re.sub(r"\n*# chimora-begin.*?# chimora-end\n?", "\n", text, flags=re.S).rstrip("\n") + "\n"
block = ("\n# chimora-begin (Remakeee server/proxy_site.sh; keep it, this proxy's deploys load this file)\n"
         f"{domain} {{\n\treverse_proxy {upstream}\n}}\n# chimora-end\n")
open(out, "w").write(base + block)
sys.exit(0 if base + block != text else 3)
PY
	local frc=$?
	if [ "$frc" = 3 ]; then
		[ -n "${QUIET:-}" ] || echo "Caddyfile already has the $domain block."
		return 0
	fi
	[ "$frc" = 0 ] || return "$frc"
	docker exec -i "$proxy" sh -c 'cat > /tmp/chimora-file-check.caddy' < "$work/file.new"
	if ! docker exec "$proxy" caddy validate --config /tmp/chimora-file-check.caddy --adapter caddyfile >/dev/null 2>"$work/verr"; then
		cat "$work/verr" >&2
		echo "The Caddyfile with the $domain block does not validate. File left unchanged." >&2
		return 1
	fi
	local stamp
	stamp="$(date +%Y%m%d-%H%M%S)"
	cp -p "$file" "$keep/proxy-caddyfile-before-chimora-$stamp"
	cat "$work/file.new" > "$file"   # in place: the container's bind mount keeps seeing the file
	echo "$(date -Is) $domain block added to $file (not loaded; backup: $keep/proxy-caddyfile-before-chimora-$stamp)"
}

set +e
persist_file
prc=$?
set -e
[ "$prc" = 0 ] || echo "Warning: the file part failed; the running config is still handled." >&2

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
