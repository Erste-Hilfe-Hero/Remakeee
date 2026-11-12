#!/usr/bin/env bash
# Runs the GUT suite and fails if a test script did not load: GUT only warns and skips a
# script with a parse error (or one that does not extend GutTest), so the job stayed green.
# Checks: GUT's exit code, no parse/ignore lines for res://tests/, and GUT's "Scripts" count
# is at least the number of test_*.gd files in the .gutconfig.json dirs.
# Usage: tools/gut_strict.sh [godot-binary]   or   tools/gut_strict.sh --check-log LOG
set -uo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" = "--check-log" ]; then
  LOG="$2"
  STATUS=0
else
  GODOT="${1:-godot}"
  LOG="$(mktemp)"
  "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd 2>&1 | tee "$LOG"
  STATUS=${PIPESTATUS[0]}
fi
CLEAN="$(mktemp)"
sed 's/\x1b\[[0-9;]*m//g' "$LOG" >"$CLEAN"
fail=0
if [ "$STATUS" -ne 0 ]; then
  echo "::error::GUT exited with $STATUS"
  fail=1
fi
bad="$(grep -E "Failed to load script \"res://tests/|Ignoring script res://tests/|Parse Error.*res://tests/|at: GDScript::reload \(res://tests/" "$CLEAN" | sort -u)"
if [ -n "$bad" ]; then
  echo "$bad" | while IFS= read -r l; do echo "::error::GUT test script did not load: $l"; done
  fail=1
fi
expected=$(find tests/unit tests/fuzz -type f -name 'test_*.gd' 2>/dev/null | wc -l)
ran=$(grep -E '^Scripts +[0-9]+' "$CLEAN" | tail -1 | awk '{print $2}')
if [ -z "$ran" ]; then
  echo "::error::GUT printed no Scripts total (did it finish?)"
  fail=1
elif [ "$ran" -lt "$expected" ]; then
  echo "::error::GUT ran $ran test scripts but tests/ has $expected test_*.gd files"
  fail=1
fi
[ "$fail" -eq 0 ] && echo "GUT strict: $ran of $expected test scripts ran"
exit "$fail"
