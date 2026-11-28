-- Plan area 7, item 2947: each search of the new features can use an index. The tables are tiny
-- here, so sequential scans are switched off to see which plan Postgres would choose.
create or replace function pg_temp.uses_index(q text) returns boolean language plpgsql as $$
declare
  line text;
  found boolean := false;
begin
  for line in execute 'explain ' || q loop
    if line ~ 'Index' then found := true; end if;
  end loop;
  return found;
end $$;
set enable_seqscan = off;
do $$
begin
  assert pg_temp.uses_index('select * from public.league_fair_entries where season = 1 order by rating limit 5'),
    'league search by season and rating';
  assert pg_temp.uses_index('select * from public.league_open_entries where season = 1 and rating between 1400 and 1600'),
    'open league search';
  assert pg_temp.uses_index('select * from public.league_matches where battle_id = 1'), 'league match by battle';
  assert pg_temp.uses_index('select * from public.raids where closes_at < now()'), 'raids by end';
  assert pg_temp.uses_index('select * from public.raid_members where user_id = ''20000000-0000-0000-0000-0000000000c1'''),
    'raids of a player';
  assert pg_temp.uses_index('select * from public.raid_attempts where battle_id = 1'), 'raid attempt by battle';
  assert pg_temp.uses_index('select * from public.bund_members where bund_id = 1'), 'members of a bund';
  assert pg_temp.uses_index('select * from public.bund_invites where user_id = ''20000000-0000-0000-0000-0000000000c1'''),
    'invites of a player';
  assert pg_temp.uses_index('select * from public.trade_sides where user_id = ''20000000-0000-0000-0000-0000000000d1'' and not collected'),
    'trades by player and status';
  assert pg_temp.uses_index('select * from public.trades where state = ''open'' and closes_at < now()'), 'open trades by end';
end $$;
reset enable_seqscan;
