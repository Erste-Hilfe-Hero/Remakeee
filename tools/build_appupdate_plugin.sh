#!/usr/bin/env bash
# Builds Chimora's Google Play in-app update plugin (plugins/chimora_appupdate/android) into
# addons/chimora_appupdate/bin/ with the Gradle wrapper of the installed Android build template.
# Run after tools/ci_setup_android.sh. Usage: tools/build_appupdate_plugin.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -x android/build/gradlew ] || { echo "Android build template missing (run tools/ci_setup_android.sh)"; exit 1; }
godot_version="$(cat android/.build_version)"
android/build/gradlew -p plugins/chimora_appupdate/android --no-daemon -q assembleRelease \
	-PgodotVersion="$godot_version" -PappUpdateVersion=2.1.0
mkdir -p addons/chimora_appupdate/bin
cp plugins/chimora_appupdate/android/build/outputs/aar/chimora_appupdate-release.aar addons/chimora_appupdate/bin/
echo "App update plugin built for Godot $godot_version"
