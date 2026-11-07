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
	# The build image has wget but neither curl nor python.
	conf="$(wget -qO- --tries=3 --timeout=30 "${server%/}/chimora.json" 2>/dev/null || curl -fsS --retry 3 "${server%/}/chimora.json")" || { echo "::error::Could not read ${server%/}/chimora.json"; exit 1; }
	conf="$(printf '%s' "$conf" | tr -d '\n')"
	url="$(printf '%s' "$conf" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
	key="$(printf '%s' "$conf" | sed -n 's/.*"anon_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
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
printf '{"url": "%s", "anon_key": "%s"}\n' "${url%/}" "$key" > data/online.json
echo "Server address written for $url"
