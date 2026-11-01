#!/usr/bin/env bash
# APK size budget (item 100). Fails CI when the package grows past the budget, and writes the
# size and its biggest parts to the job summary so growth is visible in every run.
#   tools/apk_budget.sh build/android/Chimora-debug.apk 80
set -euo pipefail
apk="$1"
budget_mb="${2:-80}"
bytes=$(stat -c %s "$apk")
mb=$(awk "BEGIN { printf \"%.1f\", $bytes / 1048576 }")
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
{
  echo "### APK size: ${mb} MB (budget ${budget_mb} MB)"
  echo
  echo '| Size (KB) | Entry |'
  echo '| ---: | --- |'
  # awk instead of head: head closing the pipe early kills sort with SIGPIPE (exit 141) under pipefail.
  command -v unzip >/dev/null && unzip -l "$apk" | awk 'NR>3 && $4 != "" { printf "| %d | %s |\n", $1 / 1024, $4 }' | sort -t'|' -k2 -nr | awk 'NR <= 12'
} >> "$summary"
if awk "BEGIN { exit !($bytes > $budget_mb * 1048576) }"; then
  echo "::error::APK is ${mb} MB, over the ${budget_mb} MB budget. See docs/RELEASE.md (APK size budget) or raise the budget on purpose."
  exit 1
fi
echo "APK ${mb} MB is within the ${budget_mb} MB budget."
