# Live content

Changes to shop offers, balance values, the type chart, events, texts and news reach players without a store release. The game fetches a signed JSON patch from the server at start and when it comes back from the background.

## Rules

- **Data only.** A patch is one JSON object. Allowed top-level keys: `version`, `requires`, `min_client`, `latest`, `shop`, `balance`, `type_chart`, `events`, `texts`, `news`. Apple (App Review Guideline 2.5.2) and Google Play (Device and Network Abuse policy) forbid downloading executable code, so there are no scripts, no Godot `.pck` files and no paths to scenes or resources. Both `tools/live/publish.py` and the game (`LiveContent.has_code`) refuse a patch with an unknown key or a string that looks like code (`.gd`, `.pck`, `res://`, `extends `, ...). News links that start with `https://` are allowed.
- **Signed.** RSA-2048, PKCS#1 v1.5 over SHA-256 of the body bytes. The public key is in `scripts/online/LiveContent.gd`. The game uses a patch only when the signature is valid, and it checks the cached copy again on every start.
- **Fallback.** Order: a verified cache (`user://live_content.json`), then the bundled `data/live_content.json`. If there is no connection, no patch or a bad signature, the game keeps what it had.
- **Insert only.** The server keeps every version (`public.live_content`). `live_content_publish` refuses a version that is not newer than the newest stored one. To roll back, publish the old content again with a higher version.

## Fields

```json
{
  "version": 3,
  "requires": "1.1.0",
  "min_client": {"ios": "0", "android": "0"},
  "latest": {"ios": "1.2.0", "android": "1.2.0"},
  "news": [
    {"date": "2026-11-20", "title": {"en": "Patch 1.2", "de": "Patch 1.2"},
     "body": {"en": "...", "de": "..."}, "url": "https://discord.gg/e69SM39rKK"}
  ],
  "texts": {"en": {"key": "text"}, "de": {"key": "Text"}},
  "shop": {}, "balance": {}, "type_chart": {}, "events": []
}
```

| Field | Meaning |
| --- | --- |
| `version` | Whole number. Must go up by at least 1 with every publish. |
| `requires` | Optional. Older games ignore the patch, for data that only newer builds understand. |
| `min_client` | Per platform. A game below this version name must update: a dialog with only "Update" and "Try again". **Separate for iOS and Android**, because their builds differ. `"0"` means no minimum. Never raise it before that build is live in that store. |
| `latest` | Per platform. A game below it is offered an update once per start ("Update" / "Later"). On iOS the App Store lookup (`itunes.apple.com/lookup?id=6831632885`, bundle `de.chimora.game`) also counts when it is newer. |
| `news` | "What's new" on the title screen, newest first. `title` and `body` are plain text or `{"en", "de", ...}`. The panel always ends with "Join our Discord" (`MenuHost.DISCORD_URL`). |
| `texts` | Text overrides by language, read with `LiveContent.text(key, fallback)`. |
| `shop`, `balance`, `type_chart`, `events` | Read with `LiveContent.section(name, fallback)`. |

Version names are compared part by part (`1.10.0` is newer than `1.9.0`). The game's own name is `Online.CLIENT_VERSION_NAME`, which `tools/bump_version.py` keeps equal to `version/name` in `export_presets.cfg`.

## Publishing a patch (how Claude does it)

1. Edit `live/content.json`. Raise `version` by 1. Write news in English and German.
2. Check it: `python3 tools/live/publish.py check live/content.json`.
3. Open a pull request. The `Live content` workflow and the `ip-check` job run the same check.
4. After merging, run the `Live content` workflow by hand (Actions, Live content, Run workflow). First with `dry_run` on, which signs and verifies only. Then again with `dry_run` off, which adds the patch to the server. With `gh`: `gh workflow run live-content.yml -f dry_run=false --ref <branch>`.
5. Players get it on their next start or resume.

The workflow signs with the `LIVE_CONTENT_KEY` secret, checks the signature against the public key in the game, and then runs `select public.live_content_publish(version, body, signature)` on the server through SSH (`CHIMORA_SERVER_IP`, `CHIMORA_SERVER_PASSWORD`, the same secrets as `server.yml`). It never deletes or changes a row.

Manually, with the key on disk: `python3 tools/live/publish.py sign live/content.json --key key.pem --out signed.json`, then `python3 tools/live/publish.py sql signed.json` gives the SQL line for `docker compose exec -T db psql -U postgres -d postgres`.

When a new store build ships, also copy the content to `data/live_content.json` so the bundled fallback is current.

## Key

- The private key is **never** in the repository. Store it as the GitHub secret `LIVE_CONTENT_KEY` (the whole PEM text) and keep an offline copy.
- New key: `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out live_content_key.pem`, then `openssl pkey -in live_content_key.pem -pubout`, and put that public key into `LiveContent.PUBLIC_KEY`. Builds with the old key ignore patches signed with the new one and keep their cache or bundled data, so change the key only with a store release.

## Server

Migration `supabase/migrations/20261111000001_live_content.sql` adds the table and two functions:

- `live_content_get(p_have int)`: for signed-in players. Returns the newest `{version, body, signature}`, or `{version, unchanged: true}` when the game already has it, or `{version: 0}` when there is none.
- `live_content_publish(p_version, p_body, p_signature)`: only for the database owner. Not callable by players.

The migration reaches the live server like every other one: `server.yml` deploys on a push to `main` that touches `supabase/**`, and `server/migrate.sh` makes a backup first and applies only new files. Tests: `tools/online/sql_test/test_live_content.sql`.

## Android in-app updates

Google's in-app update API needs the Play Core library inside an Android plugin. The project's own billing plugin does not include it, and AGENTS.md rule 4 asks for Ali's OK before adding SDKs. Until then Android uses the store-link dialog driven by `latest.android` and `min_client.android`.

## Code

- `scripts/online/LiveContent.gd`: checking, cache, fallback, version compare, readers.
- `scripts/online/Online.gd`: `refresh_live_content()` after hello and on resume, `update_state()`, `check_store()`.
- `scripts/ui/TitleScreen.gd`: required and optional update dialogs, "What's new" row.
- `scripts/ui/MenuHost.gd`: `run_news()`.
- `tests/unit/test_live_content.gd`: GUT tests.
