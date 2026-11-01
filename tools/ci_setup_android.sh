#!/usr/bin/env bash
# CI helper for the barichello/godot-ci container.
# 1. GitHub runs containers with HOME=/github/home, but the image installs the
#    export templates and editor settings (Android SDK path) under /root.
# 2. Installs the Android Gradle build template into android/build, which is what
#    "Project > Install Android Build Template" does in the editor. android/ is
#    gitignored so it always matches the engine version.
set -euo pipefail
TEMPLATES="${GODOT_TEMPLATES:-4.7.2.stable}"

mkdir -p "$HOME/.local/share/godot/export_templates" "$HOME/.config"
if [ "$HOME" != "/root" ]; then
  if [ -d "/root/.local/share/godot/export_templates/$TEMPLATES" ] && [ ! -d "$HOME/.local/share/godot/export_templates/$TEMPLATES" ]; then
    cp -r "/root/.local/share/godot/export_templates/$TEMPLATES" "$HOME/.local/share/godot/export_templates/"
  fi
  if [ -d /root/.config/godot ] && [ ! -d "$HOME/.config/godot" ]; then
    cp -r /root/.config/godot "$HOME/.config/godot"
  fi
fi

SRC="$HOME/.local/share/godot/export_templates/$TEMPLATES/android_source.zip"
if [ ! -f "$SRC" ]; then
  echo "::error::Android build template not found at $SRC"
  exit 1
fi
rm -rf android
mkdir -p android/build
unzip -q "$SRC" -d android/build
touch android/build/.gdignore
echo "$TEMPLATES" > android/.build_version
echo "Android build template $TEMPLATES installed"

# 3. zipalign -P 16 needs build-tools 35+, and the Gradle build targets SDK 36.
#    Install them if the image's SDK is older.
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
SDKMANAGER="$(command -v sdkmanager || true)"
if [ -z "$SDKMANAGER" ] && [ -n "$SDK" ]; then
  SDKMANAGER="$(find "$SDK" -path '*cmdline-tools*' -name sdkmanager -type f 2>/dev/null | sort -V | tail -1)"
fi
if [ -n "$SDKMANAGER" ]; then
  yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
  "$SDKMANAGER" "build-tools;35.0.0" "platforms;android-36" >/dev/null
  echo "Installed build-tools 35.0.0 and platform 36"
else
  echo "::warning::sdkmanager not found; using the image's build-tools"
fi
