#!/usr/bin/env bash
# Builds Chimora's Google Play In-App Review plugin (plugins/chimora_review/android) into
# addons/chimora_review/bin/ with the Gradle wrapper of the installed Android build template.
# Run after tools/ci_setup_android.sh. Usage: tools/build_review_plugin.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -x android/build/gradlew ] || { echo "Android build template missing (run tools/ci_setup_android.sh)"; exit 1; }
godot_version="$(cat android/.build_version)"
android/build/gradlew -p plugins/chimora_review/android --no-daemon -q assembleRelease \
	-PgodotVersion="$godot_version" -PreviewVersion=2.0.2
mkdir -p addons/chimora_review/bin
cp plugins/chimora_review/android/build/outputs/aar/chimora_review-release.aar addons/chimora_review/bin/
echo "Review plugin built for Godot $godot_version"
