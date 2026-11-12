-- Saves hold Spirlings up to save_level_max (96, Halcyra); the open league and echo teams stay
-- at level_max 60. test_rules.sql replays the older online_rules migration, so load this again.
\ir ../../../supabase/migrations/20261112200010_save_level_max.sql
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000d4') on conflict do nothing;
create temp table sl (k text primary key, v jsonb);
grant all on sl to authenticated;
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000d4', false);
insert into sl values ('put', public.save_put(1, '{"schema": 1, "party": [{"species": "Kindlop", "level": 90}], "storage": [{"level": 96}]}', '', 0));
insert into sl values ('get', public.save_get(1));
insert into sl values ('team', public.team_set('[{"species": "Kindlop", "level": 90, "moves": []}]'));
insert into sl values ('high', public.save_put(2, '{"schema": 1, "party": [{"level": 97}]}', '', 0));
reset role;
-- team_set (above) clamps echo teams at level_max; the row is set to 90 directly for the league.
do $$ begin
  assert (select (team->0->>'level')::int from public.profiles where id = '20000000-0000-0000-0000-0000000000d4') = 60,
    'echo team clamped to 60';
end $$;
update public.profiles set team = '[{"species": "Kindlop", "level": 90, "moves": []}]'
where id = '20000000-0000-0000-0000-0000000000d4';
do $$
declare
  get jsonb := (select v from sl where k = 'get');
  saved jsonb := (select team from public.profiles where id = '20000000-0000-0000-0000-0000000000d4');
begin
  assert ((select v from sl where k = 'put')->>'ok')::boolean, (select v from sl where k = 'put')::text;
  assert get::text like '%"level": 90%', 'the Ring 90 Spirling comes back: ' || get::text;
  assert (select v from sl where k = 'high')->>'error' = 'implausible', 'Ring 97 is above save_level_max';
  assert public._config_int('level_max', 60) = 60, 'level_max stays 60';
  assert public._config_int('save_level_max', 0) = 96;
  assert (public._league_team('20000000-0000-0000-0000-0000000000d4', 'open', '["Kindlop"]')->'team'->0->>'level')::int = 60,
    'open league caps a Ring 90 Spirling at 60: ' || public._league_team('20000000-0000-0000-0000-0000000000d4', 'open', '["Kindlop"]')::text;
  assert saved->0->>'level' = '90', 'set directly for the league check';
end $$;
select set_config('request.jwt.claim.sub', '', false);
