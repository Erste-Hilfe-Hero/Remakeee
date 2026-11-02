#!/usr/bin/env bash
# Adds (or updates) the Chimora site to another Caddy that already runs on this machine, without
# touching its other sites. Safety rules:
#   1. Only proceed when the running config equals the Caddyfile on disk, so a reload loses nothing.
#   2. Back up the file, change only the block between the chimora markers, validate before reload.
#   3. On any failure put the backup back.
# Usage: PROXY_CONTAINER=name PROXY_CADDYFILE=/host/path/Caddyfile DOMAIN=host bash proxy_site.sh
set -euo pipefail
proxy="${PROXY_CONTAINER:?}"
file="${PROXY_CADDYFILE:?}"
domain="${DOMAIN:?}"
inner="${PROXY_CADDYFILE_INNER:-/etc/caddy/Caddyfile}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

docker exec "$proxy" caddy adapt --config "$inner" --adapter caddyfile > "$work/disk.json" 2>/dev/null
docker exec "$proxy" wget -qO- http://127.0.0.1:2019/config/ > "$work/live.json"
if ! python3 - "$work/disk.json" "$work/live.json" <<'PY'
import json, sys
a, b = (json.load(open(p)) for p in sys.argv[1:3])
for d in (a, b):
    d.pop("admin", None)
sys.exit(0 if a == b else 1)
PY
then
	echo "The running proxy config differs from $file. Not touching it." >&2
	exit 1
fi

stamp="$(date +%Y%m%d-%H%M%S)"
cp -p "$file" "$file.before-chimora-$stamp"
python3 - "$file" "$domain" <<'PY'
import re, sys
path, domain = sys.argv[1], sys.argv[2]
text = open(path).read()
text = re.sub(r"\n?# chimora-begin.*?# chimora-end\n", "\n", text, flags=re.S)
block = (f"\n# chimora-begin (managed by Remakeee server/proxy_site.sh)\n"
         f"{domain} {{\n\tencode gzip\n\treverse_proxy chimora-gateway:80\n}}\n# chimora-end\n")
# Write in place: the file is bind-mounted, so its inode must stay the same.
with open(path, "r+") as f:
    f.seek(0)
    f.write(text.rstrip("\n") + "\n" + block)
    f.truncate()
PY

restore() {
	echo "Restoring the previous proxy config." >&2
	cat "$file.before-chimora-$stamp" > "$file"
	docker exec "$proxy" caddy reload --config "$inner" --adapter caddyfile >/dev/null 2>&1 || true
}
if ! docker exec "$proxy" caddy validate --config "$inner" --adapter caddyfile >/dev/null 2>"$work/err"; then
	cat "$work/err" >&2
	restore
	exit 1
fi
if ! docker exec "$proxy" caddy reload --config "$inner" --adapter caddyfile; then
	restore
	exit 1
fi
echo "Proxy now serves $domain (backup: $file.before-chimora-$stamp)"
