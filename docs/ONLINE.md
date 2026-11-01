# Online (Chimora is online only)

Chimora only runs with an internet connection. The server keeps every journey, the phone keeps a cache copy.
The server is [Supabase](https://supabase.com) in Frankfurt (region `eu-central-1`). The ideas list behind
this is the "Chimora online: 200 ideas" artifact in the project.

## How it works

- **Account:** the first start makes an account without email (Supabase anonymous sign-in). The game never
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

## Code

| Part | Where |
| --- | --- |
| Database tables and functions | `supabase/migrations/*.sql` |
| Tests for the SQL (throwaway Postgres) | `tools/online/test_sql.sh`, `tools/online/sql_test/` |
| Autoload: sign-in, saves, heartbeat, reconnect | `scripts/online/Online.gd` |
| Real server client (HTTPS) | `scripts/online/SupabaseBackend.gd` |
| Local stand-in with the same rules (tests, builds without a server) | `scripts/online/LocalBackend.gd` |
| Account menu | `scripts/ui/AccountMenu.gd` |

Security model: every table has row level security on and no policies, and players have no table rights. The
game only calls the `security definer` functions, which check `auth.uid()` and every rule themselves.
New server features add a migration file, a SQL test and the same rule in `LocalBackend`.

Builds without a server address use `LocalBackend`, a test server that lives on the phone. The account menu
then says "test server on this phone". The debug APK from CI works like this until the secrets below exist.

## Setting up the server (Ali, once)

1. Create a Supabase account and a project. Region: **Frankfurt (eu-central-1)**. Plan: Free is enough for
   testing, Pro (about 25 USD a month) for launch because Free projects pause after a week without use.
2. Sign the data processing agreement: Organization settings, Legal documents, DPA. Put Supabase's address
   into `docs/legal/DATENSCHUTZ.md` and `PRIVACY_POLICY_EN.md` (the placeholders say where).
3. Authentication, Sign In / Providers: switch on **Allow anonymous sign-ins**. Switch off email sign-up
   (Chimora does not use it).
4. SQL Editor: run every file in `supabase/migrations/` in name order. (Or with the Supabase CLI:
   `supabase link` then `supabase db push`.)
5. Project settings, API: copy the **Project URL** and the **anon public** key.
6. GitHub, repository settings, Secrets and variables, Actions: add `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
   The anon key is meant to be public; the database functions protect everything.

From then on every CI build talks to the real server. Store builds (release AAB, iOS) fail without the two
secrets, because an online-only game cannot ship without its server.

## Changing things without an app update

In the Supabase table editor, table `server_config`:

| key | value | effect |
| --- | --- | --- |
| `min_version` | `1004` | builds with a lower version code must update |
| `motd` | `"Maintenance today 3-4 am"` | notice on the title screen (`""` = none) |

Table `banned_words`: words a Tamer name may not contain.
