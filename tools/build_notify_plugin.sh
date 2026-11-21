#!/usr/bin/env bash
# Builds Chimora's local notification plugin (plugins/chimora_notify/android) into
# addons/chimora_notify/bin/ with the Gradle wrapper of the installed Android build template.
# Run after tools/ci_setup_android.sh. Usage: tools/build_notify_plugin.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -x android/build/gradlew ] || { echo "Android build template missing (run tools/ci_setup_android.sh)"; exit 1; }
godot_version="$(cat android/.build_version)"
android/build/gradlew -p plugins/chimora_notify/android --no-daemon -q assembleRelease \
	-PgodotVersion="$godot_version" -PcoreVersion=1.13.1
mkdir -p addons/chimora_notify/bin
cp plugins/chimora_notify/android/build/outputs/aar/chimora_notify-release.aar addons/chimora_notify/bin/
echo "Notify plugin built for Godot $godot_version"
