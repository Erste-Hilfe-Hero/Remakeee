# Playing offline

Owner decision (Ali, 28.11.2026): "Lass das Spiel auch offline spielbar sein" and "Offline spielbar soll
keine extra Option sein: wenn der Spieler Internet hat, ist es mit dem Server verbunden, falls nicht, ist
auch nicht schlimm."

Chimora plays offline. There is no setting and no screen for it: with internet the game connects and syncs
in the background, without it the journey simply goes on. A connection that drops in the middle of a battle
or a walk switches to offline quietly; nothing pauses.

## What the player sees

- **Title:** the game tries to connect for at most `TitleScreen.CONNECT_WAIT` (4 s) and then shows the list
  as always. Offline one quiet line stands over the art: "Offline. Your journey is saved on this phone."
  No "Try again", no "Start offline" row. Continue, Load and New Game all work.
- **Playing:** after `OfflineMark.SHOW_AFTER` (3 s) without connection a small mark (13 x 9 px, three
  signal bars with a stroke) fades in at the top centre, under the safe area. It takes no taps, never dims
  the screen and fades out when the connection is back. `Online` tries again in the background (first after
  1 s, then 4, 8, 16, 30 s with 20 % spread).
- **A part that needs the server:** one short line, at reading size in every era (13 pt, `ShopZoom`):
  "This needs internet. The rest of your journey plays on offline." (`OnlineErrors.NEEDS_INTERNET`, all
  14 languages). It works again as soon as the phone is online, without a restart.
- **Saving:** "Saved on this phone. The server follows once the connection is back." "Save and to title"
  asks nothing more offline; it only asks when the phone is online and the upload did not go through.

## What works offline

Story, wild battles, bonding (Echo call), Wayfarers and Wardens, Rifts, team, storage, satchel, map and
travel, puzzles, weather, the Lamp Watch, daily finds and daily tasks (phone clock offline), goals, badges,
settings, photo mode and the local save. Bought unlocks, the Wayfarer Pass and the age band from the last
connection keep working (see "Entitlements").

## What needs internet

Shop and every purchase, Riftglass (balance, spending, the daily gift, Continue in battle, bond boost),
the pass track rewards, leagues, live and echo duels, raids, trades, gifts, friends and Lantern Mail, bunds,
tournaments, online events, weekly and climb boards, promo codes, the account menu's server parts (transfer
code, data export, deleting the account, earlier saves) and the backup of the saves on the server.
League, Friends (with everything behind it), Promo and the Shop check first and show the needs-internet
line; every other server call answers with the same line through `Online.error_text()` (code "offline").

## Sync and conflicts

The save in `user://` is the journey; the server keeps a copy per slot with a revision (`Online.revs`).

1. Every local save marks its slot dirty (`Online.note_saved`). Online it goes up at once, offline it waits.
2. When a background try reaches the server (`Online._reconnect`): sign-in (a first start offline makes the
   anonymous account here), `hello`, `session_claim`, then `push_dirty()` sends every waiting slot through the
   normal `save_put` with the revision it last saw, then the queued small actions, then profile and team.
3. The title, once online, runs `sync_down()`: a slot only the server changed is pulled, a slot only this
   phone changed is pushed.
4. **Conflict:** a slot changed here and on another device (the server's revision moved on) is never
   overwritten on either side. It stays dirty here, the server keeps the other device's copy, and the title
   asks "Slot N was played on this phone and on another device. Which journey do you keep?" (the rule the
   cloud save already had). Nothing is decided automatically, so no progress is lost silently.
5. **Another device took the account** (`other_device`): this phone no longer jumps to the title mid-game. It
   stops syncing and plays on offline; the next title asks "Play on this device", and the sync after it meets
   the conflict rule above.
6. **Version checks** (`UPDATE_REQUIRED`) only exist with a connection: the title stops for a required update
   only when the server says so. A required update met in the background during play does not stop the
   game; online parts stay closed until the update (`state == UPDATE_REQUIRED`).

## Anti-cheat and paid goods

- Saves made offline reach the server only through `save_put`, so every server check still applies:
  play time no faster than wall-clock time since the last accepted save, money per minute, unknown species,
  arts and items, party size, schema version. A refused save stays on the phone, is flagged as before and
  is never forced.
- **No purchase offline:** `Billing.buy_in_store` and `Billing.buy_with_riftglass` return "offline" before
  any store sheet or server call, even when an older shop state is still in memory. The shop shows the
  needs-internet line; the Starter Pack note never shows offline (`ShopScreen.starter_popup_now`).
- **Riftglass stays server-authoritative:** spending, the daily gift and every grant need the server
  (`RiftglassSinks.why_not`, `claim_daily`); Riftglass rows are hidden offline. Bag items and coins from
  purchases come from `shop_claim` online only.
- **Store purchases finished while offline** (Ask to Buy, a purchase made on another device) stay open in
  the store and go to the server on the next connection (`Billing.resume_pending`), so no entitlement is lost.
- **Shop rules hold offline too:** no shop in battle or after a defeat (unchanged), and `kids_locked` (age band
  under 13, also from the offline copy) shows "The shop is closed for your age" before anything else, never a
  purchase prompt.

## Entitlements offline

After every `shop_state` from the real server, `Billing.save_cache()` writes `user://shop_entitlements.json`:
the age band, the bought unlocks, `pass_active` and `pass_until`, and the time. Never the Riftglass balance,
prices, limits or account tokens. At start without a connection `Billing.load_cache()` puts it into
`Billing.state` (marked `cached`), so bought team slots, storage boxes, settings and the pass keep working.

- The copy carries a SHA-256 check value (salt, device id, content); an edited file is ignored. This is a
  deterrent, not a lock: the server stays the authority and replaces the copy at the next connection
  (`ShopEffects.apply_unlocks` then trims what a refund took back).
- A clock set back before the copy was written makes it void; the pass counts as ended after `pass_until`.
- The local test server never writes or reads the copy, so tests stay independent.

## Server

No server change and no migration. Everything runs on the existing functions (`hello`, `session_claim`,
`save_list`, `save_get`, `save_put`, `shop_state`, ...). Should a later step need one, its timestamp must be
after 20261128010000.

## Store texts

Every App Store and Play description (20 locales, 14 languages) says the story plays offline and that friends,
leagues and the shop need internet; the review notes and the Play app access text say how to test it
(airplane mode). `tools/store/listing_check.py` rejects the old online-only sentences (`ONLINE_ONLY`) and
review notes over 3999 characters. The terms (NUTZUNGSBEDINGUNGEN 2.2, TERMS_EN 2) and the privacy note say the same; `LegalInfo.TERMS_VERSION` is unchanged, the clause only loosens a restriction (lawyer to confirm).

## Code

| Piece | Where |
| --- | --- |
| Connection state, background retries, sync | `scripts/online/Online.gd` |
| The offline mark | `scripts/online/OfflineMark.gd` |
| Needs-internet line, reading-size helper | `scripts/online/OnlineErrors.gd` (`NEEDS_INTERNET`, `say_offline`) |
| Title without a connection | `scripts/ui/TitleScreen.gd` (`_go_online`, `_connect_capped`, `_after_connect`) |
| No purchase offline, entitlement copy | `scripts/shop/Billing.gd`, `ShopMenu._run`, `ShopScreen.starter_popup_now` |
| Texts | `tools/i18n/de_offline.py`, `tools/i18n/locales_offline.py` |

## Tests

`tests/unit/test_offline_start.gd` (start offline, new game, play, online, sync; save point; anti-cheat on the
first upload; conflict with another device; other device mid-game), `test_offline_play.gd` (drop mid-battle
without a pause, needs-internet lines for shop, league and friends at 13 pt / 44 pt in every era, no store
purchase or Riftglass offline, kids lock, entitlement copy), `test_offline_title.gd` (no connection question,
a hanging server holds the title at most 4 s), plus the rewritten `test_reconnect_fade.gd`,
`test_ux_online.gd`, `test_walk_after_pause.gd` and `test_online.gd`.

Screenshots: `tools/c100_offline_shots.gd` (title offline, the mark in the world, the shop and league lines):

    xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 390x844 -s res://tools/c100_offline_shots.gd -- out_dir de
