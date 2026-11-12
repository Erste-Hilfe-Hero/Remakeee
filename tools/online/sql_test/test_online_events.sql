-- Online 100, area 7: online events. The same cases as tests/unit/test_online_events.gd.
insert into auth.users (id) values
  ('53000000-0000-0000-0000-00000000000a'), ('53000000-0000-0000-0000-00000000000b'),
  ('53000000-0000-0000-0000-00000000000c'), ('53000000-0000-0000-0000-00000000000d'),
  ('53000000-0000-0000-0000-00000000000e')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '53000000-0000-0000-0000-00000000000' || u, false)
$$;
create temp table bv (k text primary key, v jsonb);
grant all on bv to authenticated;
begin;
update public.feature_flags set enabled = false where key = 'events';
set role authenticated;
select pg_temp.as_user('a');
insert into bv values ('code_a', to_jsonb(public.hello(1)->'profile'->>'code'));
insert into bv values ('off_events', public.event_list());
select pg_temp.as_user('b');
insert into bv values ('code_b', to_jsonb(public.hello(1)->'profile'->>'code'));
select pg_temp.as_user('c');
insert into bv values ('code_c', to_jsonb(public.hello(1)->'profile'->>'code'));
select pg_temp.as_user('d');
insert into bv values ('code_d', to_jsonb(public.hello(1)->'profile'->>'code'));
select pg_temp.as_user('e');
insert into bv values ('code_e', to_jsonb(public.hello(1)->'profile'->>'code'));
reset role;
do $$ begin
  assert (select v->>'error' from bv where k = 'off_events') = 'feature_off';
end $$;
update public.feature_flags set enabled = true where key in ('events', 'rift_board');
insert into public.saves (user_id, slot, rev, data) values
  ('53000000-0000-0000-0000-00000000000a', 1, 3, '{"money": 1000, "inventory": {}, "party": []}'),
  ('53000000-0000-0000-0000-00000000000b', 1, 1, '{"money": 0, "inventory": {}, "party": []}'),
  ('53000000-0000-0000-0000-00000000000c', 1, 1, '{"money": 0, "inventory": {}, "party": []}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;

-- Online events.
insert into public.online_events (id, kind, starts_at, ends_at, data) values
  ('t-fest', 'festival', now() - interval '1 day', now() + interval '1 day',
    '{"name": {"en": "Test fest"}, "goal_kind": "battles", "target": 20, "rewards": ["tonic", "remedy", "strong_tonic", "max_tonic", "spark_charm"]}'),
  ('t-board', 'board', now() - interval '1 day', now() + interval '1 day',
    '{"name": {"en": "Test board"}, "rules": {"max_stage": 1}, "allowed": ["Kindlop", "Zippit"]}'),
  ('t-old', 'festival', now() - interval '10 days', now() - interval '1 hour',
    '{"goal_kind": "bonds", "target": 10, "rewards": ["tonic", "tonic", "tonic", "tonic", "tonic"]}'),
  ('t-later', 'sighting', now() + interval '3 days', now() + interval '4 days', '{"species": ["Kindlop"], "boost": 3}'),
  ('t-gone', 'festival', now() - interval '40 days', now() - interval '30 days', '{"goal_kind": "bonds", "target": 10}');
update public.online_events set total = 16 where id = 't-old';
insert into public.event_scores (event_id, user_id, score, at) values
  ('t-old', '53000000-0000-0000-0000-00000000000a', 8, now() - interval '2 days'),
  ('t-old', '53000000-0000-0000-0000-00000000000b', 5, now() - interval '3 days'),
  ('t-old', '53000000-0000-0000-0000-00000000000c', 3, now() - interval '4 days');
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb := public.event_list(); ids text[];
begin
  select array_agg(x->>'id') into ids from jsonb_array_elements(r->'events') x;
  assert ids @> array['t-fest', 't-board', 't-old', 't-later'] and not ids @> array['t-gone'], r::text;
  assert (select count(*) from unnest(ids) i where i like 'week-%') = 2, 'this week and the next from the rotation';
  assert not exists (select 1 from jsonb_array_elements(r->'events') x where x ? 'allowed'), 'the species list stays on the server';
  assert (select x->>'state' from jsonb_array_elements(r->'events') x where x->>'id' = 't-later') = 'upcoming';
  assert (select x->>'state' from jsonb_array_elements(r->'events') x where x->>'id' = 't-old') = 'ended';
  assert (select (x->>'mine')::int from jsonb_array_elements(r->'events') x where x->>'id' = 't-old') = 8;
  assert jsonb_array_length(r->'tiers') = 5;
  perform public.community_add('battles', 5);
  perform public.community_add('battles', 5);
  perform public.community_add('battles', 5);
  assert public.event_claim('t-fest', 4, 1, 3)->>'error' = 'not_reached';
end $$;
select pg_temp.as_user('b');
select public.community_add('battles', 9);
select pg_temp.as_user('a');
do $$
declare r jsonb;
begin
  assert (select (x->>'total')::int from jsonb_array_elements(public.event_list()->'events') x where x->>'id' = 't-fest') = 20;
  assert public.event_claim('t-fest', 6, 1, 3)->>'error' = 'bad_tier';
  assert public.event_claim('t-fest', 5, 1, 3)->>'error' = 'not_reached', 'the extra tier needs 150 %';
  assert public.event_claim('t-later', 1, 1, 3)->>'error' = 'no_such_event';
  r := public.event_claim('t-fest', 4, 1, 3);
  assert (r->>'ok')::boolean and r->>'item' = 'max_tonic' and (r->>'rev')::int = 4, r::text;
  assert public.event_claim('t-fest', 4, 1, 4)->>'error' = 'claimed';
  assert public.event_enter('t-fest', array['Kindlop'])->>'error' = 'no_such_event';
  assert public.event_enter('t-board', array['Kindlop', 'Smoldrake'])->>'error' = 'rules';
  assert public.event_enter('t-board', array['Kindlop', 'Kindlop'])->>'error' = 'bad_team';
  assert public.event_enter('t-board', array['Nobodyhere'])->>'error' = 'bad_team';
  assert public.event_enter('t-board', array[]::text[])->>'error' = 'bad_team';
  assert (public.event_enter('t-board', array['Kindlop', 'Zippit'])->>'ok')::boolean;
end $$;
insert into bv values ('rift1', public.battle_submit('rift', 'cinder', '{"teams": []}', '{"winner": "player", "rounds": 7}'));
insert into bv values ('rift2', public.battle_submit('rift', 'cinder', '{"teams": []}', '{"winner": "player", "rounds": 9}'));
select pg_temp.as_user('c');
do $$
declare r jsonb;
begin
  assert public.event_claim('t-fest', 1, 1, 1)->>'error' = 'not_helped';
  r := public.event_board('t-fest', false);
  assert jsonb_array_length(r->'rows') = 2 and (r->'rows'->0->>'score')::int = 15 and r->'rows'->0->>'name' = '', r::text;
  assert jsonb_array_length(public.event_board('t-fest', true)->'rows') = 0, 'friends only';
  assert public.event_board('t-later', false)->>'error' = 'no_such_event';
end $$;
reset role;
insert into public.battle_results (battle_id, verdict) values
  (((select v from bv where k = 'rift1')->>'battle_id')::bigint, 'ok'),
  (((select v from bv where k = 'rift2')->>'battle_id')::bigint, 'mismatch');
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb;
begin
  r := public.event_board('t-board', true);
  assert jsonb_array_length(r->'rows') = 1 and (r->'rows'->0->>'score')::int = 1 and (r->'rows'->0->>'me')::boolean, r::text;
  assert public.event_reward('t-fest', 1, 4)->>'error' = 'still_running';
  r := public.event_reward('t-old', 1, 4);
  assert (r->>'ok')::boolean and (r->>'rank')::int = 1 and (r->>'players')::int = 3 and r->>'title' = 'first'
    and r->>'item' = 'spark_charm' and (r->>'rev')::int = 5, r::text;
  assert public.event_reward('t-old', 1, 5)->>'error' = 'claimed';
  r := public.event_recap('t-old');
  assert (r->>'score')::int = 8 and (r->>'rank')::int = 1 and (r->>'players')::int = 3 and (r->>'best')::int = 8
    and (r->>'reached')::int = 5 and r->'award'->>'title' = 'first', r::text;
  assert public.event_recap('t-later')->>'error' = 'no_such_event';
  assert exists (select 1 from jsonb_array_elements(public.event_list()->'titles') t where t->>'event' = 't-old' and t->>'title' = 'first');
end $$;
select pg_temp.as_user('c');
do $$ begin
  assert public.event_reward('t-old', 1, 1)->>'title' = 'top10';
end $$;
select pg_temp.as_user('d');
do $$ begin
  assert public.event_reward('t-old', 1, 1)->>'error' = 'not_helped';
end $$;
reset role;
rollback;
