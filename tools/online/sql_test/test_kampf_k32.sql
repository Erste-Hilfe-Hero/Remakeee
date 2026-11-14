-- KAMPF_PLAN_1000 419 (raid guardian phases) and 435 (boss boards by rounds).
-- The same cases as tests/unit/test_kampf_k32.gd.
insert into auth.users (id) values
  ('32000000-0000-0000-0000-00000000000a'), ('32000000-0000-0000-0000-00000000000b'),
  ('32000000-0000-0000-0000-00000000000c')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '32000000-0000-0000-0000-00000000000' || u, false)
$$;
create or replace function pg_temp.uid(u text) returns uuid language sql as $$
  select ('32000000-0000-0000-0000-00000000000' || u)::uuid
$$;
begin;
-- 419: the phase is fixed on the attempt from the strength left when it starts.
do $$
declare
  rid bigint;
  a public.raid_attempts;
begin
  assert jsonb_array_length((select value->'phases' from public.server_config where key = 'raid_rules')) = 2, 'two phases in raid_rules';
  assert public._raid_phase(1200, 1200) = 0 and public._raid_phase(601, 1200) = 0, 'fresh guardian';
  assert public._raid_phase(600, 1200) = 1 and public._raid_phase(301, 1200) = 1, 'half gone';
  assert public._raid_phase(300, 1200) = 2 and public._raid_phase(0, 1200) = 2, 'a quarter left';
  assert public._raid_phase(0, 0) = 0, 'no strength, no phase';
  insert into public.raids (guardian, level, players, hp_total, hp_left, closes_at)
    values ('Leviarch', 60, 2, 1200, 1200, now() + interval '1 day') returning id into rid;
  insert into public.raid_attempts (raid_id, user_id, seed, teams)
    values (rid, pg_temp.uid('a'), 7, '[[], []]') returning * into a;
  assert a.phase = 0 and (public._raid_expect(a)->>'raid_phase')::int = 0, 'phase 0 at full strength';
  update public.raids set hp_left = 500 where id = rid;
  insert into public.raid_attempts (raid_id, user_id, seed, teams)
    values (rid, pg_temp.uid('a'), 8, '[[], []]') returning * into a;
  assert a.phase = 1 and (public._raid_expect(a)->>'raid_phase')::int = 1, 'phase 1 below half';
  update public.raids set hp_left = 1 where id = rid;
  select * into a from public.raid_attempts where raid_id = rid and seed = 8;
  assert a.phase = 1, 'an attempt keeps its phase when the Rift moves on';
  assert (public._raid_expect(a)->>'round_limit')::int = 10, 'expect keeps the round limit';
end $$;

-- 435: boss boards.
do $$ begin
  assert (select count(*) from public.feature_flags where key = 'boss_board' and not enabled) = 1, 'boss board starts off';
end $$;
set role authenticated;
do $$
declare w text;
begin
  foreach w in array array['a', 'b', 'c'] loop
    perform pg_temp.as_user(w);
    perform public.hello(1);
  end loop;
  assert public.boss_submit('prism_boss', 5)->>'error' = 'feature_off', 'off until switched on';
end $$;
reset role;
update public.feature_flags set enabled = true where key = 'boss_board';
insert into public.friendships (a, b, status, requested_by)
  values (pg_temp.uid('a'), pg_temp.uid('b'), 'accepted', pg_temp.uid('a')) on conflict do nothing;
set role authenticated;
do $$
declare r jsonb;
begin
  perform pg_temp.as_user('a');
  assert (public.boss_submit('prism_boss', 12)->>'ok')::boolean;
  assert (public.boss_submit('prism_boss', 15)->>'ok')::boolean, 'a slower clear is fine but does not count';
  assert public.boss_submit('prism_boss', 31)->>'error' = 'implausible', 'one heart, at most 30 rounds';
  assert public.boss_submit('prism_boss', 0)->>'error' = 'implausible';
  assert public.boss_submit('roof', 3)->>'error' = 'bad_kind';
  assert (public.boss_submit('boss_tower', 40)->>'ok')::boolean;
  assert public.boss_submit('boss_tower', 91)->>'error' = 'implausible';
  perform pg_temp.as_user('b');
  perform public.boss_submit('prism_boss', 9);
  perform pg_temp.as_user('c');
  perform public.boss_submit('prism_boss', 4);
  perform pg_temp.as_user('a');
  r := public.boss_board('prism_boss', true);
  assert (r->>'ok')::boolean and jsonb_array_length(r->'rows') = 2, r::text;
  assert r->'rows'->0->>'name' <> '' and (r->'rows'->0->>'score')::int = 9, 'fewest rounds first, friend with name';
  assert (r->'rows'->1->>'score')::int = 12 and (r->'rows'->1->>'me')::boolean, 'best clear counts';
  r := public.boss_board('prism_boss', false);
  assert jsonb_array_length(r->'rows') = 3 and (r->'rows'->0->>'score')::int = 4, r::text;
  assert r->'rows'->0->>'name' = '', 'strangers stay nameless';
  r := public.boss_board('boss_tower', false);
  assert jsonb_array_length(r->'rows') = 1 and (r->'rows'->0->>'score')::int = 40, r::text;
  assert public.boss_board('roof', true)->>'error' = 'bad_kind';
end $$;
reset role;
rollback;
