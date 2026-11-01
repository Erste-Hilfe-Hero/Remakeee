#!/usr/bin/env bash
# Writes data/online.json (server address for the build). Either from the CHIMORA_SERVER secret
# (address of our own server, e.g. https://1-2-3-4.sslip.io; the anon key is read from
# <address>/chimora.json), or from SUPABASE_URL and SUPABASE_ANON_KEY (a Supabase Cloud project).
# The anon key is public by design; the database functions enforce every rule. Without any of
# these the build uses the local test server on the phone.
# Usage: tools/online/write_config.sh [--require]
set -euo pipefail
cd "$(dirname "$0")/../.."
url="${SUPABASE_URL:-}"
key="${SUPABASE_ANON_KEY:-}"
server="${CHIMORA_SERVER:-}"
if [ -n "$server" ] && { [ -z "$url" ] || [ -z "$key" ]; }; then
	case "$server" in https://*) ;; *) server="https://$server" ;; esac
	conf="$(curl -fsS --retry 3 "${server%/}/chimora.json")" || { echo "::error::Could not read ${server%/}/chimora.json"; exit 1; }
	url="$(printf '%s' "$conf" | python3 -c 'import json,sys;print(json.load(sys.stdin)["url"])')"
	key="$(printf '%s' "$conf" | python3 -c 'import json,sys;print(json.load(sys.stdin)["anon_key"])')"
fi
if [ -z "$url" ] || [ -z "$key" ]; then
	if [ "${1:-}" = "--require" ]; then
		echo "::error::Set the CHIMORA_SERVER secret (or SUPABASE_URL and SUPABASE_ANON_KEY) for store builds (docs/ONLINE.md)."
		exit 1
	fi
	echo "No server secrets: this build uses the local test server."
	exit 0
fi
case "$url" in https://*) ;; *) echo "::error::SUPABASE_URL must start with https://"; exit 1 ;; esac
python3 - "$url" "$key" <<'PY'
import json, sys
json.dump({"url": sys.argv[1].rstrip("/"), "anon_key": sys.argv[2]}, open("data/online.json", "w"))
PY
echo "Server address written for $url"
