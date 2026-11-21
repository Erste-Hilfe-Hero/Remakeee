# Billing plugin versions

Checked on 2026-11-06 (plan item 4119). Update the date whenever a version changes.

| Store | Plugin | Library | Where |
| --- | --- | --- | --- |
| Google Play | Chimora's own plugin `ChimoraBilling` (Godot Android plugin v2) | Play Billing Library 8.0.0 | Source `plugins/chimora_billing/android`, built by `tools/build_billing_plugin.sh` into `addons/chimora_billing/bin/` (CI only) |
| App Store | not yet (StoreKit 2, plan item 4092) | | |

The Android plugin is built against the Godot build template of the engine version in CI
(`GODOT_VERSION`, now 4.7.2), so plugin and engine always match. Play Billing adds the
permission `com.android.vending.BILLING` through its own manifest; `tools/release_check.py`
fails on any other new permission and on ad or analytics SDKs.

To change the Play Billing version, change `-PbillingVersion` in `tools/build_billing_plugin.sh`
and `BILLING` in `addons/chimora_billing/plugin.gd` together.

## Play In-App Updates

Plugin `ChimoraAppUpdate` (source `plugins/chimora_appupdate/android`, built by
`tools/build_appupdate_plugin.sh` into `addons/chimora_appupdate/bin/`, CI only) uses
`com.google.android.play:app-update:2.1.0`, the newest stable on 2026-11-14. It adds no permission.
See docs/LIVE_CONTENT.md, "In-game updates".

## Local notifications

Plugin `ChimoraNotify` (source `plugins/chimora_notify/android`, built by `tools/build_notify_plugin.sh` into
`addons/chimora_notify/bin/`, CI only) uses `androidx.core:core:1.13.1` for NotificationCompat (AndroidX, already in
every Godot app through the engine's androidx.fragment). It adds `POST_NOTIFICATIONS` (asked at runtime on Android 13+
only after the player said yes in the game), an inexact `AlarmManager.set` per note and a non-exported receiver;
no exact-alarm, boot or install permission, no network. On iOS the same calls go to `ChimoraStoreKit.notify_*`
(`ChimoraNotify.swift`, UNUserNotificationCenter). `scripts/core/LocalNotify.gd` decides what and when
(plan Chimora 100, item 76).
