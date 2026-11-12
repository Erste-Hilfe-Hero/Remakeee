-- Online 100, areas 4 and 7: bund life and online events. The same cases as tests/unit/test_bund_events.gd.
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
update public.feature_flags set enabled = false where key in ('bund', 'events');
set role authenticated;
select pg_temp.as_user('a');
insert into bv values ('code_a', to_jsonb(public.hello(1)->'profile'->>'code'));
insert into bv values ('off_bund', public.bund_life());
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
  assert (select v->>'error' from bv where k = 'off_bund') = 'feature_off';
  assert (select v->>'error' from bv where k = 'off_events') = 'feature_off';
end $$;
update public.feature_flags set enabled = true where key in ('bund', 'events', 'rift_board');
insert into public.saves (user_id, slot, rev, data) values
  ('53000000-0000-0000-0000-00000000000a', 1, 1, '{"money": 1000, "inventory": {"tonic": 3, "grapple_line": 1}, "party": []}'),
  ('53000000-0000-0000-0000-00000000000b', 1, 1, '{"money": 0, "inventory": {}, "party": []}'),
  ('53000000-0000-0000-0000-00000000000c', 1, 1, '{"money": 0, "inventory": {}, "party": []}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;

-- Bund goal, level, reward, donations.
set role authenticated;
select pg_temp.as_user('a');
insert into bv values ('create', public.bund_create(4, 5));
select public.bund_invite((select v #>> '{}' from bv where k = 'code_b'));
select pg_temp.as_user('b');
select public.bund_answer((select (v->>'bund')::bigint from bv where k = 'create'), true);
select pg_temp.as_user('a');
do $$
declare r jsonb; kind text; i int;
begin
  r := public.bund_life();
  assert (r->>'level')::int = 1 and (r->>'xp')::int = 0 and r->>'lang' = 'any' and not (r->>'open')::boolean, r::text;
  assert (r->'goal'->>'target')::int = 40 and (r->'goal'->>'total')::int = 0, r::text;
  assert (r->'next')::int = 100, r::text;
  kind := r->'goal'->>'kind';
  insert into bv values ('kind', to_jsonb(kind));
  assert public.bund_goal_claim(1, 1)->>'error' = 'not_helped';
  perform public.community_add(kind, 9);
  assert (public.bund_life()->'goal'->>'mine')::int = 5, 'at most 5 per step';
  perform public.community_add('nothing', 5);
  assert (public.bund_life()->'goal'->>'total')::int = 5, 'other kinds do not count';
  assert public.bund_goal_claim(1, 1)->>'error' = 'not_reached';
  for i in 1 .. 7 loop perform public.community_add(kind, 5); end loop;
  r := public.bund_life();
  assert (r->'goal'->>'done')::boolean and (r->>'xp')::int = 200 and (r->>'level')::int = 2, r::text;
  perform public.community_add(kind, 5);
  assert (public.bund_life()->>'xp')::int = 200, 'the goal gives xp once';
  assert public.bund_goal_claim(1, 0)->>'error' = 'sync_first';
  r := public.bund_goal_claim(1, 1);
  assert (r->>'ok')::boolean and r->>'item' = 'strong_tonic' and (r->>'count')::int = 2 and (r->>'rev')::int = 2, r::text;
  assert public.bund_goal_claim(1, 2)->>'error' = 'claimed';
  assert public.bund_donate(1, 2, 150, '{}')->>'error' = 'bad_amount';
  assert public.bund_donate(1, 2, 0, '{}')->>'error' = 'bad_amount';
  assert public.bund_donate(1, 2, 0, '{"tonic": 1.5}')->>'error' = 'bad_amount';
  assert public.bund_donate(1, 2, 0, '{"grapple_line": 1}')->>'error' = 'not_donatable';
  assert public.bund_donate(1, 2, 5100, '{}')->>'error' = 'limit_today';
  assert public.bund_donate(1, 2, 2000, '{}')->>'error' = 'not_enough';
  assert public.bund_donate(1, 2, 0, '{"tonic": 9}')->>'error' = 'not_enough';
  r := public.bund_donate(1, 2, 500, '{"tonic": 2}');
  assert (r->>'ok')::boolean and (r->>'xp')::int = 15 and (r->>'money')::int = -500 and (r->'bag'->>'tonic')::int = -2
    and (r->>'rev')::int = 3, r::text;
  r := public.bund_life();
  assert (r->>'xp')::int = 215 and (r->>'week_xp')::int = 215 and (r->'donate'->>'coins_left')::int = 4500
    and (r->'donate'->>'items_left')::int = 18, r::text;
end $$;
select pg_temp.as_user('b');
do $$ begin
  assert public.bund_goal_claim(1, 1)->>'error' = 'not_helped', 'only who helped';
  assert public.bund_settings('de', true)->>'error' = 'not_allowed';
end $$;
reset role;
do $$
declare d jsonb := (select data from public.saves where user_id = '53000000-0000-0000-0000-00000000000a' and slot = 1);
begin
  assert (d->>'money')::int = 500 and (d->'inventory'->>'tonic')::int = 1 and (d->'inventory'->>'strong_tonic')::int = 2, d::text;
end $$;

-- Language, open bunds, search, blocking, board.
set role authenticated;
select pg_temp.as_user('a');
do $$ begin
  assert public.bund_settings('xx', true)->>'error' = 'bad_lang';
  assert (public.bund_settings('de', true)->>'open')::boolean;
end $$;
select pg_temp.as_user('d');
select public.block((select v #>> '{}' from bv where k = 'code_a'));
select pg_temp.as_user('c');
do $$
declare b bigint := (select (v->>'bund')::bigint from bv where k = 'create'); r jsonb;
begin
  r := public.bund_search('de');
  assert exists (select 1 from jsonb_array_elements(r->'bunds') x where (x->>'id')::bigint = b
    and (x->>'size')::int = 2 and (x->>'level')::int = 2 and (x->>'active')::int = 2), r::text;
  assert not exists (select 1 from jsonb_array_elements(public.bund_search('fr')->'bunds') x where (x->>'id')::bigint = b);
  assert (public.bund_join(b)->>'joined')::boolean, 'an open bund takes anyone';
  assert public.bund_join(b)->>'error' = 'in_bund';
end $$;
select pg_temp.as_user('d');
do $$
declare b bigint := (select (v->>'bund')::bigint from bv where k = 'create');
begin
  assert not exists (select 1 from jsonb_array_elements(public.bund_search('any')->'bunds') x where (x->>'id')::bigint = b),
    'never a bund with a blocked player';
  assert public.bund_join(b)->>'error' = 'no_such_bund';
end $$;
select pg_temp.as_user('a');
select public.bund_settings('de', false);
select pg_temp.as_user('e');
do $$
declare b bigint := (select (v->>'bund')::bigint from bv where k = 'create'); r jsonb;
begin
  assert not (public.bund_join(b)->>'joined')::boolean, 'a closed bund gets a request';
  assert public.bund_life()->>'error' = 'no_bund';
  r := public.bund_board();
  assert (r->'rows'->0->>'xp')::int = 215 and not (r->'rows'->0->>'me')::boolean, r::text;
end $$;
select pg_temp.as_user('a');
do $$
declare r jsonb := public.bund_board();
begin
  assert (r->'rows'->0->>'me')::boolean and (r->'rows'->0->>'level')::int = 2, r::text;
  assert exists (select 1 from jsonb_array_elements(public.bund_info()->'bund'->'pending') p where p->>'kind' = 'request');
end $$;
reset role;

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
