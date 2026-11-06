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

All under Menu, Friends. Spirlings are never traded or gifted, and there is no free text anywhere.

- **Friends:** 8-character friend code, requests, a list with online dot and in-game place, Wanderer card,
  friendship level 1-5 (points from gifts, echo help and duels). 100 friends at most. 20 requests per hour.
- **Lantern Mail:** one gift per friend per day; the item is rolled on the server when it is opened, from the
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
| `level_max` | `60` | highest Ring in saves and echo teams |
| `duel_ring` | `50` | Ring everyone fights at in an echo duel |
| `save_schema_max` | `1` | newest online save format the server takes (`Online.SAVE_SCHEMA`) |

Also `gift_table`, `gift_open_limit`, `friend_limit`, `goal_rotation` (list of `{"kind", "target"}`;
kinds `battles`, `bonds`, `rests`), `goal_rewards` (four item ids) and `goal_user_cap`.

Table `banned_words`: words a Wanderer name may not contain.

Table `feature_flags` (key, `enabled`, `min_version`): switches the new online parts on one by one,
for example `update feature_flags set enabled = true where key = 'trade';`. Keys: `league_fair`,
`league_open`, `live_duel`, `trade`, `bund`, `raid`. All start switched off.

## Bunds

Bunds (plan area 7) wait behind the flag `bund`; switch them on with
`update feature_flags set enabled = true where key = 'bund';`. A bund has at most `bund_max` (30)
members, one leader, helpers and members, and a name made of two word numbers into
`scripts/online/BundWords.gd` (never reorder those lists, only append). Leaving is always possible;
when the leader leaves or deletes the account, the oldest helper (else the oldest member) leads.
A leader dissolves a bund of 3 or more only by confirming again after 24 hours. Blocked players
cannot invite or ask each other. Tables: `bunds`, `bund_members`, `bund_invites`; menu
`scripts/ui/BundMenu.gd` (Friends, Bund).

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

## Trading

Trading (plan area 7) waits behind the flag `trade`. Friends from friendship level
`trade_min_level` (3) whose friendship was accepted at least `trade_min_days` (7) ago can open a
trade (`trade_open`, one open trade per pair, at most `trade_max_open` per player, never with
blocked players). Only items in `trade_items` can be traded; `tools/online/game_data_sql.py` fills
it from `"tradeable": true` in `data/items.json` at every deploy. Shop items and Spirlings are never
tradeable (a test checks that no item from `data/shop.json` is on the list). The server is the
trustee: `trade_put` moves the offer out of the bag of the stored save at once, `trade_confirm` must
name the other side's current offer, and once both confirmed each side takes the other's items
with `trade_collect`. Any change of an offer resets both confirmations; `trade_cancel` (or 7 days
without finishing) gives everyone their own items back. Every change of a save happens in a call
of its own device, which sends the revision it knows (`sync_first` otherwise), so the game changes
its bag the same way and saves on top of the new revision. Tables: `trades` (no account ids),
`trade_sides`; menu `scripts/ui/TradeMenu.gd` (Friends, Trades).

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
