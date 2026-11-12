-- Online 100: weekend tournament (62, 74, 80), watching a live duel one move behind (73), the hidden
-- open round of a live duel, the best league team (77). The same cases as tests/unit/test_tourney_watch.gd.
insert into auth.users (id) values
  ('56000000-0000-0000-0000-00000000000a'), ('56000000-0000-0000-0000-00000000000b'),
  ('56000000-0000-0000-0000-00000000000c'), ('56000000-0000-0000-0000-00000000000d'),
  ('56000000-0000-0000-0000-00000000000e')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '56000000-0000-0000-0000-00000000000' || u, false)
$$;
create or replace function pg_temp.uid(u text) returns uuid language sql as $$
  select ('56000000-0000-0000-0000-00000000000' || u)::uuid
$$;
create temp table tw (k text primary key, v text);
grant all on tw to authenticated;
begin;
delete from public.tourneys;
update public.feature_flags set enabled = true where key in ('events', 'live_duel', 'league_fair');
insert into public.server_config (key, value) values ('tourney', '{"size": 4, "days": []}')
on conflict (key) do update set value = excluded.value;
insert into public.saves (user_id, slot, rev, data) values
  (pg_temp.uid('c'), 1, 1, '{"inventory": {}, "party": [], "storage": []}'),
  (pg_temp.uid('d'), 1, 1, '{"inventory": {}, "party": [], "storage": []}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;
set role authenticated;
do $$
declare w text;
begin
  foreach w in array array['a', 'b', 'c', 'd', 'e'] loop
    perform pg_temp.as_user(w);
    insert into tw values ('code_' || w, public.hello(1)->'profile'->>'code');
    perform public.team_set('[{"species": "Kindlop", "level": 40, "moves": []}, {"species": "Puddlet", "level": 40, "moves": []},
      {"species": "Mossling", "level": 40, "moves": []}]');
  end loop;
end $$;

-- 62: weekends only; four sign up (size 4 here), the fourth starts the knockout.
select pg_temp.as_user('a');
do $$ begin assert public.tourney_join('["Kindlop", "Puddlet"]')->>'error' = 'tourney_closed', 'weekends only'; end $$;
reset role;
update public.server_config set value = value || '{"days": [1, 2, 3, 4, 5, 6, 7]}' where key = 'tourney';
set role authenticated;
do $$
declare r jsonb;
begin
  r := public.tourney_join('["Kindlop", "Puddlet"]');
  assert r->'tourney'->>'state' = 'signup', r::text;
  assert public.tourney_join('["Kindlop", "Puddlet"]')->>'error' = 'joined';
  assert public.tourney_fight()->>'error' = 'no_tourney';
end $$;
select pg_temp.as_user('b');
select public.tourney_join('["Kindlop", "Puddlet"]');
select pg_temp.as_user('c');
select public.tourney_join('["Kindlop", "Puddlet"]');
select pg_temp.as_user('d');
do $$
declare r jsonb;
begin
  r := public.tourney_join('["Kindlop", "Puddlet"]')->'tourney';
  assert r->>'state' = 'running' and (r->>'round')::int = 1, r::text;
  assert (r->'foe'->>'place')::int = 3 and r->'foe'->>'name' = '' and r->'foe'->'team' = '["Kindlop", "Puddlet"]', r::text;
end $$;
select pg_temp.as_user('e');
do $$ begin
  assert public.tourney_join('["Kindlop", "Puddlet"]')->'tourney'->>'state' = 'signup', 'the fifth player opens the next one';
end $$;
-- Round 1: a sends the battle like the game, the referee's verdict comes in through battle_results.
select pg_temp.as_user('a');
do $$
declare r jsonb;
begin
  r := public.tourney_fight();
  assert (r->>'ok')::boolean and jsonb_array_length(r->'teams') = 2, r::text;
  assert public.battle_submit('tourney', '999999999', '{"teams": []}', '{}')->>'error' = 'no_such_fight';
  r := public.battle_submit('tourney', r->>'fight_id', '{"teams": [], "inputs": [{"t": "turn", "k": 5}]}', '{}');
  assert (r->>'ok')::boolean, r::text;
  insert into tw values ('battle_a', r->>'battle_id');
  assert public.tourney_fight()->>'error' = 'fought';
end $$;
select pg_temp.as_user('b');
select public.tourney_fight();
select pg_temp.as_user('c');
select public.tourney_fight();
select pg_temp.as_user('d');
select public.tourney_fight();
reset role;
insert into public.battle_results (battle_id, verdict, detail) values
  ((select v::bigint from tw where k = 'battle_a'), 'ok', '{"winner": "player", "foe_damage": 80, "rounds": 4}');
insert into public.battles (id, user_id, kind) values (9560001, pg_temp.uid('b'), 'tourney'),
  (9560002, pg_temp.uid('c'), 'tourney'), (9560003, pg_temp.uid('d'), 'tourney'), (9560004, pg_temp.uid('c'), 'tourney');
update public.tourney_fights set state = 'submitted', battle_id = 9560001, replay = '{"inputs": []}' where user_id = pg_temp.uid('b');
update public.tourney_fights set state = 'submitted', battle_id = 9560002, replay = '{"inputs": []}' where user_id = pg_temp.uid('c');
update public.tourney_fights set state = 'submitted', battle_id = 9560003, replay = '{"inputs": []}' where user_id = pg_temp.uid('d');
select public._tourney_apply(9560001, true, '{"winner": "foe", "foe_damage": 0, "rounds": 5}');
select public._tourney_apply(9560002, true, '{"winner": "player", "foe_damage": 30, "rounds": 5}');
do $$ begin
  assert (select state from public.tourney_fights where user_id = pg_temp.uid('a')) = 'done', 'verdict applied';
  assert (select round from public.tourneys order by id limit 1) = 1, 'd has not fought yet';
end $$;
select public._tourney_apply(9560003, true, '{"winner": "player", "foe_damage": 20, "rounds": 5}');
set role authenticated;
select pg_temp.as_user('c');
do $$
declare r jsonb;
begin
  r := public.tourney_info()->'tourney';
  assert (r->>'round')::int = 2 and (r->>'out_round')::int = 0, r::text;
  assert (r->'foe'->>'place')::int = 1, r::text;
  insert into tw values ('fight_c', public.tourney_fight()->>'fight_id');
end $$;
select pg_temp.as_user('d');
do $$ begin
  assert (public.tourney_info()->'tourney'->>'out_round')::int = 1, 'both won: more damage goes on';
  assert public.tourney_fight()->>'error' = 'no_tourney';
end $$;
reset role;
-- The final: c wins, a never plays and the time runs out.
update public.tourney_fights set state = 'submitted', battle_id = 9560004, replay = '{"seed": 1, "teams": [], "inputs": []}'
where id = (select v::bigint from tw where k = 'fight_c');
select public._tourney_apply(9560004, true, '{"winner": "player", "foe_damage": 10, "rounds": 5}');
do $$ begin assert (select state from public.tourneys order by id limit 1) = 'running'; end $$;
update public.tourneys set round_ends = now() - interval '1 second' where state = 'running';
set role authenticated;
select pg_temp.as_user('c');
do $$
declare r jsonb;
begin
  r := public.tourney_info()->'tourney';
  assert r->>'state' = 'done' and (r->>'won')::boolean, r::text;
  r := public.tourney_reward(1, 1);
  assert (r->>'tier')::int = 0 and r->>'item' = 'spark_charm', r::text;
  assert public.tourney_reward(1, (r->>'rev')::int)->>'error' = 'no_reward';
end $$;
select pg_temp.as_user('a');
do $$ begin assert (public.tourney_info()->'tourney'->>'out_round')::int = 2; end $$;
select pg_temp.as_user('d');
do $$ begin assert (public.tourney_reward(1, 1)->>'tier')::int = 2, 'out in the semi-final of four'; end $$;
-- 74, 80: everyone can watch the final.
select pg_temp.as_user('e');
do $$
declare r jsonb;
begin
  r := public.tourney_finals()->'rows';
  assert jsonb_array_length(r) = 1 and (r->0->>'champion')::boolean and r->0->>'name' = '', r::text;
  assert (public.tourney_replay((r->0->>'fight')::bigint)->'replay') ? 'inputs';
  assert public.tourney_replay((select v::bigint from tw where k = 'fight_c') - 1)->>'error' = 'no_such_fight', 'only finals';
end $$;
reset role;
do $$ begin
  assert (select replay ? 'seed' and replay->'inputs' = '[{"t": "turn", "k": 5}]' from public.tourney_fights
    where user_id = pg_temp.uid('a') and round = 1), 'the server keeps its own setup with the inputs';
  assert public._tourney_rounds(8) = 3 and public._tourney_rounds(4) = 2 and public._tourney_rounds(2) = 1;
end $$;

-- Live duel: the open round stays hidden; friends watch one move behind (73).
set role authenticated;
select pg_temp.as_user('a');
select public.friend_request((select v from tw where k = 'code_b'));
select public.friend_request((select v from tw where k = 'code_c'));
select pg_temp.as_user('b');
select public.friend_respond((select v from tw where k = 'code_a'), true);
select pg_temp.as_user('c');
select public.friend_respond((select v from tw where k = 'code_a'), true);
select pg_temp.as_user('a');
insert into tw values ('duel', public.live_invite((select v from tw where k = 'code_b'))->>'id');
select public.live_pick((select v::bigint from tw where k = 'duel'), '[0, 1, 2]');
select pg_temp.as_user('b');
select public.live_answer((select v::bigint from tw where k = 'duel'), true);
select public.live_pick((select v::bigint from tw where k = 'duel'), '[0, 1, 2]');
select pg_temp.as_user('a');
select public.live_pick((select v::bigint from tw where k = 'duel'), '[0, 1, 2]');
do $$
declare r jsonb;
begin
  r := public.live_move((select v::bigint from tw where k = 'duel'), 1, '{"k": 5}');
  assert (r->>'ok')::boolean and r->'moves'->'1'->0 = '{"k": 5}', r::text;
  assert public.live_watch((select v::bigint from tw where k = 'duel'))->>'error' = 'no_such_duel', 'not the own duel';
end $$;
select pg_temp.as_user('b');
do $$
declare r jsonb;
begin
  r := public.live_state((select v::bigint from tw where k = 'duel'));
  assert r->'moves'->'1'->0 = 'null'::jsonb, 'b does not see a''s choice of the open round: ' || r::text;
  perform public.live_move((select v::bigint from tw where k = 'duel'), 1, '{"k": 5}');
  perform public.live_move((select v::bigint from tw where k = 'duel'), 2, '{"k": 5}');
end $$;
select pg_temp.as_user('a');
select public.live_move((select v::bigint from tw where k = 'duel'), 2, '{"k": 5}');
select pg_temp.as_user('d');
do $$ begin
  assert public.live_watch((select v::bigint from tw where k = 'duel'))->>'error' = 'no_such_duel', 'only friends watch';
  assert jsonb_array_length(public.live_watch_list()->'duels') = 0;
end $$;
select pg_temp.as_user('c');
do $$
declare r jsonb;
begin
  r := public.live_watch_list()->'duels';
  assert jsonb_array_length(r) = 1 and r->0->>'id' = (select v from tw where k = 'duel'), r::text;
  r := public.live_watch((select v::bigint from tw where k = 'duel'));
  assert (r->>'side')::int = -1 and (r->>'round')::int = 3, r::text;
  assert (select array_agg(k) from jsonb_object_keys(r->'moves') k) = array['1'], 'round 2 is held back: ' || r::text;
  assert jsonb_array_length(r->'names') = 2;
end $$;
select pg_temp.as_user('a');
select public.live_forfeit((select v::bigint from tw where k = 'duel'));
select pg_temp.as_user('c');
do $$ begin
  assert (select count(*) from jsonb_object_keys(public.live_watch((select v::bigint from tw where k = 'duel'))->'moves')) = 2,
    'all of it once the duel is over';
end $$;
select pg_temp.as_user('b');
select public.block((select v from tw where k = 'code_c'));
select pg_temp.as_user('c');
do $$ begin
  assert public.live_watch((select v::bigint from tw where k = 'duel'))->>'error' = 'no_such_duel', 'blocked by a player';
end $$;

-- 77: the best league team of the season, placement battles first, no name.
select pg_temp.as_user('a');
do $$ begin assert public.league_top_team('fair')->'team' = 'null'::jsonb; end $$;
reset role;
insert into public.league_fair_entries (season, user_id, team, rating, games) values
  ((public._league_season()).id, pg_temp.uid('b'), '[{"species": "Kindlop", "level": 50, "moves": ["Ember"]}]', 9900, 12),
  ((public._league_season()).id, pg_temp.uid('c'), '[{"species": "Puddlet", "level": 50, "moves": []}]', 9950, 2)
on conflict (season, user_id) do update set rating = excluded.rating, games = excluded.games, team = excluded.team;
set role authenticated;
do $$
declare r jsonb;
begin
  r := public.league_top_team('fair');
  assert r->'team'->0->>'species' = 'Kindlop' and (r->>'games')::int = 12 and not r ? 'name', r::text;
  assert public.league_top_team('x')->>'error' = 'bad_league';
end $$;
reset role;
rollback;
