# Store listings

Everything the two store consoles ask for, in the folder layout of fastlane (`supply` for Google Play,
`deliver` for the App Store), so it can be uploaded by hand or with fastlane later.

| Folder | What |
| --- | --- |
| `android/<lang>/title.txt`, `short_description.txt`, `full_description.txt` | Play listing (30 / 80 / 4000 characters) |
| `android/<lang>/changelogs/default.txt` | "What's new" |
| `android/<lang>/images/phoneScreenshots/1-6.png` | 1080 x 1920 phone screenshots |
| `android/<lang>/images/featureGraphic.png`, `icon.png` | 1024 x 500 feature graphic, 512 x 512 icon |
| `android/app_access_de.txt` | Text for Play Console → App content → App access |
| `ios/metadata/<lang>/*.txt` | Name, subtitle, description, keywords, promotional text, URLs, release notes |
| `ios/screenshots/<lang>/N_iphone69.png` | 1320 x 2868 (6.9" iPhone, the one size Apple requires; smaller iPhones are scaled from it) |
| `ios/review_information/notes.txt` | Notes for App Review |
| `ios/iap_review.png` | 720 x 1280 picture of the shop, App Review needs one for every in-app purchase |
| `products.json` | In-app products for both stores |

Languages: all 14 of the game (Play folders like `ja-JP`, App Store folders like `ja`, pairs in
`tools/release_check.py` TEXT_LANGS), each with its own texts and screenshots. The app is
iPhone-only (`targeted_device_family=0`), so no iPad screenshots are needed.

Upload: Google Play by `play_store.mjs`, App Store Connect by `app_store.mjs` and `iap.mjs` in the
lifekit workflow `chimora-store.yml` (commits `run:chimora-store-play`, `run:chimora-store-asc+iap`).

Rebuild the images after the art or the UI changes: see the top of `tools/store/make_store_images.py`.
Rules for every text and image: no other game's or brand's names, no comparisons (docs/IP_HYGIENE.md,
docs/legal/STORE_COMPLIANCE.md). Say clearly that the game needs the internet.
Every description keeps its accessibility block ("PLAYABLE YOUR WAY" and its 13 translations,
`A11Y_HEADINGS` in `tools/release_check.py`); claim only what the game has (docs/KAMPF_TECHNIK.md section 4).

Privacy, support and account deletion URLs point to the pages the game server serves
(`server/site`, built by `tools/site/build_site.py`). Change them together with `LegalInfo.SITE` once
there is an own domain.
