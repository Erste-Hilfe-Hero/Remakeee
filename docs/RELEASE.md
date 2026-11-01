# Building and releasing Chimora

CI lives in `.github/workflows/export.yml` and uses Godot **4.7.2-stable**
(`barichello/godot-ci:4.7.2`, templates `4.7.2.stable`).

| Job | Runs on | What it does |
| --- | --- | --- |
| `test` | every push and PR | headless boot with no errors, data validation, GUT tests |
| `android-debug` | pushes to `main`, tags, manual | debug APK (throwaway keystore made in the job) + `zipalign -c -P 16` |
| `android-release` | `v*` tags, manual | signed **AAB** for Google Play, 16 KB alignment check on every `.so`, `zipalign -c -P 16` on a universal APK |
| `web` | every push and PR (after tests) | single-threaded **Web** build as the `web-build` artifact; serve the folder with any static server to play in a browser |
| `android-internal` | manual (tick "play_internal") | uploads the release AAB to the Play **internal testing** track as a draft |
| `ios` | manual (tick "ios"), or `v*` tags when the repo variable `IOS_ENABLED=true` | IPA on a `macos-26` runner with Xcode 26, upload to TestFlight |

## Android setup (one time)

1. Create an **upload key** (Play App Signing keeps the real app key, so losing this one is recoverable):
   `keytool -genkeypair -v -keystore upload.keystore -alias chimora-upload -keyalg RSA -keysize 2048 -validity 10000`
2. In GitHub: Settings → Environments → New environment `prod`. Add required reviewers so only you can release.
3. Add these secrets to the `prod` environment:
   - `ANDROID_KEYSTORE_B64`: output of `base64 -w0 upload.keystore`
   - `ANDROID_KEYSTORE_ALIAS`: `chimora-upload`
   - `ANDROID_KEYSTORE_PASSWORD`: the keystore password (use the same password for the key)
4. In Play Console, enrol in **Play App Signing** and upload the first AAB from the `android-release` artifact.

5. For automatic internal-testing uploads: in Play Console → Setup → API access, create a service account,
   give it "Release to testing tracks" for this app, download its JSON key and save the whole JSON as the
   `prod` secret `PLAY_SERVICE_ACCOUNT_JSON`. Then run the workflow by hand with **play_internal** ticked.
   The release lands as a draft on the internal track; roll it out in Play Console. Testers join through
   the internal testing opt-in link.

Version codes are stamped in CI as `1000 + run number` (Android `version/code`, iOS build number), so every
upload is higher than the last. A `v1.2.3` tag also sets the version name to `1.2.3`.

Signing uses Godot's `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables, so passwords never touch
`export_presets.cfg`. The release job sets **no** `GODOT_ANDROID_KEYSTORE_DEBUG_*` variables, because setting
only some of them breaks the export (Godot issue #109551).

Preset values: target SDK 36, min SDK 24, arm64-v8a only, Gradle build, AAB. The Gradle build template is
installed fresh in CI by `tools/ci_setup_android.sh` (the `android/` folder is gitignored). To build locally,
use Project → Install Android Build Template in the editor.

`package/unique_name` is `com.chimora.game` as a placeholder. Change it to a reverse domain you own before
the first upload; it can never change afterwards.

## iOS setup (one time)

Add to the `prod` environment:

- `IOS_DIST_CERT_P12_B64`, `IOS_DIST_CERT_PASSWORD`: Apple Distribution certificate exported as .p12
- `IOS_PROVISION_PROFILE_B64`: App Store provisioning profile for the bundle ID
- `IOS_TEAM_ID`: your 10-character team ID
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_B64`: App Store Connect API key with App Manager access

Then set the repository variable `IOS_ENABLED=true` to build iOS on tags, or run the workflow manually with
"ios" ticked. Godot's iOS export writes a `PrivacyInfo.xcprivacy`; with no analytics the App Store privacy label
is "Data Not Collected".

## Releasing

Bump `version/code` and `version/name` (Android) and `application/version` / `application/short_version` (iOS)
in `export_presets.cfg`, then push a tag such as `v0.1.0`.
