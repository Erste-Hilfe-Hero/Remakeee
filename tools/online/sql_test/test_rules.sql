-- Plan area 7, items 2669-2674: real game limits, duel Ring from config, Wanderer names,
-- save schema field, feature flags.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-00000000000a'), ('20000000-0000-0000-0000-00000000000b')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;
create temp table rcodes (who text primary key, code text);
grant all on rcodes to authenticated;

-- An old default name from before the rename becomes "Wanderer XXXX" (the migration again).
insert into public.profiles (id, code, name) values ('20000000-0000-0000-0000-00000000000b', 'RULESB23', 'Tamer SB23')
on conflict (id) do update set name = 'Tamer ' || right(public.profiles.code, 4);
\ir ../../../supabase/migrations/20261110000001_online_rules.sql
do $$ begin
  assert (select name from public.profiles where id = '20000000-0000-0000-0000-00000000000b')
    = 'Wanderer ' || right((select code from public.profiles where id = '20000000-0000-0000-0000-00000000000b'), 4),
    'old default name renamed';
end $$;

set role authenticated;

select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
insert into rcodes values ('a', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('20000000-0000-0000-0000-00000000000b');
insert into rcodes values ('b', public.hello(1)->'profile'->>'code');

-- Saves: team of 5, Ring 1-60, schema field required (2669, 2673).
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$
declare five text := '[{"level":60},{"level":1},{},{},{}]';
begin
  assert (public.save_put(1, ('{"schema": 1, "party": ' || five || '}')::jsonb, '', 0)->>'ok')::boolean, 'team of 5 on Ring 60 is fine';
  assert public.save_put(2, '{"schema": 1, "party": [{},{},{},{},{},{}]}', '', 0)->>'error' = 'implausible', 'six in the team';
  assert public.save_put(2, '{"schema": 1, "party": [{"level": 61}]}', '', 0)->>'error' = 'implausible', 'Ring 61';
  assert public.save_put(2, '{"schema": 1, "party": [{"level": 0}]}', '', 0)->>'error' = 'implausible', 'Ring 0';
  assert public.save_put(2, '{"schema": 1, "storage": [{"level": 99}]}', '', 0)->>'error' = 'implausible', 'storage Ring 99';
  assert public.save_put(2, '{"schema": 1, "storage": {"a": 1}}', '', 0)->>'error' = 'implausible', 'storage not a list';
  assert public.save_put(2, '{"party": []}', '', 0)->>'error' = 'schema', 'missing schema';
  assert public.save_put(2, '{"schema": 2, "party": []}', '', 0)->>'error' = 'schema', 'schema too new';
  assert public.save_put(2, '{"schema": 0, "party": []}', '', 0)->>'error' = 'schema', 'schema 0';
  assert public.save_put(2, '{"schema": 1.5, "party": []}', '', 0)->>'error' = 'schema', 'schema not whole';
  assert public.save_put(2, '{"schema": "1", "party": []}', '', 0)->>'error' = 'schema', 'schema as text';
  assert jsonb_array_length(public.save_list()) = 1, 'refused saves stored nothing';
end $$;

-- Wanderer names (2672).
do $$
declare c text := (select code from rcodes where who = 'a');
begin
  assert public.profile_set('B1tch', 0, '', '{}')->>'name' = 'Wanderer ' || right(c, 4);
  assert public.profile_set('', 0, '', '{}')->>'name' = 'Wanderer ' || right(c, 4);
  assert public.profile_set('Mara', 0, '', '{}')->>'name' = 'Mara';
end $$;

-- Friends for the duel Ring check.
select public.friend_request((select code from rcodes where who = 'b'));
select pg_temp.as_user('20000000-0000-0000-0000-00000000000b');
select public.friend_respond((select code from rcodes where who = 'a'), true);
select public.team_set('[{"species":"Puddlet","level":80},{},{},{},{},{"species":"Sixth"}]');
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$
declare t jsonb := public.friend_team((select code from rcodes where who = 'b'));
begin
  assert jsonb_array_length(t->'team') = 5, 'echo team limited to 5';
  assert (t->'team'->0->>'level')::int = 60, 'echo team Ring clamped to 60';
  assert (t->>'duel_ring')::int = 50, 'duel Ring from server_config: ' || t::text;
end $$;

-- Ali changes the duel Ring and the limits on the server, no app update (2671).
reset role;
update public.server_config set value = '40' where key = 'duel_ring';
update public.server_config set value = '2' where key = 'save_schema_max';
set role authenticated;
do $$ begin
  assert (public.friend_team((select code from rcodes where who = 'b'))->>'duel_ring')::int = 40;
  assert (public.save_put(3, '{"schema": 2, "party": []}', '', 0)->>'ok')::boolean, 'schema 2 allowed after config change';
end $$;
reset role;
update public.server_config set value = '50' where key = 'duel_ring';
update public.server_config set value = '1' where key = 'save_schema_max';
set role authenticated;

-- Feature flags (2674): not readable by players, off by default, version gated.
do $$ begin
  begin
    perform * from public.feature_flags;
    raise exception 'feature_flags must not be readable';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public._flag_on('trade', 99);
    raise exception '_flag_on must not be callable';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.feature_flags) >= 6;
  assert not public._flag_on('trade', 99), 'off by default';
  assert not public._flag_on('nothing', 99), 'unknown flag is off';
  update public.feature_flags set enabled = true, min_version = 5 where key = 'trade';
  assert public._flag_on('trade', 5) and not public._flag_on('trade', 4), 'version gate';
  update public.feature_flags set enabled = false, min_version = 1 where key = 'trade';
end $$;
