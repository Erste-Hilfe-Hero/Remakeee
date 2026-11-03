#!/usr/bin/env bash
# Boots the project headless and fails if Godot prints any script or engine error.
# Usage: tools/headless_check.sh [godot-binary]
set -uo pipefail
GODOT="${1:-godot}"
LOG="$(mktemp)"
"$GODOT" --headless --path . --quit-after 10 >"$LOG" 2>&1
STATUS=$?
cat "$LOG"
if [ "$STATUS" -ne 0 ] || grep -Eq "SCRIPT ERROR|^ERROR:|Parse Error" "$LOG"; then
  echo "::error::Headless boot printed errors"
  exit 1
fi
echo "Headless boot clean"
