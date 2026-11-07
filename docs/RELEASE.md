# Building and releasing Chimora

CI lives in `.github/workflows/export.yml` and uses Godot **4.7.2-stable**
(`barichello/godot-ci:4.7.2`, templates `4.7.2.stable`).

| Job | Runs on | What it does |
| --- | --- | --- |
| `test` | every push and PR | headless boot with no errors, data validation, GUT tests |
| `android-debug` | every push and PR | debug APK (throwaway keystore made in the job) + `zipalign -c -P 16` |
| `android-release` | `v*` tags, manual | signed **AAB** for Google Play, 16 KB alignment check on every `.so`, `zipalign -c -P 16` on a universal APK |
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

`package/unique_name` and the iOS bundle ID are `de.chimora.game`. They can never change after the first
upload. Store texts, screenshots and the submission steps: `store/README.md` and `docs/STORE_RELEASE.md`.
Run `python3 tools/release_check.py --strict` before tagging a release.

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

## APK size budget

CI fails the Android debug job when the APK is larger than 92 MB (raised from 88 MB on 7 Nov 2026 for the 12 new languages: their text tables and the CJK pixel fonts add about 2-3 MB) (`tools/apk_budget.sh`). The job summary shows the size and the biggest files in the package. If the budget is hit, first look for large textures or audio that slipped in. Raise the number in `.github/workflows/export.yml` only on purpose, for example when a new era adds art.

Raised from 80 to 88 MB for the layered place music (plan area 6, items 2475 to 2479): every place song ships as four stems. Phones and tablets play the stems, so the Android and iOS presets leave out the eleven full mixes of the place songs; the web build plays the full mixes and leaves out `audio/music/stems/` (web audio plays samples, which AudioStreamSynchronized does not use).

## Official build path and version numbers (plan area 9)

- **Store builds** (signed AAB for Google Play, IPA for TestFlight) run in the lifekit repository, because the
  signing keys and store accounts live there: workflow `.github/workflows/chimora-store.yml` on branch
  `claude/chimora-store`, started by a commit `run:chimora-store-android` / `run:chimora-store-ios`. It checks
  out this repository at the pinned `CHIMORA_REF`. That is the official path to the stores.
- **This repository** builds the debug APK and the browser test build on every push (`export.yml`) and is the
  only place where code changes. Before a store build, set `CHIMORA_REF` in lifekit to the commit on `main`
  (or the release tag) that passed all checks here.
- **Version numbers:** `python3 tools/bump_version.py --name 1.2.0` sets the version name and the next version
  code in every export preset and `Online.CLIENT_VERSION` at once; CI runs `--check`. The lifekit build adds
  its own build number for the store upload. Raise `server_config.min_version` only when the new build is
  live in both stores.
- GitHub Actions are pinned to commit SHAs (the tag stays as a comment). Update them in a reviewed PR.
