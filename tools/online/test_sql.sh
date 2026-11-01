#!/usr/bin/env bash
# Runs the Supabase migrations and their tests on a throwaway local Postgres.
# Usage: tools/online/test_sql.sh   (needs the PostgreSQL server binaries, e.g. postgresql-16)
set -euo pipefail
cd "$(dirname "$0")/../.."
bin="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)"
[ -n "$bin" ] || { echo "PostgreSQL server binaries not found"; exit 1; }
dir="$(mktemp -d)"
trap '"$bin/pg_ctl" -D "$dir/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$dir"' EXIT
run() { if [ "$(id -u)" = 0 ]; then chown -R postgres "$dir"; su postgres -c "$*"; else sh -c "$*"; fi; }
mkdir -p "$dir/data" "$dir/sock"
run "'$bin/initdb' -D '$dir/data' -A trust -U postgres >/dev/null"
run "'$bin/pg_ctl' -D '$dir/data' -o \"-k $dir/sock -c listen_addresses=''\" -l '$dir/log' -w start >/dev/null"
psql_() { PGOPTIONS="-c client_min_messages=warning" psql -h "$dir/sock" -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"; }
psql_ -f tools/online/sql_test/stub_supabase.sql
for f in supabase/migrations/*.sql; do
	psql_ -f "$f"
done
# Migrations must be re-runnable (Supabase applies each once, but local resets replay them).
for f in supabase/migrations/*.sql; do
	psql_ -f "$f"
done
for t in tools/online/sql_test/test_*.sql; do
	echo "== $t"
	psql_ -f "$t"
done
echo "SQL tests OK"
