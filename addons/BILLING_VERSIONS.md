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
