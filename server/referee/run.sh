#!/usr/bin/env bash
# Battle referee loop (plan area 7, items 2687-2690, 2703). Reads up to BATCH battles from
# battle_queue, plays them again with the game's own battle code (referee.gd + BattleReferee)
# and writes ok / mismatch / error into battle_results. Logs in as the database user
# chimora_referee (PGHOST, PGUSER, PGPASSWORD, PGDATABASE from the environment), which may only
# read battle_queue and write battle_results.
#   run.sh          # forever, every INTERVAL seconds
#   run.sh --once   # one batch (tests)
set -euo pipefail
game="${GAME_DIR:-/game}"
godot="${GODOT:-godot}"
batch="${BATCH:-20}"
interval="${INTERVAL:-2}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
q() { psql -X -v ON_ERROR_STOP=1 -qAt "$@"; }

one_batch() {
	q -c "select coalesce(json_agg(json_build_object('id', battle_id, 'replay', replay, 'claim', claim)), '[]')
		from (select battle_id, replay, claim from public.battle_queue order by battle_id limit $batch) b" > "$work/in.json"
	if [ "$(cat "$work/in.json")" = "[]" ]; then
		return 1
	fi
	rm -f "$work/out.json"
	if ! timeout 120 "$godot" --headless --path "$game" -s res://server/referee/referee.gd -- check "$work/in.json" "$work/out.json" >"$work/log" 2>&1 \
			|| [ ! -s "$work/out.json" ]; then
		# The game code failed on this batch: every battle in it gets "error", so the queue moves on.
		tail -5 "$work/log" >&2 || true
		q -c "select coalesce(json_agg(json_build_object('id', battle_id, 'verdict', 'error', 'detail', json_build_object('reason', 'crash'))), '[]')
			from (select battle_id from public.battle_queue order by battle_id limit $batch) b" > "$work/out.json"
	fi
	{
		printf '%s' 'insert into public.battle_results (battle_id, verdict, detail) select (x->>'"'"'id'"'"')::numeric::bigint, x->>'"'"'verdict'"'"', coalesce(x->'"'"'detail'"'"', '"'"'{}'"'"') from jsonb_array_elements($chimora_referee$'
		cat "$work/out.json"
		printf '%s\n' '$chimora_referee$::jsonb) x on conflict (battle_id) do nothing;'
	} | q
	echo "referee: $(grep -o '"verdict"' "$work/out.json" | wc -l) battles decided"
	return 0
}

if [ "${1:-}" = "--once" ]; then
	one_batch || true
	exit 0
fi
while true; do
	one_batch || sleep "$interval"
done
