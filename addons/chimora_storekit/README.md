# ChimoraStoreKit (iOS purchases)

StoreKit 2 for the App Store, as a GDExtension. Source: `plugins/chimora_storekit/ios`
(Swift for StoreKit, a small godot-cpp class for the engine singleton `ChimoraStoreKit`).
`tools/build_storekit_plugin.sh` builds it on macOS in the iOS CI job and writes `bin/ChimoraStoreKit.framework`
(with its own Info.plist, MinimumOSVersion = the app's `application/min_ios_version`) and
`chimora_storekit.gdextension` here; both are gitignored, so other platforms never see the extension.
The game talks to it through `scripts/shop/AppleBillingStore.gd`.
`notify_request_permission`, `notify_schedule` and `notify_cancel_all` (with the signal `notify_event`) are the opt-in
local notifications of `scripts/core/LocalNotify.gd` (`ChimoraNotify.swift`, UNUserNotificationCenter; plan Chimora 100,
item 76). They are scheduled on the phone only: no push server, no device token, nothing leaves the device.
