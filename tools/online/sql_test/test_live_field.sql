-- KAMPF_PLAN_1000 340: the field of a live duel. The same cases as tests/unit/test_kampf_k30.gd.
insert into auth.users (id) values
  ('c3400000-0000-0000-0000-00000000000a'), ('c3400000-0000-0000-0000-00000000000b')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', 'c3400000-0000-0000-0000-00000000000' || u, false)
$$;
create temp table lf (k text primary key, v text);
grant all on lf to authenticated;
begin;
update public.feature_flags set enabled = true where key = 'live_duel';
set role authenticated;
select pg_temp.as_user('a');
insert into lf values ('a', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species":"Kindlop","level":12},{"species":"Puddlet","level":9},{"species":"Zippit","level":9}]');
select pg_temp.as_user('b');
insert into lf values ('b', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species":"Zippit","level":20},{"species":"Kindlop","level":15},{"species":"Puddlet","level":9}]');
select public.friend_request((select v from lf where k = 'a'));
select pg_temp.as_user('a');
select public.friend_respond((select v from lf where k = 'b'), true);

do $$
declare r jsonb; id bigint;
begin
  assert public.live_invite((select v from lf where k = 'b'), 'lava_lake')->>'error' = 'bad_field', 'only listed fields';
  r := public.live_invite((select v from lf where k = 'b'));
  assert public.live_state((r->>'id')::bigint)->>'field' = '', 'no field by default';
  r := public.live_invite((select v from lf where k = 'b'), 'high_tide');
  assert (r->>'ok')::boolean, r::text;
  id := (r->>'id')::bigint;
  insert into lf values ('d', id::text);
  assert public.live_state(id)->>'field' = 'high_tide', public.live_state(id)::text;
end $$;
select pg_temp.as_user('b');
do $$
declare id bigint := (select v::bigint from lf where k = 'd');
begin
  assert public.live_state(id)->>'field' = 'high_tide', 'the friend sees the field';
  perform public.live_answer(id, true);
  perform public.live_pick(id, '[0, 1, 2]');
end $$;
select pg_temp.as_user('a');
do $$
declare id bigint := (select v::bigint from lf where k = 'd');
begin
  perform public.live_pick(id, '[0, 1, 2]');
  perform public.live_move(id, 1, '{"k": 2}');
end $$;
select pg_temp.as_user('b');
do $$
declare id bigint := (select v::bigint from lf where k = 'd');
begin
  perform public.live_move(id, 1, '{"k": 2}');
  perform public.live_finish(id, 1);
end $$;
reset role;
do $$
declare d public.live_duels; q public.battle_queue;
begin
  select * into d from public.live_duels where id = (select v::bigint from lf where k = 'd');
  select * into q from public.battle_queue where battle_id = d.judge_id;
  assert q.claim->'expect'->>'field' = 'high_tide', 'the referee plays on the field: ' || q.claim::text;
  update public.live_duels set state = 'done', judge_id = null where id = d.id;
end $$;
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb := public.live_rematch((select v::bigint from lf where k = 'd'));
begin
  assert (r->>'ok')::boolean, r::text;
  assert public.live_state((r->>'id')::bigint)->>'field' = 'high_tide', 'a rematch keeps the field';
end $$;
reset role;
rollback;
