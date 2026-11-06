#!/usr/bin/env bash
# Daily deletion run (plan area 9, items 3899, 3900, 3904): deletes everything whose period in
# docs/legal/DATENSCHUTZ.md has passed. Runs from cron (server/setup.sh); safe to run by hand.
set -euo pipefail
cd "$(dirname "$0")"
out="$(docker compose exec -T db psql -U postgres -h localhost -d postgres -v ON_ERROR_STOP=1 -tAc \
	"select public._daily_cleanup() || jsonb_build_object('web_accounts', public._web_cleanup())")"
echo "$(date -Is) cleanup $out"
if echo "$out" | grep -q '"audit_log": -1'; then
	echo "$(date -Is) cleanup: no right to delete auth.audit_log_entries" >&2
	exit 1
fi
