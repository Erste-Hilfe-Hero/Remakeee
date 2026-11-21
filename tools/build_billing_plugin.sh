#!/usr/bin/env bash
# Builds Chimora's Google Play Billing plugin (plugins/chimora_billing/android) into
# addons/chimora_billing/bin/ with the Gradle wrapper of the installed Android build template.
# Run after tools/ci_setup_android.sh. Usage: tools/build_billing_plugin.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -x android/build/gradlew ] || { echo "Android build template missing (run tools/ci_setup_android.sh)"; exit 1; }
godot_version="$(cat android/.build_version)"
android/build/gradlew -p plugins/chimora_billing/android --no-daemon -q assembleRelease \
	-PgodotVersion="$godot_version" -PbillingVersion=8.0.0
mkdir -p addons/chimora_billing/bin
cp plugins/chimora_billing/android/build/outputs/aar/chimora_billing-release.aar addons/chimora_billing/bin/
echo "Billing plugin built for Godot $godot_version"
