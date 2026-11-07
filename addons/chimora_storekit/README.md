# ChimoraStoreKit (iOS purchases)

StoreKit 2 for the App Store, as a GDExtension. Source: `plugins/chimora_storekit/ios`
(Swift for StoreKit, a small godot-cpp class for the engine singleton `ChimoraStoreKit`).
`tools/build_storekit_plugin.sh` builds it on macOS in the iOS CI job and writes `bin/ChimoraStoreKit.framework`
(with its own Info.plist, MinimumOSVersion = the app's `application/min_ios_version`) and
`chimora_storekit.gdextension` here; both are gitignored, so other platforms never see the extension.
The game talks to it through `scripts/shop/AppleBillingStore.gd`.
