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

Also `gift_table`, `gift_open_limit`, `friend_limit`, `goal_rotation` (list of `{"kind", "target"}`;
kinds `battles`, `bonds`, `rests`), `goal_rewards` (four item ids) and `goal_user_cap`.

Table `banned_words`: words a Tamer name may not contain.

## Reports (Ali, about once a week)

Table `reports` lists open reports (`handled = false`). To reset a name, run in the SQL editor:

```sql
update public.profiles set name = 'Tamer ' || right(code, 4) where id = '<target>';
update public.reports set handled = true where target = '<target>';
```

The DSA asks for a short reason to the player. Until there is an in-game notice, answer by email if they
write in, for example: "Your Tamer name was reset because it broke the rules in section 4 of the terms."
