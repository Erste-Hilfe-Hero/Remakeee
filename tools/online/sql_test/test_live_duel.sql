-- Online 100, area 1: live duels. The same cases as tests/unit/test_live_duel.gd.
insert into auth.users (id) values
  ('52000000-0000-0000-0000-00000000000a'), ('52000000-0000-0000-0000-00000000000b'),
  ('52000000-0000-0000-0000-00000000000c')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '52000000-0000-0000-0000-00000000000' || u, false)
$$;
create temp table lv (k text primary key, v text);
grant all on lv to authenticated;
begin;
update public.feature_flags set enabled = true where key = 'live_duel';
set role authenticated;
select pg_temp.as_user('a');
insert into lv values ('a', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species":"Kindlop","level":12},{"species":"Puddlet","level":9},{"species":"Zippit","level":9},{"species":"Wickit","level":5}]');
select pg_temp.as_user('b');
insert into lv values ('b', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species":"Zippit","level":20},{"species":"Kindlop","level":15},{"species":"Puddlet","level":9}]');
select public.friend_request((select v from lv where k = 'a'));
select pg_temp.as_user('c');
insert into lv values ('c', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('a');
select public.friend_respond((select v from lv where k = 'b'), true);

do $$
declare r jsonb; id bigint;
begin
  assert public.live_invite((select v from lv where k = 'c'))->>'error' = 'not_friends';
  r := public.live_invite((select v from lv where k = 'b'));
  assert (r->>'ok')::boolean, r::text;
  insert into lv values ('d', r->>'id');
  id := (r->>'id')::bigint;
  assert public.live_answer(id, true)->>'error' = 'no_such_duel', 'only the friend answers';
  assert public.live_state(id)->>'state' = 'invited';
end $$;
select pg_temp.as_user('c');
do $$ begin
  assert public.live_state((select v::bigint from lv where k = 'd'))->>'error' = 'no_such_duel';
end $$;
select pg_temp.as_user('b');
do $$
declare r jsonb; id bigint := (select v::bigint from lv where k = 'd');
begin
  r := public.live_answer(id, true);
  assert r->>'state' = 'picking' and jsonb_array_length(r->'show'->0) = 4, r::text;
  assert public.live_pick(id, '[0, 0, 1]')->>'error' = 'bad_pick';
  assert public.live_pick(id, '[0, 1]')->>'error' = 'bad_pick';
  assert public.live_pick(id, '[0, 1, 3]')->>'error' = 'bad_pick', 'only 3 shown';
  r := public.live_pick(id, '[2, 0, 1]');
  assert r->>'state' = 'picking' and (r->'picked'->1)::boolean, r::text;
  assert public.live_pick(id, '[0, 1, 2]')->>'error' = 'duel_closed';
end $$;
select pg_temp.as_user('a');
do $$
declare r jsonb; id bigint := (select v::bigint from lv where k = 'd');
begin
  r := public.live_pick(id, '[3, 1, 0]');
  assert r->>'state' = 'running' and (r->>'round')::int = 1, r::text;
  assert r->'teams'->0->0->>'species' = 'Wickit' and r->'teams'->1->0->>'species' = 'Puddlet', r::text;
  assert public.live_move(id, 2, '{"kind": "move", "slot": 0}')->>'error' = 'wrong_round';
  r := public.live_move(id, 1, '{"kind": "move", "slot": 0}');
  assert (r->>'round')::int = 1;
  assert public.live_move(id, 1, '{"kind": "move", "slot": 1}')->>'error' = 'already_moved';
  assert (public.live_emote(id, 2)->>'ok')::boolean and public.live_emote(id, 99)->>'error' = 'bad_emote';
end $$;
select pg_temp.as_user('b');
do $$
declare r jsonb; id bigint := (select v::bigint from lv where k = 'd');
begin
  r := public.live_move(id, 1, '{"kind": "move", "slot": 2}');
  assert (r->>'round')::int = 2 and r->'moves'->'1'->1->>'slot' = '2', r::text;
  assert (r->'emotes'->0->>'emote')::int = 2;
  -- The winner comes from the referee (20261113000040_live_referee.sql), not from a phone.
  r := public.live_finish(id, 1);
  assert r->>'state' = 'running' and (r->>'judging')::boolean, r::text;
end $$;
select pg_temp.as_user('a');
do $$
declare r jsonb; id bigint := (select v::bigint from lv where k = 'd');
begin
  r := public.live_finish(id, 0);
  assert r->>'state' = 'running' and (r->>'judging')::boolean, r::text;
end $$;
reset role;
insert into public.battle_results (battle_id, verdict, detail)
select judge_id, 'ok', '{"finished": true, "winner": 1, "rounds": 1}' from public.live_duels where id = (select v::bigint from lv where k = 'd');
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb; id bigint := (select v::bigint from lv where k = 'd');
begin
  r := public.live_state(id);
  assert r->>'state' = 'done' and r->>'reason' = 'played' and (r->>'winner')::int = 1, r::text;
  r := public.live_rematch(id);
  assert (r->>'ok')::boolean, r::text;
  insert into lv values ('e', r->>'id');
end $$;
-- Timeout: an invite runs out; a side away past turn plus reconnect loses; forfeit.
select pg_temp.as_user('b');
select public.live_answer((select v::bigint from lv where k = 'e'), true);
reset role;
update public.live_duels set deadline = now() - interval '61 seconds' where id = (select v::bigint from lv where k = 'e');
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb := public.live_state((select v::bigint from lv where k = 'e'));
begin
  assert r->>'state' = 'done' and r->>'reason' = 'timeout' and (r->>'winner')::int = -1, r::text;
  r := public.live_invite((select v from lv where k = 'b'));
  assert public.live_forfeit((r->>'id')::bigint)->>'error' = 'duel_closed', 'not before it starts';
end $$;
reset role;
rollback;
