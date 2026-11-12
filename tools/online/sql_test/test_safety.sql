-- Online 100, area 9 (points 83, 85, 86, 88): parent switches, under-16 defaults, pair limit and
-- sandbagged league battles, reports after a battle. The same cases as tests/unit/test_safety.gd.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-000000000071'), ('20000000-0000-0000-0000-000000000072'),
  ('20000000-0000-0000-0000-000000000073')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000' || u, false)
$$;
create temp table sc (who text primary key, code text);
create temp table sr (k text primary key, v jsonb);
grant all on sc, sr to authenticated;
update public.feature_flags set enabled = true where key in ('bund', 'raid', 'live_duel', 'league_fair', 'league_open');

set role authenticated;
select pg_temp.as_user('71');
insert into sc values ('71', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('72');
insert into sc values ('72', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('73');
insert into sc values ('73', public.hello(1)->'profile'->>'code');
reset role;
-- 73 is 14: the shop's age question put them in band 13.
insert into public.shop_profiles (user_id, age_band) values ('20000000-0000-0000-0000-000000000073', 13)
on conflict (user_id) do update set age_band = 13;

-- 86: under 16 only friends and the fair league by default. 85: parents switch things off and on.
set role authenticated;
select pg_temp.as_user('73');
insert into sr values ('h73', public.hello(1));
insert into sr values ('pg73', public.parent_get());
insert into sr values ('open73', public.league_info('open'));
insert into sr values ('fair73', public.league_info('fair'));
insert into sr values ('bund73', public.bund_search(''));
insert into sr values ('ps73', public.parent_set('["bund"]', 1));
insert into sr values ('open73b', public.league_info('open'));
select pg_temp.as_user('71');
insert into sr values ('bad', public.parent_set('["shop"]', 1));
insert into sr values ('ps71', public.parent_set('["raid", "live_duel"]', 1));
insert into sr values ('h71', public.hello(1));
insert into sr values ('raid71', public.raid_list());
insert into sr values ('ps71b', public.parent_set('[]', 1));
insert into sr values ('raid71b', public.raid_list());
reset role;

do $$ begin
  assert not (select v->'flags' from sr where k = 'h73') ? 'league_open', 'open league hidden under 16';
  assert not (select v->'flags' from sr where k = 'h73') ? 'bund', 'bunds hidden under 16';
  assert (select v->'flags' from sr where k = 'h73') ? 'league_fair', 'fair league stays';
  assert (select v->'flags' from sr where k = 'h73') ? 'raid', 'raids with friends stay';
  assert (select (v->>'young')::boolean and not (v->>'custom')::boolean from sr where k = 'pg73'), (select v::text from sr where k = 'pg73');
  assert (select v->>'error' from sr where k = 'open73') = 'parent_off';
  assert (select v->>'ok' from sr where k = 'fair73') = 'true';
  assert (select v->>'error' from sr where k = 'bund73') = 'parent_off';
  assert (select v->'flags' from sr where k = 'ps73') ? 'league_open', 'a parent can allow the open league';
  assert (select v->>'ok' from sr where k = 'open73b') = 'true';
  assert (select v->>'error' from sr where k = 'bad') = 'bad_key';
  assert not (select v->'flags' from sr where k = 'h71') ? 'raid' and not (select v->'flags' from sr where k = 'h71') ? 'live_duel';
  assert (select v->'parent_off' from sr where k = 'h71') = '["raid", "live_duel"]';
  assert (select v->>'error' from sr where k = 'raid71') = 'parent_off';
  assert (select v->>'ok' from sr where k = 'raid71b') = 'true', 'switched on again';
end $$;

-- 85: no live duel with a player whose parents switched duels off.
set role authenticated;
select pg_temp.as_user('72');
select public.friend_request((select code from sc where who = '71'));
select public.team_set('[{"species": "Kindlop", "level": 10, "moves": []}, {"species": "Zippit", "level": 10, "moves": []},
  {"species": "Mossling", "level": 10, "moves": []}]');
select pg_temp.as_user('71');
select public.friend_respond((select code from sc where who = '72'), true);
select public.team_set('[{"species": "Kindlop", "level": 10, "moves": []}, {"species": "Zippit", "level": 10, "moves": []},
  {"species": "Mossling", "level": 10, "moves": []}]');
select public.parent_set('["live_duel"]', 1);
select pg_temp.as_user('72');
insert into sr values ('live_off', public.live_invite((select code from sc where who = '71')));
select pg_temp.as_user('71');
select public.parent_set('[]', 1);
select pg_temp.as_user('72');
insert into sr values ('live_on', public.live_invite((select code from sc where who = '71')));
reset role;

do $$ begin
  assert (select v->>'error' from sr where k = 'live_off') = 'parent_off', (select v::text from sr where k = 'live_off');
  assert (select v->>'ok' from sr where k = 'live_on') = 'true', (select v::text from sr where k = 'live_on');
end $$;

-- 88: a pair is rated at most pair_rated_daily times a day; a loss without damage is sandbagged.
insert into public.league_fair_entries (season, user_id, team, rating, games) values
  ((public._league_season()).id, '20000000-0000-0000-0000-000000000071', '[{"species": "Kindlop", "level": 50, "moves": []}]', 7100, 10),
  ((public._league_season()).id, '20000000-0000-0000-0000-000000000072', '[{"species": "Zippit", "level": 50, "moves": []}]', 7110, 10)
on conflict (season, user_id) do update set rating = excluded.rating, games = excluded.games;
insert into public.league_matches (league, season, user_id, opponent, seed, teams, state)
select 'fair', (public._league_season()).id, '20000000-0000-0000-0000-000000000071', '20000000-0000-0000-0000-000000000072',
  g, '[]', 'done' from generate_series(1, 3) g;
set role authenticated;
select pg_temp.as_user('71');
insert into sr values ('find', public.league_find('fair', 0));
reset role;
delete from public.league_matches where user_id = '20000000-0000-0000-0000-000000000071';
insert into public.battles (id, user_id, kind) values
  (9071001, '20000000-0000-0000-0000-000000000071', 'league_fair'),
  (9071002, '20000000-0000-0000-0000-000000000071', 'league_fair'),
  (9071003, '20000000-0000-0000-0000-000000000071', 'league_fair'),
  (9071004, '20000000-0000-0000-0000-000000000071', 'league_fair')
on conflict do nothing;
insert into public.league_matches (league, season, user_id, opponent, seed, teams, state, battle_id)
select 'fair', (public._league_season()).id, '20000000-0000-0000-0000-000000000071', '20000000-0000-0000-0000-000000000072',
  b, '[]', 'submitted', b from generate_series(9071001, 9071004) b;
select public._league_apply(9071001, '{"winner": "foe", "rounds": 1, "foe_damage": 0}');
select public._league_apply(9071002, '{"winner": "foe", "rounds": 1, "foe_damage": 0}');
select public._league_apply(9071003, '{"winner": "foe", "rounds": 1, "foe_damage": 0}');
select public._league_apply(9071004, '{"winner": "foe", "rounds": 6, "foe_damage": 40}');

do $$ begin
  assert (select v->>'found' from sr where k = 'find') = 'true', (select v::text from sr where k = 'find');
  assert (select v->>'rated' from sr where k = 'find') = 'false' and (select v->>'pair_limit' from sr where k = 'find') = 'true',
    'fourth battle against the same rival does not count';
  assert (select count(*) from public.league_matches where battle_id between 9071001 and 9071003 and sandbagged and not rated) = 3, 'sandbagged';
  assert (select count(*) from public.cheat_flags where user_id = '20000000-0000-0000-0000-000000000071' and reason = 'league_sandbag') = 1,
    'noted from the third sandbagged battle';
  assert (select games from public.league_fair_entries where user_id = '20000000-0000-0000-0000-000000000071'
    and season = (public._league_season()).id) = 11, 'only the real loss is rated';
end $$;

-- 83: a report straight after a battle, without the rival's code.
insert into sr select 'm4', to_jsonb(id::text) from public.league_matches where battle_id = 9071004;
set role authenticated;
select pg_temp.as_user('71');
insert into sr values ('rep', public.report_battle('league', (select v #>> '{}' from sr where k = 'm4'), 2));
insert into sr values ('rep_bad', public.report_battle('league', '999999999', 2));
insert into sr values ('rep_kind', public.report_battle('shop', '1', 2));
insert into sr values ('rep_duel', public.report_battle('duel', (select v->>'id' from sr where k = 'live_on'), 1));
select pg_temp.as_user('73');
insert into sr values ('rep_other', public.report_battle('league', (select v #>> '{}' from sr where k = 'm4'), 2));
reset role;

do $$ begin
  assert (select v->>'ok' from sr where k = 'rep') = 'true', (select v::text from sr where k = 'rep');
  assert (select target from public.reports where id = (select (v->>'report_id')::bigint from sr where k = 'rep'))
    = '20000000-0000-0000-0000-000000000072', 'the rival is reported';
  assert (select context from public.reports where id = (select (v->>'report_id')::bigint from sr where k = 'rep')) = 'league';
  assert (select v->>'error' from sr where k = 'rep_bad') = 'no_such_battle';
  assert (select v->>'error' from sr where k = 'rep_kind') = 'bad_context';
  assert (select v->>'ok' from sr where k = 'rep_duel') = 'true', 'live duel rival';
  assert (select v->>'error' from sr where k = 'rep_other') = 'no_such_battle', 'only own battles';
end $$;

delete from public.battles where id between 9071001 and 9071004;
delete from auth.users where id in ('20000000-0000-0000-0000-000000000071', '20000000-0000-0000-0000-000000000072',
  '20000000-0000-0000-0000-000000000073');
update public.feature_flags set enabled = false where key in ('bund', 'raid', 'live_duel');
