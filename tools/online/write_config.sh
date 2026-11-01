#!/usr/bin/env bash
# Writes data/online.json (server address for the build) from the SUPABASE_URL and
# SUPABASE_ANON_KEY secrets. The anon key is public by design; the database functions
# enforce every rule. Without the secrets the build uses the local test server on the phone.
# Usage: tools/online/write_config.sh [--require]
set -euo pipefail
cd "$(dirname "$0")/../.."
url="${SUPABASE_URL:-}"
key="${SUPABASE_ANON_KEY:-}"
if [ -z "$url" ] || [ -z "$key" ]; then
	if [ "${1:-}" = "--require" ]; then
		echo "::error::SUPABASE_URL and SUPABASE_ANON_KEY must be set for store builds (docs/ONLINE.md)."
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
