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

- **Friends:** 8-character friend code, requests, a list with online dot and in-game place, Tamer card,
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

Security model: every table has row level security on and no policies, and players have no table rights. The
game only calls the `security definer` functions, which check `auth.uid()` and every rule themselves.
New server features add a migration file, a SQL test and the same rule in `LocalBackend`.

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

Also `gift_table`, `gift_open_limit`, `friend_limit`, `goal_rotation` (list of `{"kind", "target"}`;
kinds `battles`, `bonds`, `rests`), `goal_rewards` (four item ids) and `goal_user_cap`.

Table `banned_words`: words a Tamer name may not contain.

## Reports (Ali, about once a week)

Table `reports` lists open reports (`handled = false`). To reset a name, run in the database:

```sql
update public.profiles set name = 'Tamer ' || right(code, 4) where id = '<target>';
update public.reports set handled = true where target = '<target>';
```

The DSA asks for a short reason to the player. Until there is an in-game notice, answer by email if they
write in, for example: "Your Tamer name was reset because it broke the rules in section 4 of the terms."
