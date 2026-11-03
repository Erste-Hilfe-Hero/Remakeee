#!/usr/bin/env bash
# Prints the path of the newest zipalign (needs build-tools 35+ for -P 16).
set -euo pipefail
if command -v zipalign >/dev/null 2>&1; then command -v zipalign; exit 0; fi
for root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" /usr/lib/android-sdk /opt/android-sdk; do
  [ -n "$root" ] && [ -d "$root/build-tools" ] || continue
  found="$(find "$root/build-tools" -name zipalign -type f | sort -V | tail -1)"
  if [ -n "$found" ]; then echo "$found"; exit 0; fi
done
echo "zipalign not found" >&2
exit 1
