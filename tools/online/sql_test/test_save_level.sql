-- Spirlings have no top ring: saves hold any ring up to the save_level_max sanity bound (9999);
-- the open league and echo teams stay at level_max 60. test_rules.sql replays the older
-- online_rules migration, so load the save limit migrations again.
\ir ../../../supabase/migrations/20261112200010_save_level_max.sql
\ir ../../../supabase/migrations/20261112220010_save_level_sanity.sql
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000d4') on conflict do nothing;
create temp table sl (k text primary key, v jsonb);
grant all on sl to authenticated;
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000d4', false);
insert into sl values ('put', public.save_put(1, '{"schema": 1, "party": [{"species": "Kindlop", "level": 150, "xp": 545781}, {"species": "Kindlop", "level": 90}], "storage": [{"species": "Kindlop", "level": 500, "xp": 12488298}]}', '', 0));
insert into sl values ('get', public.save_get(1));
insert into sl values ('team', public.team_set('[{"species": "Kindlop", "level": 500, "moves": []}]'));
insert into sl values ('top', public.save_put(3, '{"schema": 1, "party": [{"level": 9999}]}', '', 0));
insert into sl values ('high', public.save_put(2, '{"schema": 1, "party": [{"level": 10000}]}', '', 0));
insert into sl values ('zero', public.save_put(2, '{"schema": 1, "storage": [{"level": 0}]}', '', 0));
reset role;
-- team_set (above) clamps echo teams at level_max; the row is set to 500 directly for the league.
do $$ begin
  assert (select (team->0->>'level')::int from public.profiles where id = '20000000-0000-0000-0000-0000000000d4') = 60,
    'echo team clamped to 60';
end $$;
update public.profiles set team = '[{"species": "Kindlop", "level": 500, "moves": []}]'
where id = '20000000-0000-0000-0000-0000000000d4';
do $$
declare
  get jsonb := (select v from sl where k = 'get');
  saved jsonb := (select team from public.profiles where id = '20000000-0000-0000-0000-0000000000d4');
begin
  assert ((select v from sl where k = 'put')->>'ok')::boolean, (select v from sl where k = 'put')::text;
  assert (get->'data'->'party'->0->>'level')::int = 150, 'the Ring 150 Spirling comes back: ' || get::text;
  assert (get->'data'->'party'->0->>'xp')::bigint = 545781, 'with its xp';
  assert (get->'data'->'party'->1->>'level')::int = 90, 'the Ring 90 Spirling comes back';
  assert (get->'data'->'storage'->0->>'level')::int = 500, 'the Ring 500 Spirling comes back: ' || get::text;
  assert (get->'data'->'storage'->0->>'xp')::bigint = 12488298, 'with its xp';
  assert ((select v from sl where k = 'top')->>'ok')::boolean, 'Ring 9999 is still a save';
  assert (select v from sl where k = 'high')->>'error' = 'implausible', 'Ring 10000 is above the sanity bound';
  assert (select v from sl where k = 'zero')->>'error' = 'implausible', 'Ring 0';
  assert public._config_int('level_max', 60) = 60, 'level_max stays 60';
  assert public._config_int('save_level_max', 0) = 9999;
  assert (public._league_team('20000000-0000-0000-0000-0000000000d4', 'open', '["Kindlop"]')->'team'->0->>'level')::int = 60,
    'open league plays a Ring 500 Spirling at 60: ' || public._league_team('20000000-0000-0000-0000-0000000000d4', 'open', '["Kindlop"]')::text;
  assert saved->0->>'level' = '500', 'set directly for the league check';
end $$;
select set_config('request.jwt.claim.sub', '', false);
