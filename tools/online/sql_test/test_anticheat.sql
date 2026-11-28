-- Plan area 7, items 2921-2925: save_put compares with the save before, knows the game's ids,
-- drops values the server keeps, and notes refused saves in cheat_flags.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000c1') on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;
-- The last save of slot 1 lies [mins] minutes back.
create or replace function pg_temp.age(mins int) returns void language sql as $$
  update public.saves set saved_at = now() - make_interval(mins => mins)
  where user_id = '20000000-0000-0000-0000-0000000000c1' and slot = 1
$$;
grant execute on function pg_temp.as_user(text) to authenticated;

do $$ begin
  assert (select count(*) from public.known_ids where kind = 'species') >= 21, 'species loaded';
  assert exists (select 1 from public.known_ids where kind = 'move' and id = 'Kiln Strike'), 'moves loaded';
  assert exists (select 1 from public.known_ids where kind = 'item'), 'items loaded';
end $$;

set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000c1');
select public.hello(1);

do $$
declare
  r jsonb;
  item text;
begin
  reset role;
  item := (select id from public.known_ids where kind = 'item' order by id limit 1);
  set role authenticated;
  -- A first save may hold the start money plus what an honest hour could bring.
  r := public.save_put(1, jsonb_build_object('schema', 1, 'money', 500, 'play_time', 60,
    'party', jsonb_build_array(jsonb_build_object('species', 'Kindlop', 'level', 5, 'moves', jsonb_build_array('Kiln Strike'))),
    'inventory', jsonb_build_object(item, 2), 'gems', 999, 'league', jsonb_build_object('rating', 3000)), '', 0);
  assert (r->>'ok')::boolean, 'honest first save: ' || r::text;
  assert (public.save_get(1)->'data') ? 'money', 'stored';
  assert not (public.save_get(1)->'data') ? 'gems', 'server-kept values are dropped (2924)';
  assert not (public.save_get(1)->'data') ? 'league', 'league values are dropped (2924)';

  -- Money: at most 5000 per minute played (2921).
  r := public.save_put(1, '{"schema": 1, "money": 20000, "play_time": 120}', '', 1);
  assert r->>'error' = 'refused' and r->>'reason' = 'money_fast', 'money too fast: ' || r::text;
  r := public.save_put(1, '{"schema": 1, "money": 5400, "play_time": 120}', '', 1);
  assert (r->>'ok')::boolean, 'one minute, 4900 more is fine: ' || r::text;

  -- Play time: only the real time since the last save plus 5 minutes (2923).
  r := public.save_put(1, '{"schema": 1, "money": 5400, "play_time": 3000}', '', 2);
  assert r->>'reason' = 'play_time_fast', 'more play time than real time: ' || r::text;
end $$;

reset role;
select pg_temp.age(60);
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000c1');
do $$
declare r jsonb;
begin
  r := public.save_put(1, '{"schema": 1, "money": 5400, "play_time": 3000}', '', 2);
  assert (r->>'ok')::boolean, 'an hour later it is fine: ' || r::text;
  -- Unknown kinds, moves and items (2922).
  r := public.save_put(1, '{"schema": 1, "money": 1, "play_time": 3000, "party": [{"species": "Pikachoo"}]}', '', 3);
  assert r->>'reason' = 'unknown_species', r::text;
  r := public.save_put(1, '{"schema": 1, "money": 1, "play_time": 3000, "storage": [{"species": "Kindlop", "moves": ["Mega Blast 9000"]}]}', '', 3);
  assert r->>'reason' = 'unknown_move', r::text;
  r := public.save_put(1, '{"schema": 1, "money": 1, "play_time": 3000, "inventory": {"golden_hack": 1}}', '', 3);
  assert r->>'reason' = 'unknown_item', r::text;
  r := public.save_put(1, '{"schema": 1, "money": 1, "play_time": 3000, "party": [{"species": "Kindlop", "held": "golden_hack"}]}', '', 3);
  assert r->>'reason' = 'unknown_item', 'held items count too';
  -- A new journey in the slot (less play time) starts again from the start money.
  r := public.save_put(1, '{"schema": 1, "money": 500, "play_time": 30}', '', 3);
  assert (r->>'ok')::boolean, 'new journey: ' || r::text;
  r := public.save_put(1, '{"schema": 1, "money": 90000, "play_time": 10}', '', 4);
  assert r->>'reason' = 'money_fast', 'a new journey cannot start rich';
end $$;

-- Three notes in a week: out of the leagues until Ali clears the account (2925).
reset role;
do $$ begin
  assert (select count(*) from public.cheat_flags where user_id = '20000000-0000-0000-0000-0000000000c1') >= 3, 'refusals are noted';
  assert public._cheat_held('20000000-0000-0000-0000-0000000000c1');
end $$;
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000c1');
do $$ begin
  assert public.league_info('fair')->>'error' = 'under_review', 'held accounts cannot play leagues';
end $$;
reset role;
update public.profiles set cheat_cleared_at = now() where id = '20000000-0000-0000-0000-0000000000c1';
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000c1');
do $$ begin
  assert (public.league_info('fair')->>'ok')::boolean, 'cleared by Ali';
end $$;

-- An empty known_ids (fresh server before the data load) never locks honest players out.
reset role;
do $$ begin
  assert public._ids_known('species', array['Kindlop']);
  assert not public._ids_known('species', array['Kindlop', 'Nobody']);
  assert public._ids_known('species', array[null, '']);
end $$;
delete from public.cheat_flags where user_id = '20000000-0000-0000-0000-0000000000c1';
delete from public.saves where user_id = '20000000-0000-0000-0000-0000000000c1';
delete from auth.users where id = '20000000-0000-0000-0000-0000000000c1';
