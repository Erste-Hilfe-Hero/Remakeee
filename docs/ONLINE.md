# Online (Chimora is online only)

Chimora only runs with an internet connection. The server keeps every journey, the phone keeps a cache copy.
The server is our own machine at **Contabo** in Germany (Cloud VPS), running the same open-source programs
as Supabase (Postgres, GoTrue for sign-in, PostgREST for the API) behind Caddy for HTTPS. Everything for it
is in `server/`. The game would also work with a Supabase Cloud project, see the end of this page. The
ideas list behind this is the "Chimora online: 200 ideas" artifact in the project.

## How it works

- **Account:** the first start makes an account without email (anonymous sign-in). The game never
  asks for an email. Moving to a new phone works with a one-time **transfer code** (Settings, Account),
  valid for 7 days. Only its hash is stored.
- **Saves:** `SaveManager.save_game()` writes the local cache, then `Online.note_saved()` sends it to the server
  with the revision it last saw. If another device saved in between, the server refuses and the title screen
  asks which journey to keep. The server also refuses impossible saves (level over 100, more than 6 in the
  party, negative money).
- **Connection lost while playing:** the game pauses behind a "Reconnecting" screen and retries every 4 seconds.
  Unsent saves go up as soon as it is back.
- **Server clock:** the daily find, the weekly challenge and the festivals use the server's time, so changing
  the phone's clock does nothing.
- **Old builds:** `server_config.min_version` sends older builds to the store. `Online.CLIENT_VERSION` is
  stamped by CI together with the version code.
- **Notice:** `server_config.motd` shows a short text on the title screen (for example planned maintenance).

## Playing together

All under Menu, Friends. Spirlings are never gifted; they can be traded between friends once the flag
`trade_spirling` is on (see Trading). There is no free text anywhere.

- **Friends:** 8-character friend code, requests, a list with online dot and in-game place, Wanderer card,
  friendship level 1-5 (points from gifts, echo help and duels). 100 friends at most. 20 requests per hour.
- **Lantern Mail:** one gift per friend per day (two from friendship level 3); the item is rolled on the server when it is opened, from the
  open table in `server_config.gift_table` (the game shows the chances). Ten opens per day. Greetings are
  set phrases (`scripts/online/Phrases.gd`, the server only stores the number), plus waves and thanks.
  Mail is deleted after 30 days.
- **Echo partner:** after losing to a Warden once, and before climbing the echo tower, the game offers a
  friend's echo team to fight beside you. The AI steers it, the friend does not need to be online, and its
  levels are capped to your level cap.
- **Echo duel:** fight a friend's echo team. Everyone is on Lv30, nothing is lost, and the friend gets a note.
- **World goal of the week:** everyone adds to one goal (battles won, bonds or rests, taking turns by week).
  Each player can add 5 per call and 500 per week. Everyone who helped can claim the rewards at 25, 50, 75
  and 100 percent.
- **Weekly board:** the weekly challenge sends rounds won * 100 + health left. Friends board by default;
  the world board shows strangers without names.
- **Safety:** blocking ends the friendship and removes their mail at once and makes your code look unknown
  to them. Reports go to table `reports`. Parents can switch friends, greetings and gifts off under
  Settings, Account (the journey stays online).

## Code

| Part | Where |
| --- | --- |
| Database tables and functions | `supabase/migrations/*.sql` |
| The server itself (Docker, HTTPS, backups, install script) | `server/` |
| Tests for the SQL (throwaway Postgres) | `tools/online/test_sql.sh`, `tools/online/sql_test/` |
| Autoload: sign-in, saves, heartbeat, reconnect | `scripts/online/Online.gd` |
| Real server client (HTTPS) | `scripts/online/SupabaseBackend.gd` |
| Local stand-in with the same rules (tests, builds without a server) | `scripts/online/LocalBackend.gd` |
| Account menu | `scripts/ui/AccountMenu.gd` |
| Friends, mail, world goal, board | `scripts/ui/FriendsMenu.gd` |
| Echo teams (snapshot, build, duel copies, board score) | `scripts/online/EchoTeam.gd` |
| Echo partner and echo duel in the world | `scripts/overworld/Overworld.gd` (`pick_echo_partner`, `echo_duel`) |
| Battle referee: checks an uploaded battle (shared by server and game) | `scripts/battle/BattleReferee.gd` |
| Battle referee service (container, loop, runner) | `server/referee/` |
| End-to-end referee test (local Postgres + Godot) | `tools/online/test_referee.sh` |
| League menu and league battle | `scripts/ui/LeagueMenu.gd`, `scripts/overworld/Overworld.gd` (`league_battle`) |
| League rules (fair rows, learnable moves, tiers) and Glicko-2 | `scripts/online/LeagueRules.gd`, `scripts/online/Glicko.gd` |
| Species and learnsets for the database (`game_species`) | `tools/online/game_data_sql.py` |

Security model: every table has row level security on and no policies, and players have no table rights. The
game only calls the `security definer` functions, which check `auth.uid()` and every rule themselves.
New server features add a migration file, a SQL test and the same rule in `LocalBackend`.

### Battle referee

After a battle that counts online (today the echo duel; later leagues, raids and live duels) the game
calls `battle_submit(kind, ref, replay, claim)`: the replay is the `BattleReplay` snapshot (seed, both
teams, every input) and the claim is what the game says came out (winner, Vigor left of every Spirling
on both sides, rounds). `_referee_check` puts the battle data, without the account, into
`battle_queue`. The `referee` container (`server/referee/run.sh`) takes up to 20 queued battles every
2 seconds, plays them again with the game's own battle code (`BattleReferee.check`, Godot 4.7.2
headless) and writes `ok`, `mismatch` or `error` into `battle_results`; a trigger copies the verdict to
`battles.status` and removes the queue row. `battle_status(id)` shows a player the state of their own
battle (`pending` = "being checked"), and `_battle_ok(id)` is what leagues, raids and weekly scores ask
before anything counts.

The referee logs in as the database user `chimora_referee` (password `REFEREE_DB_PASSWORD` in
`server/.env`, made by `setup.sh`). It may only read `battle_queue` and read or insert into
`battle_results`; PostgREST cannot switch to it, and its container has no port. `setup.sh` builds it from
the repository root (`server/referee/Dockerfile`, compose profile `referee`), so the game project must
sit next to `server/` (`/opt/chimora/project.godot`); otherwise it says so and the rest runs as before.
Look at it with `docker compose --profile referee logs referee`. The limit per player is
`server_config.battle_submit_limit` (60 an hour).

### Leagues

There are two leagues with separate tables: `league_fair_entries` (the fair league, the default) and
`league_open_entries` (the open league, every advantage allowed). `league_join(league, pick)` takes only
species names and move choices; the server rebuilds the team from the stored team (`_league_team`). In the
fair league every Spirling fights at `league_fair_ring` (50) with base stats only (no spark, even temper)
and only moves it can learn by Ring 50, its own or from earlier forms, checked against `game_species`.
`game_species` is filled from `data/spirlings.json` by `tools/online/game_data_sql.py` (`setup.sh` does it
when `../data` exists). The open league keeps the real team and Ring. The joined team is frozen as its
own row, so a later save change does not touch it.

`league_find(league, waited)` looks for an opponent within 100 rating points, widening by 50 every
10 seconds up to 400 (`league_search_*`); blocked players never meet. The server picks the seed and both
teams (the opponent is an echo played by the AI) and stores them in `league_matches`. `battle_submit`
for `league_fair` / `league_open` ignores the client's teams and seed and lets the referee replay the
server's battle with the uploaded inputs. Only an `ok` from the referee rates the player (Glicko-2 in
`_league_rate`, start 1500 / 350 / 0.06); players see tiers (Spark, Ember, Flame, Glow, Beacon, each I to
III), not numbers. A season (`league_seasons`) lasts `league_season_days` (42); in the last
`league_closing_minutes` (30) nothing is rated, `paused` stops joining, and the next season starts by itself.
Both leagues can be switched off with the flags `league_fair` and `league_open`.

In the game, Menu > Leagues (`scripts/ui/LeagueMenu.gd`) shows the fair league first and the open league
right below it. `hello` returns `flags`, the feature keys that are on for the game's version, and menus
hide what is off (`Online.flag_on`). "Find a battle" asks `league_find` every 3 seconds for up to a
minute; `Overworld.league_battle` builds the battle from the server's seed and teams
(`BattleReferee.from_expect`), uploads it with `battle_submit` and tells the player it is being checked.

Builds without a server address use `LocalBackend`, a test server that lives on the phone. The account menu
then says "test server on this phone". The debug APK from CI works like this until the secrets below exist.

### League ranks, placement, shield, quit wait, season reward (Online 100, points 12-13, 16-20)

Values in `data/league_ranks.json`; `tools/online/game_data_sql.py` writes them to `server_config.league_ranks`
(migration `20261111000030_league_ranks.sql`, rules mirrored in `LeagueRules.gd` and `LocalBackend`).
- **Ranks (12):** seven ranks by rating floor, Apprentice to Map Master. The tiers stay as before.
- **Placement (16):** the first `placement_games` (5) rated battles show no rank.
- **Shield (17):** a promotion gives `shield_games` (3) battles in which the rating cannot fall below the new
  rank's floor (`entries.shield`).
- **Echo fallback (18):** after `echo_after` (45) seconds of searching any rating is fine; with nobody at all
  the player's own league team is the echo opponent and the battle is not rated (`echo: true`).
- **Quit wait (20):** a found match that is given up for a new search at least `quit_grace` (30) seconds later
  counts as left. From `quit_free` (2) left matches in a day, `league_find` answers `quit_wait` with `wait`
  seconds: 60, doubling, at most 900.
- **Season reward and title (13, 19):** `league_reward(league, slot, rev)` once per finished season and league:
  the item of the final rank into the stored bag, the rank as title and the frame id `season_<n>_<rank>`
  (table `league_awards`, listed as `titles` in `league_info`). Menu > Leagues shows "Season reward".

### Live duels (Online 100, area 1)

Behind the flag `live_duel` (Friends > Live duels, `scripts/ui/LiveDuelMenu.gd`). Values in `data/live_duel.json`,
written to `server_config.live_duel`; migration `20261111000040_live_duel.sql`, same rules in `LocalBackend`,
helpers in `scripts/online/LiveDuel.gd`. `live_invite(code)` (friends only, `invites_per_hour`), the friend
answers with `live_answer`; both see up to 6 of the other's team and `live_pick` 3. Then each round both send
`live_move(id, round, input)`; the round closes when both are in, and the server keeps the inputs, the seed and
the `turn_seconds` (30) clock. A side away longer than the clock plus `reconnect_seconds` (60) loses
(`_live_tick`). `live_forfeit` gives up, `live_emote` stores only the number of a set phrase, `live_finish`
takes each side's winner (different answers void the duel), `live_rematch` invites again. Not done yet: the
battle scene does not play the rounds from `live_state` yet, and the referee does not check live duels.

## Where it runs now

On Ali's existing Contabo server (161.97.102.171), next to Nyrathen and Dranbleib, at
`https://chimora.161-97-102-171.sslip.io`. That machine's Caddy (`nyrathen-proxy`) already owns ports 80 and
443, so Chimora runs in shared mode: its own containers (project `chimora`, folder `/opt/chimora`) with no
public ports, reached through the proxy, which forwards its address to `chimora-gateway`. `server/proxy_site.sh`
does that in two places:
1. The proxy's running config, through Caddy's admin API: it adds only Chimora's route and TLS policy, loads
   it with a validated graceful reload, checks that everything else is unchanged and loads the saved copy
   otherwise (copies in `/opt/chimora/server/backups/`).
2. The proxy's Caddyfile on the host (`/srv/nyrathen/prod/Caddyfile`, approved by Ali on 4 Nov): one site
   block between `# chimora-begin` and `# chimora-end`, validated first and never loaded by Chimora. Nyrathen's
   own deploys (`tools/ci/host-setup.sh`, `nyrathen-caddy-play.yml` in lifekit) load that file and keep
   unmarked blocks, so Chimora survives them. Before this, each Nyrathen deploy dropped the route and the
   address failed with a TLS error until it came back.
A cron job (`/etc/cron.d/chimora-proxy`) re-runs it every 10 minutes as a fallback.
The firewall and the other services are not touched.

Deploys run from the lifekit repository (it holds the Contabo access): workflow "Chimora on Contabo" on
branch `claude/chimora-contabo`. A commit whose message starts with `run:chimora-inspect` only looks at the
machine; `run:chimora-deploy` installs or updates Chimora from this repository and runs the smoke test from
outside (its two test accounts are deleted again). Builds read address and public key from
`https://chimora.161-97-102-171.sslip.io/chimora.json` (default in `export.yml`; the secret
`CHIMORA_SERVER` overrides it).

## Setting up the server on a new machine

1. At [contabo.com](https://contabo.com) order a **Cloud VPS 10** (about 5 EUR a month is enough to start).
   Region: **European Union (Germany)**. Image: **Ubuntu 24.04**. Choose a root password.
2. Sign the data processing agreement (AV-Vertrag) in the Contabo customer panel and check the address in
   `docs/legal/DATENSCHUTZ.md` and `PRIVACY_POLICY_EN.md` against it.
3. GitHub, repository settings, Secrets and variables, Actions: add
   - `CHIMORA_SERVER_IP`: the server's IP address (from Contabo's email),
   - `CHIMORA_SERVER_PASSWORD`: the root password,
   - `CHIMORA_SERVER`: `https://<ip with dashes>.sslip.io`, for example `https://203-0-113-7.sslip.io`.
4. GitHub, Actions, **Game server**, Run workflow. It copies `server/` and the migrations to the machine and
   runs `server/setup.sh`: Docker, firewall (only ports 22, 80, 443), keys, database, HTTPS certificate,
   nightly backups (kept 14 days in `/opt/chimora/server/backups`) and automatic security updates.

From then on every CI build reads the address and the public anon key from `<CHIMORA_SERVER>/chimora.json`
and talks to the real server. Store builds (release AAB, iOS) fail without it, because an online-only game
cannot ship without its server. Every push to `main` that changes `server/` or `supabase/` updates the
machine again; data and keys stay.

No domain is needed: `sslip.io` turns the IP into a name, so Let's Encrypt can issue the certificate. With an
own domain later, point an A record at the IP, run the workflow with that domain and change `CHIMORA_SERVER`.
Note that changing the address needs a new app build, so pick the domain before the store launch.

Without GitHub: `ssh root@<ip>`, copy the repository there, run `sudo bash server/setup.sh`.

`server/smoke_test.sh` plays a short session (sign-in, save, load, friend request) against a server; CI runs
it on every pull request that touches `server/` or `supabase/` (workflow **Game server**).

### Looking into the database

There is no web dashboard (it would be one more thing open to the internet). Log in with
`ssh root@<ip>`, then `cd /opt/chimora/server && docker compose exec db psql -U postgres -h localhost`.

### Backups

`server/backup.sh` runs every night at 3:30. To copy them off the machine as well, download
`/opt/chimora/server/backups` now and then, or add Contabo Object Storage later. Restore:
`docker compose exec -T db pg_restore -U postgres -h localhost -d postgres --clean < backups/<file>.dump`.

### Alternative: Supabase Cloud

Create a project in Frankfurt (eu-central-1), switch on anonymous sign-ins, run the files in
`supabase/migrations/` in the SQL editor, and set the secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY` instead
of `CHIMORA_SERVER`. Supabase is a US company, so the privacy texts would need the transfer clause again.

## Changing things without an app update

In the database (see "Looking into the database"), table `server_config`, for example
`update server_config set value = '1004' where key = 'min_version';`:

| key | value | effect |
| --- | --- | --- |
| `min_version` | `1004` | builds with a lower version code must update |
| `motd` | `"Maintenance today 3-4 am"` | notice on the title screen (`""` = none) |
| `party_max` | `5` | most Spirlings in a saved team and an echo team |
| `level_max` | `60` | highest Ring in echo teams, the open league and duels |
| `save_level_max` | `96` | highest Ring in saves (Spirling.ERA_MAX_LEVEL, Halcyra) |
| `duel_ring` | `50` | Ring everyone fights at in an echo duel |
| `save_schema_max` | `1` | newest online save format the server takes (`Online.SAVE_SCHEMA`) |

Also `gift_table`, `gift_open_limit`, `friend_limit`, `goal_rotation` (list of `{"kind", "target"}`;
kinds `battles`, `bonds`, `rests`), `goal_rewards` (four item ids) and `goal_user_cap`.

Table `banned_words`: words a Wanderer name may not contain.

Table `feature_flags` (key, `enabled`, `min_version`): switches the new online parts on one by one,
for example `update feature_flags set enabled = true where key = 'trade';`. Keys: `league_fair`,
`league_open`, `live_duel`, `trade`, `bund`, `raid`, `trade_spirling`, `rift_board`, `league_board`, `events`,
`daily_gift`, `lend`, `invite`. All start switched off.

## Bunds

Bunds (plan area 7) wait behind the flag `bund`; switch them on with
`update feature_flags set enabled = true where key = 'bund';`. A bund has at most `bund_max` (30)
members, one leader, helpers and members, and a name made of two word numbers into
`scripts/online/BundWords.gd` (never reorder those lists, only append). Leaving is always possible;
when the leader leaves or deletes the account, the oldest helper (else the oldest member) leads.
A leader dissolves a bund of 3 or more only by confirming again after 24 hours. Blocked players
cannot invite or ask each other. Tables: `bunds`, `bund_members`, `bund_invites`; menu
`scripts/ui/BundMenu.gd` (Friends, Bund).

**Online 100, area 4** (`data/bund_rules.json`, migration `20261111000060_bund_more.sql`, `BundRules.gd`):
`bund_donate(slot, rev, item, count)` takes items from the stored bag (at most `donate_daily` a day) and gives the
bund renown (`xp_per_item` each) and week goal progress; the bund rank is 1 + renown / `xp_per_level`, at most 20.
At `goal_target` items in a week every member takes `goal_reward` once (`bund_goal_claim`). `bund_board()` lists
bunds by renown. The leader sets language and "open" (`bund_settings`); `bund_search(lang)` lists bunds that are
not full, most active first, and `bund_join(bund)` joins an open bund at once or sends a request. Bund rank perks
are not built yet.

### Online events (Online 100, area 7, points 61, 63-66, 68-70)

Behind the flag `events` (Friends, Events; `scripts/ui/EventsMenu.gd`). Values in
`data/online_events.json`, written to `server_config.online_events`; migration
`20261112000070_online_events.sql`, same rules in `scripts/online/LocalOnlineEvents.gd`, shared helpers in
`scripts/online/OnlineEvents.gd`; fixed events in its `events` list
become rows of `online_events` at every deploy (`tools/online/game_data_sql.py`). An event can also be
added on the server alone, without a store update (69):

```sql
insert into public.online_events (id, kind, starts_at, ends_at, data) values ('festival-2027-01', 'festival',
  '2027-01-01T00:00:00Z', '2027-02-01T00:00:00Z',
  '{"name": {"en": "Frost month", "de": "Frostmonat"}, "goal_kind": "rests", "target": 30000,
    "rewards": ["tonic", "strong_tonic", "spark_drop", "max_tonic", "spark_charm"]}');
```

- **Weekly events:** each week (and the next, for the calendar) gets `week-<year>-w<nn>` from the
  `weekly` rotation by ISO week number, made on the first call of the week.
- **Festivals (61, 64):** a shared goal fed by world-goal steps (`community_add`) of `goal_kind` (`add_max` 5 per step,
  `user_cap` 500 per player). Tiers at `tiers` percent of the target: 25, 50, 75, 100 and the extra tier
  150; everyone who helped takes each reached tier once (`event_claim(event, tier, slot, rev)`) while
  it runs and up to `recap_days` (14) after.
- **Rule weeks (63):** kind `board` with `rules` (`elements`, `max_stage`). `event_enter(event, team)`
  takes 1-6 different species that fit; the deploy writes the fitting species as `allowed`
  (`OnlineEvents.allowed` in the game does the same). The board counts referee-confirmed Rift wins
  after entering (optional `rift` to name one Rift). Not done yet: the server does not tie the Rift
  battle's team to the entered team.
- **Sighting days (65):** kind `sighting` with `species` and `boost`; `EncounterTable.weight_of`
  multiplies those species while one runs (the game fetches the calendar after `hello`).
- **Calendar (66):** `event_list()` shows running events, those starting within `calendar_days` (35)
  and those that ended within `recap_days`, with the own score, tiers, entry, award and titles.
- **Event board and titles (68):** `event_board(event, friends)` like the weekly boards. After the end,
  `event_reward(event, slot, rev)` gives the first title in `titles` the final rank reaches (first, top
  ten, best tenth, took part) and its item from `title_items`, once (`event_awards`).
- **Recap (70):** `event_recap(event)`: own score, place of how many, best score, tiers reached, award.
Tables `online_events`, `event_scores`, `event_awards`; events are deleted 90 days after their end.
Not done yet: weekend tournament (62) and phone notices at an event start (67, needs a push service).

## Raid Rifts

Raid Rifts (plan area 7) wait behind the flag `raid`. A player opens a Rift with 1 to 3 friends or
members of the same bund (`raid_open`, never with blocked players). The server picks a guardian from
`raid_guardians` at Ring `raid_level`; its strength is `raid_base` times 100/140/175 % for 2/3/4
players. Each member has `raid_tries` (3) attempts a day for `raid_hours` (48). An attempt
(`raid_start`) is a fair-league battle the server sets up (seed, teams, at most `raid_rounds` rounds);
only the inputs come from the game, and the referee's own count of the Vigor the guardian lost comes
off its strength. Once the guardian falls, everyone with at least `raid_share_min` percent of the
damage takes the same reward (`raid_claim`), rolled by the server from the open table `raid_rewards`.
Attempts cost nothing; nothing is for sale. Rifts are deleted 7 days after they close. Tables:
`raids` (no account ids), `raid_members`, `raid_attempts`; menu `scripts/ui/RaidMenu.gd`
(Friends, Raid Rifts).

**Online 100, area 3** (`data/raid_rules.json`, migration `20261111000050_raid_more.sql`, `RaidRules.gd`):
`raid_open(codes, tier)` takes a tier (Easy 70 % strength Ring 50, Normal as before, Hard 150 %). The guardian
is the week's one (`week % pool`), and with `legendary_chance` (5) percent a legendary from `legendaries` at
`legendary_hp` (150) percent. In `raid_claim` the member with the most damage gets `top_bonus` (1) more.
`raid_board()` lists the fastest won Rifts without names (Raid Rifts > Fastest Rifts).

## Trading

Trading (plan area 7) waits behind the flag `trade`. Friends from friendship level
`trade_min_level` (3) whose friendship was accepted at least `trade_min_days` (7) ago can open a
trade (`trade_open`, one open trade per pair, at most `trade_max_open` per player, never with
blocked players). Only items in `trade_items` can be traded; `tools/online/game_data_sql.py` fills
it from `"tradeable": true` in `data/items.json` at every deploy. Shop items are never
tradeable (a test checks that no item from `data/shop.json` is on the list). The server is the
trustee: `trade_put` moves the offer out of the bag of the stored save at once, `trade_confirm` must
name the other side's current offer, and once both confirmed each side takes the other's items
with `trade_collect`. Any change of an offer resets both confirmations; `trade_cancel` (or 7 days
without finishing) gives everyone their own items back. Every change of a save happens in a call
of its own device, which sends the revision it knows (`sync_first` otherwise), so the game changes
its bag the same way and saves on top of the new revision. Tables: `trades` (no account ids),
`trade_sides`; menu `scripts/ui/TradeMenu.gd` (Friends, Trades).

**Spirlings** (online step 1, flag `trade_spirling`): `trade_put_spirlings(trade, slot, rev, uids)` puts
up to `trade_max_spirlings` (3) Spirlings from team or storage into the trade; they leave the stored save
at once (`took`), dropped ones come back to storage (`back`). Never tradeable: a Spirling holding a
Keepsake, one with a shop boost (Gleam, Power Core, crystals), a favourite, and the team's last
Spirling. `trade_confirm(trade, theirs, their_mons)` must name the other side's Spirlings by uid
(the old two-argument call only works while the other side offers none). On the way the server keeps
every value and the **origin era** (`origin_era` 1-4, set when bonded, 1 for older saves) and drops
the nickname (no free text between players), the storage box and the favourite mark. Collected
Spirlings go into storage.

### Trading and gifting (Online 100, area 5)

Migration `20261112000050_trade_gifts.sql`, values in `data/trade_gifts.json` (written to
`server_config.trade_gifts` by `game_data_sql.py`), the same rules in `scripts/online/LocalTradeGifts.gd`,
tests `tests/unit/test_trade_gifts.gd` and `tools/online/sql_test/test_trade_gifts.sql`.

- **Trades per day (42):** `trade_confirm` refuses the confirm that would finish a trade once either side
  finished `trades_per_day` (5) trades this server day (`day_limit`, `their_day_limit`).
- **Trade history (50):** every finished trade writes one row per side into `trade_log` (items, and
  Spirlings only as species, Ring and era). `trade_history()` lists the last `history_days` (30) days,
  with the partner's name unless blocked; older rows are deleted. Trades, History in the menu.
- **Wish list (46):** `wish_set(items)` keeps up to `wish_max` (3) items from the gift table or the
  tradeable items in `profiles.wishes`; `friends_list` shows each friend's `wishes` (Wayfarer card)
  and `gifts_left`. Friends, My wish list.
- **Two gifts a day (47):** `gift_send` allows `gifts_per_day_close` (2) gifts to a friend of
  friendship level `close_level` (3) or more, else `gifts_per_day` (1).
- **Greeting cards (48):** `card_send(code, species, phrase)` sends mail kind `card`: a set phrase of
  the post list and a species that is in the team or storage of one of the sender's stored saves, at
  most `cards_per_day` (10). Friend, Send a card.
- **Thanks (49):** `gift_thank(id)` thanks once for an opened gift: the friend gets a thanks note and
  the pair `thanks_points` (2) friendship points (`mail.thanked`).
- **Lending (45, flag `lend`):** `lend_offer(code, slot, uid)` lends a copy of a Spirling of the stored
  save to a friend of friendship level `lend_min_level` (3): no nickname, box, favourite mark or
  Keepsake, never a shop-boosted one; the original stays. At most `lends_per_day` (3) per lender and
  `borrow_max` (1) open loan per borrower; a loan ends after `lend_hours` (48). `lend_use(loan, kind)`
  (kind `raid` or `live_duel`) hands the borrower the copy once; `lend_end` ends an unused loan;
  `lend_list` shows both sides. Table `spirling_loans`. Not done yet: the raid and live duel screens
  do not offer the borrowed Spirling, so `lend_use` has no caller in the game yet.
- **Spirlings stay untradeable (44)** as long as the flag `trade_spirling` stays off.

### Friends and the shared world (Online 100, area 6, points 53, 55-57, 59, 60)

Migration `20261112230020_friends_more.sql`, values in `data/friends_more.json` (written to
`server_config.friends_more` by `game_data_sql.py`), the same rules in `scripts/online/LocalFriendsMore.gd`
and `FriendRules.gd`, menu `scripts/ui/FriendsMoreMenu.gd`, tests `tests/unit/test_friends_more.gd` and
`tools/online/sql_test/test_friends_more.sql`.

- **Levels 6-10 (56):** `_level` reads the point floors from `levels` (levels 1-5 keep 0, 10, 30, 60, 100;
  6-10 at 150, 220, 300, 400, 520). Each level with an entry in `level_rewards` gives its item once per
  friend (`friend_level_claim(code, level, slot, rev)`, table `friend_level_claims`); `friends_list` lists
  them as `level_ready`.
- **Favourites (59):** `friend_favorite(code, on)`, at most `favorites_max` (10); favourites come first in
  `friends_list` (`fav`) and carry a "+" in the list.
- **Task of the day (57):** the kind is `pair_tasks[day % n]` (wave, greeting, gift), the same for everyone.
  Once both friends sent each other that mail today, each takes `pair_reward` once
  (`pair_task_claim(code, slot, rev)`, table `pair_task_claims`, kept 7 days) and the pair gets
  `pair_points` (3) friendship points once. `friends_list` shows it as `task`.
- **Rank on the Wanderer card (53):** `friends_list.rank` is the fair league rank of the friend's latest
  season (-1 = none or placement).
- **Suggestions (60):** `friend_suggestions()` lists the opponents of the player's own league battles of the
  last `suggest_days` (14) days who are not friends, not asked, not blocked and have friends switched on,
  at most `suggest_max` (5), without name or code. `friend_suggest_request(match)` sends the request.
- **Invite link (55, flag `invite`):** the link is `chimora://friend/<code>` (DeepLink route `friend`,
  asks before it sends). A journey younger than `invite_days` (7) redeems one code once
  (`invite_redeem`, table `invites`), which sends a friend request; once accepted, both take
  `invite_reward` with `invite_claim(slot, rev)`, the inviter for at most `invite_max` (10) friends.
  `invite_state()` shows the counts.

Not done in this area: friends as figures in your town (51), visiting a friend's camp (52) and friends
nearby (54).

## Weekly boards (online step 1)

Under Friends, Weekly board. The weekly challenge board is as before. With the flag `rift_board`
the game uploads every won Warden battle (`battle_submit`, kind `rift`, ref = the Rift id, which must
be in `known_ids` kind `rift`, filled from every `"warden"` in `data/` by `game_data_sql.py`). Table
`rift_runs` keeps the claimed rounds; `rift_board(rift, friends)` shows each player's fewest rounds
this week, counting only battles the referee replayed as `ok`. With the flag `league_board`,
`league_board(league, friends)` counts this week's rated league wins (only referee-confirmed ones
are rated). Both show names only for you and your friends, never blocked players, top `board_rows`
(20) plus your own row. Rift runs are deleted after 35 days.

## Daily gift (online step 1)

With the flag `daily_gift`, Friends, Daily gift shows the open table `daily_gift_table` with its
chances; `daily_gift_claim(slot, rev)` rolls one item on the server once per server day and puts it
into the stored save's bag (like a trade, so the device sends the revision it knows). Nothing is sold
there and no shop link is shown. Table `daily_gifts`, kept 7 days.

## Earlier saves

Every change of a stored save (saving, a trade, a restore) puts the version before it into
`save_history`, which keeps the newest `save_history_keep` (5) per slot. Settings, Account, Earlier
saves lists them with date, place and play time (`save_history_list`); `save_restore` makes one the
newest version again, and the replaced one stays in the list. When the running journey is replaced,
the game reads the slot again and returns to the title.

## One device at a time

After `hello` the game calls `session_claim(p_token)`: a fresh start (empty token) gets a new
token, stored in `profiles.session_token`; a device that sends its old token keeps it, unless
another device claimed the account meanwhile (`other_device`). Every call carries the token in
the header `x-chimora-session`. The trigger `saves_device` refuses changed saves from a device
whose token is not the newest one (saving, trades, restores), and `presence` returns
`other_device`. The old device then goes to the title, which says "Signed in on another device"
and only takes the account back when the player picks "Play on this device". Calls without the
header (older builds) are not checked; moving the account with a transfer code claims anew.

## Small actions while the connection is weak

Set phrases, waves, thanks and world goal steps go through `Online.send_small`: each gets its own
id and waits in `Online.actions` (at most 50, kept in the session file) until it is sent with
`action_once(p_id, p_fn, p_args)`. The server runs `mail_send` or `community_add` and keeps the id
for 2 days in `action_done`, so an action sent twice counts once. After a reconnect the queue goes
out in order; a menu shows "It goes out as soon as the connection is back." for a waiting action.

## Set phrases and names

There is no free text anywhere. Every place that shows set phrases has its own list of allowed
phrase numbers in `server_config.phrases_allowed` (`post`, `duel`, `bund`, `raid`), the same lists
as `Phrases.CONTEXTS`; the server checks them with `_phrase_ok(context, n)`. Append new phrases at
the end of `Phrases.LIST` and add their numbers to the lists in both places. Wanderer names hold
1 to 10 letters, digits or spaces, at most 3 digits in total and nothing like "www" or "http";
anything else becomes "Wanderer" and the end of the friend code.

## Reports and decisions (Ali, about once a week)

Every report gets a number at once (`report_in`, the player sees "Your report has number 12"). Open
reports:

```sql
select id, target_name, reason, context, object_id, created_at from public.reports where status = 'open' order by id;
```

Decide each one in the database console (players cannot call these functions):

```sql
select public.moderation_decide(12, true, 'name_reset');   -- upheld: name_reset, warning or league_block
select public.moderation_decide(13, false, null);          -- rejected, no breach
```

An upheld decision sends the reported player a statement of reasons in the game (DSA Art. 17:
measure, reason from the fixed list, section 4 of the terms, a person decided, objection possible for 6
months), under Account, Messages from the team. The reporter always gets the result. Reasons: 0 name,
1 greetings, 2 cheating, 3 something else.

Objections (DSA Art. 20) come in as `appeals`:

```sql
select a.id, a.reason, n.body, a.created_at from public.appeals a join public.notices n on n.id = a.notice_id
where a.status = 'open';
select public.appeal_answer(4, true);   -- true: decision changed (a league block is lifted), false: kept
```

A name that was reset stays reset after a changed decision; the player picks a new one.

Reports from the web form `/melden` (DSA Art. 16, also without an account) land in `web_reports`.
Their numbers start with W on the page. Answer them by e-mail when a contact is given:

```sql
select id, code, reason, details, contact, created_at from public.web_reports where status = 'open' order by id;
update public.web_reports set status = 'upheld', decided_at = now() where id = 3;  -- or 'rejected'
```

To act on the player, turn it into a normal report, so the player gets the statement of reasons:

```sql
insert into public.reports (reporter, target, target_name, reason, context)
select null, id, name, 0, 'friends' from public.profiles where code = '<code>' returning id;
select public.moderation_decide(<that id>, true, 'name_reset');
```

## Refused saves (anti-cheat)

`save_put` compares every save with the one before it in that slot (plan area 7, items 2921-2925):
money may grow by at most `max_money_per_min` (5000) per minute played, play time by at most the real
time since the last save plus `save_time_slack` (300 seconds), and every Spirling kind, move and item
must be in `known_ids` (filled from `data/*.json` at every deploy by `tools/online/game_data_sql.py`).
Less play time than before counts as a new journey in that slot, so money then counts from
`start_money`. Keys in `save_server_keys` (league, raid, trades, premium currency …) are dropped from
every save, because the server keeps those itself. A refused save answers `refused` with a reason and
is noted in `cheat_flags` (the same refusal once per 10 minutes). With `cheat_flag_limit` (3) notes in
`cheat_flag_days` (7) the account is out of leagues (`under_review`) until Ali clears it:

```sql
select p.code, f.reason, f.at, f.detail from public.cheat_flags f join public.profiles p on p.id = f.user_id
order by f.at desc limit 50;
update public.profiles set cheat_cleared_at = now() where code = '<CODE>';
```

## Privacy: export, deletion, retention

`data_export()` returns every row of every public table that has a uuid (account) column, found
through the system catalog, so new tables are covered without code changes; the player's own id reads
"you", other players "another player", and hash or token columns are left out. `delete_account()`
deletes the auth user and then every row anywhere that still carries the id. `tools/online/sql_test/test_privacy.sql`
checks both against the catalog. `hello` runs `_privacy_cleanup()` about once in 100 calls: battle
recordings and league matches older than 30 days, refused-save notes older than 6 months and league
standings of seasons that ended more than a season ago are removed. The record of processing activities is
`docs/legal/VERARBEITUNGEN.md`; add a row there before switching on a new online feature.
