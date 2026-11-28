#!/usr/bin/env bash
# End-to-end check of the battle referee (plan area 7): a throwaway local Postgres with all
# migrations, three uploaded battles (honest, tampered, broken), one run of server/referee/run.sh
# as the database user chimora_referee, then the states must be ok, mismatch and error.
# Usage: tools/online/test_referee.sh [godot]   (needs PostgreSQL server binaries and Godot 4.7.2)
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$(pwd)"
godot="${1:-godot}"
bin="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)"
[ -n "$bin" ] || { echo "PostgreSQL server binaries not found"; exit 1; }
dir="$(mktemp -d)"
chmod 755 "$dir"
cleanup() {
	"$bin/pg_ctl" -D "$dir/data" -m immediate stop >/dev/null 2>&1 || true
	case "$dir" in /tmp/*) rm -rf -- "$dir" ;; esac
}
trap cleanup EXIT
run() { if [ "$(id -u)" = 0 ]; then chown -R postgres "$dir/data" "$dir/sock"; su postgres -c "$*"; else sh -c "$*"; fi; }
mkdir -p "$dir/data" "$dir/sock"
run "'$bin/initdb' -D '$dir/data' -A trust -U postgres >/dev/null"
run "'$bin/pg_ctl' -D '$dir/data' -o \"-k $dir/sock -c listen_addresses=''\" -l '$dir/sock/log' -w start >/dev/null"
psql_() { PGOPTIONS="-c client_min_messages=warning" psql -X -h "$dir/sock" -U postgres -d postgres -v ON_ERROR_STOP=1 -qAt "$@"; }
psql_ -f tools/online/sql_test/stub_supabase.sql >/dev/null
for f in supabase/migrations/*.sql; do psql_ -f "$f" >/dev/null; done
psql_ -c "alter role chimora_referee login"
python3 tools/online/game_data_sql.py data/spirlings.json | psql_ >/dev/null

"$godot" --headless --path . --import >/dev/null 2>&1 || true
"$godot" --headless --path . -s res://server/referee/referee.gd -- sample "$dir/sample.json" >/dev/null 2>&1
[ -s "$dir/sample.json" ] || { echo "sample battles were not written"; exit 1; }

{
	echo "insert into auth.users (id) values ('40000000-0000-0000-0000-00000000000a');"
	echo "set role authenticated;"
	echo "select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000a', false);"
	printf '%s' "select public.battle_submit('echo_duel', 'test', x->'replay', x->'claim') from jsonb_array_elements(\$s\$"
	cat "$dir/sample.json"
	echo "\$s\$::jsonb) with ordinality t(x, n) order by n;"
} | psql_ >/dev/null

PGHOST="$dir/sock" PGUSER=chimora_referee PGDATABASE=postgres GAME_DIR="$root" GODOT="$godot" \
	bash server/referee/run.sh --once

got="$(psql_ -c "select string_agg(status, ',' order by id) from public.battles")"
echo "states: $got"
[ "$got" = "ok,mismatch,error" ] || { echo "referee gave the wrong verdicts"; exit 1; }
left="$(psql_ -c "select count(*) from public.battle_queue")"
[ "$left" = "0" ] || { echo "queue not empty"; exit 1; }
# Live duels (Online 100, point 3): the referee plays the rounds the server kept and says who won,
# or that the duel is not over yet.
cat > "$dir/live.json" <<'LIVE'
[{"id": 1, "replay": {"teams": [], "inputs": []}, "claim": {"expect": {"live": true, "seed": 123,
   "teams": [[{"species": "Kindlop", "level": 40, "moves": []}], [{"species": "Mossling", "level": 3, "moves": []}]],
   "moves": {"1": [{"k": 0, "m": 0, "s": -1}, {"k": 0, "m": 0, "s": -1}]}}}},
 {"id": 2, "replay": {"teams": [], "inputs": []}, "claim": {"expect": {"live": true, "seed": 123,
   "teams": [[{"species": "Kindlop", "level": 40, "moves": []}], [{"species": "Mossling", "level": 3, "moves": []}]],
   "moves": {}}}}]
LIVE
"$godot" --headless --path . -s res://server/referee/referee.gd -- check "$dir/live.json" "$dir/live_out.json" >/dev/null 2>&1
live="$(python3 -c "import json,sys; r=json.load(open(sys.argv[1])); print(','.join('%s:%s:%s' % (x['verdict'], x['detail'].get('finished'), x['detail'].get('winner')) for x in r))" "$dir/live_out.json")"
echo "live duels: $live"
[ "$live" = "ok:True:0,ok:False:-1" ] || { echo "referee gave the wrong live duel verdicts"; exit 1; }

# The fair league rows of the game and of the database are the same for every species (item 2748).
"$godot" --headless --path . -s res://server/referee/referee.gd -- fair "$dir/fair.json" >/dev/null 2>&1
[ -s "$dir/fair.json" ] || { echo "fair rows were not written"; exit 1; }
diff="$({
	printf '%s' "select string_agg(x->>'species', ', ') from jsonb_array_elements(\$f\$"
	cat "$dir/fair.json"
	echo "\$f\$::jsonb) x where public._league_fair_row(x->>'species', x->'ask') <> x->'row'
		or public._league_fair_row(x->>'species', '[]') <> x->'none';"
} | psql_)"
count="$(psql_ -c "select count(*) from public.game_species")"
echo "fair rows compared for $count species"
[ -z "$diff" ] || { echo "fair rows differ for: $diff"; exit 1; }
echo "Referee test OK"
