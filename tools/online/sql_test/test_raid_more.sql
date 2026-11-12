-- Online 100, area 3: raid tiers, weekly guardian, top bonus, fastest Rifts, legendary guardians.
insert into auth.users (id) values
  ('53000000-0000-0000-0000-00000000000a'), ('53000000-0000-0000-0000-00000000000b')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '53000000-0000-0000-0000-00000000000' || u, false)
$$;
create temp table rm (k text primary key, v text);
grant all on rm to authenticated;
begin;
update public.feature_flags set enabled = true where key = 'raid';
update public.server_config set value = '["Cairnhold", "Leviarch"]' where key = 'raid_guardians';
update public.server_config set value = jsonb_set(value, '{legendary_chance}', '0') where key = 'raid_rules';
set role authenticated;
select pg_temp.as_user('a');
insert into rm values ('a', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('b');
insert into rm values ('b', public.hello(1)->'profile'->>'code');
select public.friend_request((select v from rm where k = 'a'));
select pg_temp.as_user('a');
select public.friend_respond((select v from rm where k = 'b'), true);
do $$
declare r jsonb;
begin
  assert public.raid_open(jsonb_build_array((select v from rm where k = 'b')), 5)->>'error' = 'bad_tier';
  r := public.raid_open(jsonb_build_array((select v from rm where k = 'b')), 0);
  assert (r->>'hp')::int = 840 and not (r->>'legendary')::boolean, r::text;
  assert r->>'guardian' = (array['Cairnhold', 'Leviarch'])[floor(extract(epoch from now()) / 604800)::int % 2 + 1], r::text;
  insert into rm values ('raid', r->>'raid');
  assert (public.raid_open(jsonb_build_array((select v from rm where k = 'b')), 2)->>'hp')::int = 1800;
end $$;
reset role;
update public.server_config set value = jsonb_set(value, '{legendary_chance}', '100') where key = 'raid_rules';
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb := public.raid_open(jsonb_build_array((select v from rm where k = 'b')), 1);
begin
  assert (r->>'legendary')::boolean and (r->>'hp')::int = 1800, r::text;
  insert into rm values ('leg', r->>'guardian');
end $$;
reset role;
do $$ begin
  assert (public._config('raid_rules', '{}')->'legendaries') ? (select v from rm where k = 'leg');
  assert (select level from public.raids where id = (select v::bigint from rm where k = 'raid')) = 50;
end $$;
update public.raid_members set damage = 900 where raid_id = (select v::bigint from rm where k = 'raid') and user_id = '53000000-0000-0000-0000-00000000000a';
update public.raid_members set damage = 300 where raid_id = (select v::bigint from rm where k = 'raid') and user_id = '53000000-0000-0000-0000-00000000000b';
update public.raids set hp_left = 0, created_at = now() - interval '10 minutes', won_at = now(), reward = '{"item": "tonic", "count": 2}'
where id = (select v::bigint from rm where k = 'raid');
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb := public.raid_claim((select v::bigint from rm where k = 'raid'));
begin
  assert (r->>'count')::int = 3 and (r->>'top')::boolean, r::text;
  r := public.raid_board();
  assert (r->'rows'->0->>'seconds')::int = 600 and not (r->'rows'->0 ? 'name'), r::text;
end $$;
select pg_temp.as_user('b');
do $$ begin
  assert (public.raid_claim((select v::bigint from rm where k = 'raid'))->>'count')::int = 2;
end $$;
reset role;
rollback;
