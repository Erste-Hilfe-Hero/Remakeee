#!/usr/bin/env bash
# Applies every file in supabase/migrations that has not run yet, in name order, each in one
# transaction. Applied files are listed in chimora_meta.migrations (not reachable from the API).
set -euo pipefail
cd "$(dirname "$0")"
dir="../supabase/migrations"
user="${MIGRATE_USER:-postgres}"
psql_db() { docker compose exec -T db psql -U "$user" -h localhost -d postgres -v ON_ERROR_STOP=1 -q "$@"; }

psql_db -c "create schema if not exists chimora_meta;
	revoke all on schema chimora_meta from public;
	create table if not exists chimora_meta.migrations (name text primary key, applied_at timestamptz not null default now());"

for f in "$dir"/*.sql; do
	name="$(basename "$f")"
	done_already="$(psql_db -tAc "select 1 from chimora_meta.migrations where name = '$name'")"
	if [ "$done_already" = "1" ]; then
		continue
	fi
	echo "Applying $name"
	{ cat "$f"; echo; echo "insert into chimora_meta.migrations (name) values ('$name');"; } | psql_db -1
done
# PostgREST caches the list of functions: tell it about new ones.
psql_db -c "notify pgrst, 'reload schema';"
echo "Database is up to date."
