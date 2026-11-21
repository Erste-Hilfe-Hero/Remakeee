-- Plan area 7, item 2947: indexes for every search of the new features, so they stay fast with
-- many players. The league search (season, rating) and the league match lookup (battle_id) already
-- have theirs; tools/online/sql_test/test_indexes.sql checks with explain that each search uses one.

create index if not exists raids_closes on public.raids (closes_at);
create index if not exists raid_attempts_battle on public.raid_attempts (battle_id);
create index if not exists trades_open on public.trades (state, closes_at);
create index if not exists bund_invites_user on public.bund_invites (user_id, kind);
