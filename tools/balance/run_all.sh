#!/usr/bin/env bash
# Plan area 2, item 881: after every balance change, rewrite the generated parts of
# docs/BALANCE.md (difficulty, AI profiles, rule variants, reference teams, the change log and
# the full report at ring 36) and print the band checks. Never edit those parts by hand.
#   tools/balance/run_all.sh [godot]       (default: godot on PATH)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${1:-godot}"
"$GODOT" --headless --path . -s res://tools/balance_doc.gd
for mode in mirror fields keepsakes ladder mono; do
	echo "== $mode =="
	"$GODOT" --headless --path . -s res://tools/balance_sim.gd -- --mode "$mode" --level 36 2>/dev/null | grep -E "^\||^[A-Z]" || true
done
echo "== team against the baseline =="
"$GODOT" --headless --path . -s res://tools/balance_sim.gd -- --mode team --level 36 --rounds 3000 --compare 2>/dev/null | sed -n '/Shifts against/,$p'
