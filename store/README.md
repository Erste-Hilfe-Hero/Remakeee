# Store listings

Everything the two store consoles ask for, in the folder layout of fastlane (`supply` for Google Play,
`deliver` for the App Store), so it can be uploaded by hand or with fastlane later.

| Folder | What |
| --- | --- |
| `android/<lang>/title.txt`, `short_description.txt`, `full_description.txt` | Play listing (30 / 80 / 4000 characters) |
| `android/<lang>/changelogs/default.txt` | "What's new" |
| `android/<lang>/images/phoneScreenshots/1-8.png` | 1080 x 2160 phone screenshots (captions of the language's main App Store locale) |
| `android/<lang>/images/featureGraphic.png`, `icon.png` | 1024 x 500 feature graphic, 512 x 512 icon |
| `android/app_access_de.txt` | Text for Play Console → App content → App access |
| `ios/metadata/<lang>/*.txt` | Name, subtitle, description, keywords, promotional text, URLs, release notes |
| `ios/in_app_events/<lang>/*.txt` | In-App Event card: name (30), short (50) and long description (120) |
| `ios/screenshots/<lang>/N_iphone69.png` | 1320 x 2868 (6.9" iPhone, the one size Apple requires; smaller iPhones are scaled from it), 8 per locale, all 20 locales |
| `ios/screenshot_captions/<locale>.txt` | The 8 captions of the pictures, one per line, per App Store locale (checked by `tools/store/listing_check.py`) |
| `ios/screenshots_ipad13/<lang>/N_ipad13.png` | 2064 x 2752 (13" iPad), en-US and de-DE only; not uploaded while the app is iPhone-only. All 20 locales are rendered by the same tool |
| `icon_variants/face_*.png` | Icon variant "face" (plan Chimora 100, item 88) for a Product Page Optimization test; the app icon stays `art/icon/`. Made by `tools/art/gen_icon.py --variant` |
| `ios/review_information/notes.txt` | Notes for App Review |
| `ios/iap_review.png` | 720 x 1280 picture of the shop, App Review needs one for every in-app purchase |
| `products.json` | In-app products for both stores |

Languages: all 14 of the game (Play folders like `ja-JP`, App Store folders like `ja`, pairs in
`tools/release_check.py` TEXT_LANGS), each with its own texts and screenshots. The app is
iPhone-only (`targeted_device_family=0`), so no iPad screenshots are needed for now (the 13" set waits
in `ios/screenshots_ipad13/`).

App Store locales: all 20 Chimora is listed in, the 14 game languages plus `en-GB`, `en-AU`, `en-CA`,
`fr-CA`, `es-MX` and `pt-PT` (the game text there is pt-BR, the description says so). Each locale has its
own name ("Chimora: " plus a genre phrase), subtitle with search words, keywords and promotional text
(plan Chimora 100, items 83-85, 93, 95). Keyword rules: comma separated without spaces, no word that the
name or subtitle already has, and no word twice in one storefront. Apple indexes some locales together,
so these pairs carry disjoint words: `en-US` + `es-MX` (US, es-MX holds extra English terms), `en-CA` +
`fr-CA` (Canada, fr-CA holds extra English terms), `en-GB` + `en-AU` (Australia; en-GB is also read in
many EU storefronts). The pairs come from reported behaviour, not from Apple docs: test one unique word
before relying on one. `python3 tools/store/listing_check.py` checks every limit and rule and runs in CI.

App Store "Languages": Apple lists the languages from the `.lproj` folders in the app. Godot 4.7 writes
`<lang>.lproj/InfoPlist.strings` only for locales that have a project translation, so `ios/lproj/<lang>.po`
(one unused string each, listed in `internationalization/locale/translations`) marks the 13 non-English
languages, `application/config/name_localized` keeps the home-screen name "Chimora" in each, and the iOS
preset also lists them in `CFBundleLocalizations`. `tools/release_check.py` checks all three against `data/i18n`.

Upload: Google Play by `play_store.mjs`, App Store Connect by `app_store.mjs` and `iap.mjs` in the
lifekit workflow `chimora-store.yml` (commits `run:chimora-store-play`, `run:chimora-store-asc+iap`).

Rebuild the images after the art or the UI changes: see the top of `tools/store/make_store_images.py`
(raw screens from `tools/store_shots.gd`, all from the running game; the 1.3.2 screens in a second run
with the tall window `--resolution 440x956`). The set (1.3.2), in this order: monster hero (Era IV
Spirlings, one Gleam), 3v3 battle, a wild Rime Gleam in battle (its opening line, or the command menu
where that line takes two pages), Era V town in the rain, a puzzle board (Tracks in the Mud), one town
in Eras I to IV, the shop's Featured page, the pass track. No money prices and no Discord note in any
picture: the Featured page is shot without store prices (the buttons say "Show", as before the store
answers) and with the euro hints "(≈ ...)" taken out. The weekend Growth note is switched off for the shots. The app preview video (15-30 s, 1080 x 1920, 30 fps, H.264) is recorded by
`tools/store_video.gd` and encoded by `tools/store/make_store_video.py`; it is kept outside the repo.
The folders with pictures carry a `.gdignore`, so Godot does not import them.
Rules for every text and image: no other game's or brand's names, no comparisons (docs/IP_HYGIENE.md,
docs/legal/STORE_COMPLIANCE.md). Say clearly that the game needs the internet.
Every description keeps its accessibility block ("PLAYABLE YOUR WAY" and its 13 translations,
`A11Y_HEADINGS` in `tools/release_check.py`); claim only what the game has (docs/KAMPF_TECHNIK.md section 4).

Privacy, support and account deletion URLs point to the pages the game server serves
(`server/site`, built by `tools/site/build_site.py`). Change them together with `LegalInfo.SITE` once
there is an own domain.
