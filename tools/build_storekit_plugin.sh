#!/usr/bin/env bash
# Builds Chimora's StoreKit 2 plugin (plugins/chimora_storekit/ios, a GDExtension) for iPhone into
# addons/chimora_storekit/bin/ and writes addons/chimora_storekit/chimora_storekit.gdextension.
# macOS with Xcode only (CI job ios). Both outputs are gitignored: without them (Linux, Android, web,
# local runs) the extension does not exist and the shop on iOS says purchases are not available.
# Usage: tools/build_storekit_plugin.sh            (needs python3; installs scons with pip if missing)
set -euo pipefail
cd "$(dirname "$0")/.."
MIN_IOS="${MIN_IOS:-16.0}"
# godot-cpp of the oldest API Chimora needs; GDExtensions built against it load in newer engines.
CPP_REFS="${GODOT_CPP_REF:-godot-4.5-stable godot-4.4-stable}"
work="${RUNNER_TEMP:-/tmp}/chimora_storekit"
rm -rf "$work" && mkdir -p "$work"
for ref in $CPP_REFS; do
	if git clone -q --depth 1 -b "$ref" https://github.com/godotengine/godot-cpp "$work/godot-cpp"; then
		echo "godot-cpp $ref"; break
	fi
done
[ -d "$work/godot-cpp" ] || { echo "no godot-cpp"; exit 1; }
command -v scons >/dev/null || python3 -m pip install -q scons || pip3 install -q --break-system-packages scons
(cd "$work/godot-cpp" && scons -s platform=ios arch=arm64 target=template_release ios_simulator=no \
	ios_min_version="$MIN_IOS" -j"$(sysctl -n hw.ncpu)")
lib=$(ls "$work"/godot-cpp/bin/libgodot-cpp.ios.template_release*.a | head -1)
echo "godot-cpp library: $lib"
SDK=$(xcrun -sdk iphoneos --show-sdk-path)
src=plugins/chimora_storekit/ios
xcrun -sdk iphoneos clang++ -std=c++17 -arch arm64 -isysroot "$SDK" -miphoneos-version-min="$MIN_IOS" -O2 -fPIC \
	-DNDEBUG -DIOS_ENABLED -DUNIX_ENABLED -DTHREADS_ENABLED -fvisibility=hidden \
	-I "$work/godot-cpp/include" -I "$work/godot-cpp/gen/include" -I "$work/godot-cpp/gdextension" \
	-c "$src/chimora_storekit.cpp" -o "$work/chimora_storekit.o"
out=addons/chimora_storekit/bin
name=libchimora_storekit.ios.template_release.dylib
mkdir -p "$out"
xcrun -sdk iphoneos swiftc -target "arm64-apple-ios$MIN_IOS" -sdk "$SDK" -swift-version 5 -O -emit-library \
	-module-name ChimoraStoreKit "$src/ChimoraStoreKit.swift" "$work/chimora_storekit.o" \
	-Xlinker "$lib" -lc++ -framework StoreKit \
	-Xlinker -install_name -Xlinker "@rpath/$name" -o "$out/$name"
nm -gU "$out/$name" | grep -q chimora_storekit_init || { echo "entry symbol missing"; exit 1; }
cat > addons/chimora_storekit/chimora_storekit.gdextension <<GDE
[configuration]

entry_symbol = "chimora_storekit_init"
compatibility_minimum = "4.4"

[libraries]

ios.release = "res://$out/$name"
ios.debug = "res://$out/$name"
GDE
ls -la "$out"
echo "StoreKit plugin built (iOS $MIN_IOS)"
