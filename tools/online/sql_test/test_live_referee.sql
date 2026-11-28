-- Online 100: the referee decides live duels (3); a borrowed Spirling in a live duel and in a raid
-- attempt (45). The same cases as tests/unit/test_live_referee.gd.
insert into auth.users (id) values
  ('57000000-0000-0000-0000-00000000000a'), ('57000000-0000-0000-0000-00000000000b')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '57000000-0000-0000-0000-00000000000' || u, false)
$$;
create temp table lr (k text primary key, v text);
grant all on lr to authenticated;
-- The referee's answer for the check that is open on duel [k].
create or replace function pg_temp.referee(k_ text, verdict_ text, detail_ jsonb) returns void language sql as $$
  insert into public.battle_results (battle_id, verdict, detail)
  select judge_id, verdict_, detail_ from public.live_duels where id = (select v::bigint from lr where k = k_)
$$;
update public.feature_flags set enabled = true where key in ('live_duel', 'lend', 'raid');
set role authenticated;
select pg_temp.as_user('a');
insert into lr values ('a', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species":"Kindlop","level":40},{"species":"Puddlet","level":40},{"species":"Mossling","level":40}]');
select pg_temp.as_user('b');
insert into lr values ('b', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species":"Kindlop","level":40},{"species":"Puddlet","level":40},{"species":"Mossling","level":40}]');
select public.friend_request((select v from lr where k = 'a'));
select pg_temp.as_user('a');
select public.friend_respond((select v from lr where k = 'b'), true);
reset role;
update public.friendships set points = 30, accepted_at = now() - interval '8 days'
where a in ('57000000-0000-0000-0000-00000000000a', '57000000-0000-0000-0000-00000000000b');
insert into public.saves (user_id, slot, rev, data) values
  ('57000000-0000-0000-0000-00000000000a', 1, 1, '{"inventory": {}, "party": [{"uid": "m1", "species": "Wickit", "level": 12, "moves": []},
    {"uid": "m2", "species": "Kindlop", "level": 9}], "storage": []}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;
set role authenticated;

-- 45: the borrowed Spirling joins the shown Spirlings while both pick; one per duel; the loan is used up.
select pg_temp.as_user('a');
do $$
declare r jsonb;
begin
  r := public.lend_offer((select v from lr where k = 'b'), 1, 'm1');
  assert (r->>'ok')::boolean, r::text;
  insert into lr values ('loan', r->>'loan');
  r := public.live_invite((select v from lr where k = 'b'));
  assert (r->>'ok')::boolean, r::text;
  insert into lr values ('d', r->>'id');
end $$;
select pg_temp.as_user('b');
do $$
declare r jsonb; id bigint := (select v::bigint from lr where k = 'd'); loan bigint := (select v::bigint from lr where k = 'loan');
begin
  assert public.live_borrow(id, loan)->>'error' = 'duel_closed', 'only while picking';
  perform public.live_answer(id, true);
  assert public.live_borrow(id, 999999)->>'error' = 'no_such_loan';
  r := public.live_borrow(id, loan);
  assert jsonb_array_length(r->'show'->1) = 4 and r->'show'->1->3->>'species' = 'Wickit' and (r->'show'->1->3->>'loan')::boolean, r::text;
  assert (r->'show'->1->3->>'level')::int = 12 and jsonb_typeof(r->'show'->1->3->'moves') = 'array', r::text;
  assert public.live_borrow(id, loan)->>'error' = 'used';
  assert public.lend_list()->'borrowed'->0->>'used_for' = 'live_duel';
  r := public.live_pick(id, '[3, 0, 1]');
  assert (r->'picked'->>1)::boolean, r::text;
end $$;
select pg_temp.as_user('a');
do $$
declare r jsonb; id bigint := (select v::bigint from lr where k = 'd'); loan bigint := (select v::bigint from lr where k = 'loan');
begin
  assert public.live_borrow(id, loan)->>'error' = 'no_such_loan', 'only the borrower';
  assert jsonb_array_length(public.live_state(id)->'show'->1) = 4, 'the rival sees it too';
  r := public.live_pick(id, '[0, 1, 2]');
  assert r->>'state' = 'running' and r->'teams'->1->0->>'species' = 'Wickit' and not (r->>'judging')::boolean, r::text;
  -- 3: nothing to check before a round is over.
  assert public.live_finish(id, 0)->>'error' = 'not_over';
  perform public.live_move(id, 1, '{"k": 2}');
end $$;
select pg_temp.as_user('b');
do $$
declare r jsonb; id bigint := (select v::bigint from lr where k = 'd');
begin
  perform public.live_move(id, 1, '{"k": 2}');
  r := public.live_finish(id, 1);
  assert r->>'state' = 'running' and (r->>'judging')::boolean, r::text;
end $$;
select pg_temp.as_user('a');
do $$
declare r jsonb := public.live_finish((select v::bigint from lr where k = 'd'), 0);
begin
  assert r->>'state' = 'running' and (r->>'judging')::boolean, 'one check at a time';
end $$;
reset role;
do $$
declare d public.live_duels; q public.battle_queue;
begin
  select * into d from public.live_duels where id = (select v::bigint from lr where k = 'd');
  assert d.judged_round = 1 and d.judge_id is not null;
  assert (select count(*) from public.battles where kind = 'live_judge' and ref = d.id::text) = 1, 'the second report opens no second check';
  select * into q from public.battle_queue where battle_id = d.judge_id;
  assert (q.claim->'expect'->>'live')::boolean and (q.claim->'expect'->>'seed')::bigint = d.seed, q.claim::text;
  assert jsonb_array_length(q.claim->'expect'->'teams') = 2 and q.claim->'expect'->'teams'->1->0->>'species' = 'Wickit', q.claim::text;
  assert (select array_agg(key) from jsonb_object_keys(q.claim->'expect'->'moves') key) = array['1'], q.claim::text;
  -- The clock rests while the referee looks.
  update public.live_duels set deadline = now() - interval '5 minutes' where id = d.id;
end $$;
set role authenticated;
select pg_temp.as_user('a');
do $$ begin
  assert public.live_state((select v::bigint from lr where k = 'd'))->>'state' = 'running', 'no timeout during the check';
end $$;
reset role;
-- The referee: one round of rests ends nothing. The duel goes on.
select pg_temp.referee('d', 'ok', '{"finished": false, "winner": -1, "rounds": 1}');
do $$
declare d public.live_duels;
begin
  select * into d from public.live_duels where id = (select v::bigint from lr where k = 'd');
  assert d.state = 'running' and d.judge_id is null and d.deadline > now(), 'the duel goes on with a fresh clock';
  assert (select status from public.battles where kind = 'live_judge' and ref = d.id::text) = 'ok';
end $$;
set role authenticated;
select pg_temp.as_user('b');
do $$
declare id bigint := (select v::bigint from lr where k = 'd');
begin
  assert public.live_finish(id, 1)->>'error' = 'not_over', 'one check per finished round';
  perform public.live_move(id, 2, '{"k": 2}');
end $$;
select pg_temp.as_user('a');
do $$
declare r jsonb; id bigint := (select v::bigint from lr where k = 'd');
begin
  perform public.live_move(id, 2, '{"k": 2}');
  r := public.live_finish(id, 0);
  assert (r->>'judging')::boolean, r::text;
end $$;
reset role;
-- The referee says side 0 won; that counts, although side 1 claimed the win before.
select pg_temp.referee('d', 'ok', '{"finished": true, "winner": 0, "rounds": 2}');
set role authenticated;
select pg_temp.as_user('b');
do $$
declare r jsonb; id bigint := (select v::bigint from lr where k = 'd');
begin
  r := public.live_state(id);
  assert r->>'state' = 'done' and r->>'reason' = 'played' and (r->>'winner')::int = 0 and not (r->>'judging')::boolean, r::text;
  assert public.live_finish(id, 1)->>'error' = 'duel_closed';
  assert public.battle_submit('live_judge', id::text, '{"teams": []}', '{}')->>'error' = 'bad_kind', 'no phone can open a check';
  -- A duel the referee cannot play again ends without a winner.
  r := public.live_rematch(id);
  insert into lr values ('e', r->>'id');
end $$;
select pg_temp.as_user('a');
do $$
declare id bigint := (select v::bigint from lr where k = 'e');
begin
  perform public.live_answer(id, true);
  perform public.live_pick(id, '[0, 1, 2]');
end $$;
select pg_temp.as_user('b');
do $$
declare id bigint := (select v::bigint from lr where k = 'e');
begin
  perform public.live_pick(id, '[0, 1, 2]');
  perform public.live_move(id, 1, '{"k": 2}');
end $$;
select pg_temp.as_user('a');
do $$
declare id bigint := (select v::bigint from lr where k = 'e');
begin
  perform public.live_move(id, 1, '{"k": 2}');
  perform public.live_finish(id, 1);
end $$;
reset role;
select pg_temp.referee('e', 'error', '{"reason": "rebuild"}');
do $$
declare d public.live_duels;
begin
  select * into d from public.live_duels where id = (select v::bigint from lr where k = 'e');
  assert d.state = 'done' and d.reason = 'disputed' and d.winner = -1 and d.judge_id is null;
end $$;
-- A referee that stays silent for 10 minutes: no winner.
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb := public.live_rematch((select v::bigint from lr where k = 'e'));
begin
  insert into lr values ('f', r->>'id');
end $$;
select pg_temp.as_user('b');
do $$
declare id bigint := (select v::bigint from lr where k = 'f');
begin
  perform public.live_answer(id, true);
  perform public.live_pick(id, '[0, 1, 2]');
end $$;
select pg_temp.as_user('a');
do $$
declare id bigint := (select v::bigint from lr where k = 'f');
begin
  perform public.live_pick(id, '[0, 1, 2]');
  perform public.live_move(id, 1, '{"k": 2}');
end $$;
select pg_temp.as_user('b');
do $$
declare r jsonb; id bigint := (select v::bigint from lr where k = 'f');
begin
  perform public.live_move(id, 1, '{"k": 2}');
  r := public.live_finish(id, 1);
  assert (r->>'judging')::boolean, r::text;
end $$;
reset role;
update public.live_duels set deadline = now() - interval '11 minutes' where id = (select v::bigint from lr where k = 'f');
set role authenticated;
do $$
declare r jsonb := public.live_state((select v::bigint from lr where k = 'f'));
begin
  assert r->>'state' = 'done' and r->>'reason' = 'disputed' and (r->>'winner')::int = -1, r::text;
end $$;

-- 45: the borrowed Spirling in a raid attempt, as the last of the team with the fair row.
select pg_temp.as_user('a');
do $$
declare r jsonb := public.lend_offer((select v from lr where k = 'b'), 1, 'm1');
begin
  assert (r->>'ok')::boolean, r::text;
  insert into lr values ('loan2', r->>'loan');
end $$;
select pg_temp.as_user('b');
do $$
declare r jsonb; raid bigint; loan bigint := (select v::bigint from lr where k = 'loan2');
begin
  r := public.raid_open(jsonb_build_array((select v from lr where k = 'a')));
  assert (r->>'ok')::boolean, r::text;
  raid := (r->>'raid')::bigint;
  insert into lr values ('raid', raid::text);
  assert public.raid_start_loan(raid, '["Kindlop"]', 999999)->>'error' = 'no_such_loan';
  assert public.raid_start_loan(raid, '["Kindlop"]', null)->>'error' = 'no_such_loan';
  assert public.raid_start_loan(raid, '["Kindlop", "Wickit"]', loan)->>'error' = 'duplicate_species';
  assert public.raid_start_loan(raid, '[]', loan)->>'error' = 'empty_team', 'at least one own Spirling';
  assert public.raid_start_loan(raid, '["Kindlop", "Puddlet", "Mossling", "Zippit", "Wickit"]', loan)->>'error' = 'bad_team';
  assert public.lend_list()->'borrowed'->0->>'state' = 'lent', 'a failed start keeps the loan';
  r := public.raid_start_loan(raid, '["Kindlop", "Puddlet"]', loan);
  assert (r->>'ok')::boolean and jsonb_array_length(r->'teams'->0) = 3 and r->'teams'->0->2->>'species' = 'Wickit'
    and (r->'teams'->0->2->>'level')::int = 50, r::text;
  assert public.lend_list()->'borrowed'->0->>'used_for' = 'raid';
  assert public.raid_start_loan(raid, '["Kindlop"]', loan)->>'error' = 'used';
  r := public.raid_start(raid, '["Kindlop"]');
  assert (r->>'ok')::boolean and jsonb_array_length(r->'teams'->0) = 1, 'without a loan as before';
end $$;
select pg_temp.as_user('a');
do $$ begin
  assert public.raid_start_loan((select v::bigint from lr where k = 'raid'), '["Kindlop"]', (select v::bigint from lr where k = 'loan2'))->>'error'
    = 'no_such_loan', 'only the borrower';
end $$;
reset role;
do $$ begin
  assert has_function_privilege('authenticated', 'public.live_borrow(bigint, bigint)', 'execute');
  assert has_function_privilege('authenticated', 'public.raid_start_loan(bigint, jsonb, bigint)', 'execute');
  assert not has_function_privilege('authenticated', 'public._live_judged(bigint, text, jsonb)', 'execute');
  assert not has_function_privilege('authenticated', 'public._raid_begin(uuid, bigint, jsonb, bigint)', 'execute');
  assert not has_function_privilege('anon', 'public.live_finish(bigint, int)', 'execute');
end $$;
