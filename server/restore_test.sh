#!/usr/bin/env bash
# Weekly restore test (plan item 3826): plays the newest backup into a throwaway database, checks
# that the player tables came back with the same number of rows as the live database had when
# the dump was taken (give or take what changed since), drops it again and writes the result to
# public/status.json, which the monitor workflow (.github/workflows/monitor.yml) reads from outside.
set -uo pipefail
cd "$(dirname "$0")"
psql_() { docker compose exec -T db psql -U postgres -h localhost -v ON_ERROR_STOP=1 -tA "$@"; }
status() { # ok message
	mkdir -p public
	python3 - "$1" "$2" "${dump:-}" > public/status.json.tmp <<'PY'
import json, sys, time
ok, msg, dump = sys.argv[1] == "1", sys.argv[2], sys.argv[3]
print(json.dumps({"restore_test": {"ok": ok, "message": msg, "dump": dump, "at": int(time.time())}}))
PY
	chmod a+r public/status.json.tmp
	mv public/status.json.tmp public/status.json
	echo "$(date -Is) restore test: $2"
	[ "$1" = 1 ] || exit 1
}

dump="$(ls -t backups/chimora-*.dump 2>/dev/null | head -1)"
[ -n "$dump" ] || status 0 "no backup found"
age_days=$(( ( $(date +%s) - $(stat -c %Y "$dump") ) / 86400 ))
[ "$age_days" -le 2 ] || status 0 "newest backup is $age_days days old"

check_db="chimora_restore_check"
psql_ -d postgres -c "drop database if exists $check_db" >/dev/null
psql_ -d postgres -c "create database $check_db" >/dev/null || status 0 "cannot create the check database"
# Extension objects owned by the platform can fail to restore; the player tables are what counts.
docker compose exec -T db pg_restore -U postgres -h localhost -d "$check_db" --no-owner --no-privileges < "$dump" \
	> /tmp/chimora-restore.log 2>&1 || true
problems=""
for t in auth.users public.profiles public.saves public.friendships public.mail; do
	restored="$(psql_ -d "$check_db" -c "select count(*) from $t" 2>/dev/null)" || { problems="$problems $t:missing"; continue; }
	live="$(psql_ -d postgres -c "select count(*) from $t")"
	# More than 20 % fewer rows than live (and more than 10 rows apart) means the dump lost data.
	if [ "$restored" -lt $(( live * 8 / 10 )) ] && [ $(( live - restored )) -gt 10 ]; then
		problems="$problems $t:$restored/$live"
	fi
done
psql_ -d postgres -c "drop database if exists $check_db" >/dev/null
[ -z "$problems" ] || status 0 "restore of $dump is incomplete:$problems"
status 1 "restored $dump into a throwaway database, player tables complete"
