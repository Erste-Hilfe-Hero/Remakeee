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

Languages: `de-DE` and `en-US`. The app is iPhone-only (`targeted_device_family=0`), so no iPad
screenshots are needed.

Rebuild the images after the art or the UI changes: see the top of `tools/store/make_store_images.py`.
Rules for every text and image: no other game's or brand's names, no comparisons (docs/IP_HYGIENE.md,
docs/legal/STORE_COMPLIANCE.md). Say clearly that the game needs the internet.

Privacy, support and account deletion URLs point to the pages the game server serves
(`server/site`, built by `tools/site/build_site.py`). Change them together with `LegalInfo.SITE` once
there is an own domain.
