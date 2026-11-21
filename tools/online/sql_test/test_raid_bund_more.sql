-- Online 100, areas 3 and 4: random raid groups (25), Echo teams (26), role signs (27), bund rank
-- perks (34), bund house (35), bund against bund (37). The same cases as tests/unit/test_raid_bund_more.gd.
insert into auth.users (id) values
  ('55000000-0000-0000-0000-00000000000a'), ('55000000-0000-0000-0000-00000000000b'),
  ('55000000-0000-0000-0000-00000000000c'), ('55000000-0000-0000-0000-00000000000d'),
  ('55000000-0000-0000-0000-00000000000e'), ('55000000-0000-0000-0000-00000000000f'),
  ('55000000-0000-0000-0000-000000000001'), ('55000000-0000-0000-0000-000000000002')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '55000000-0000-0000-0000-00000000000' || u, false)
$$;
create or replace function pg_temp.uid(u text) returns uuid language sql as $$
  select ('55000000-0000-0000-0000-00000000000' || u)::uuid
$$;
create temp table rb (k text primary key, v text);
grant all on rb to authenticated;
begin;
delete from public.bunds;
delete from public.raid_queue;
update public.feature_flags set enabled = true where key in ('raid', 'bund');
update public.server_config set value = '["Cairnhold", "Leviarch"]' where key = 'raid_guardians';
update public.server_config set value = jsonb_set(value, '{legendary_chance}', '0') where key = 'raid_rules';
update public.server_config set value = value || '{"war_size": 2, "war_days": []}' where key = 'bund_rules';
insert into public.saves (user_id, slot, rev, data) values
  ('55000000-0000-0000-0000-00000000000a', 1, 1, '{"inventory": {"tonic": 50}, "party": [], "storage": []}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;
set role authenticated;
do $$
declare w text;
begin
  foreach w in array array['a', 'b', 'c', 'd', 'e', 'f', '1', '2'] loop
    perform pg_temp.as_user(w);
    insert into rb values ('code_' || w, public.hello(1)->'profile'->>'code');
    perform public.team_set('[{"species": "Kindlop", "level": 40, "moves": []}, {"species": "Puddlet", "level": 40, "moves": []}]');
  end loop;
end $$;

-- 25, 27: two players form a group after group_wait seconds; roles come along.
select pg_temp.as_user('a');
do $$
declare r jsonb;
begin
  assert public.raid_find(9, '')->>'error' = 'bad_tier';
  assert public.raid_find(1, 'boss')->>'error' = 'bad_role';
  r := public.raid_find(1, 'attack');
  assert not (r->>'found')::boolean and (r->>'waiting')::int = 0, r::text;
end $$;
select pg_temp.as_user('b');
do $$ begin assert not (public.raid_find(1, 'guard')->>'found')::boolean, 'b just came'; end $$;
reset role;
update public.raid_queue set created_at = now() - interval '31 seconds' where user_id = pg_temp.uid('a');
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb;
begin
  r := public.raid_find(1, 'attack');
  assert (r->>'found')::boolean and (r->>'echoes')::int = 0, r::text;
  insert into rb values ('raid', r->>'raid');
end $$;
select pg_temp.as_user('b');
do $$
declare r jsonb;
begin
  r := public.raid_find(1, 'guard');
  assert (r->>'found')::boolean and r->>'raid' = (select v from rb where k = 'raid'), r::text;
  r := public.raid_list()->'raids'->0;
  assert (r->>'players')::int = 2 and r->>'role' = 'guard', r::text;
  assert (select array_agg(m->>'role' order by m->>'role') from jsonb_array_elements(r->'members') m) = array['attack', 'guard'], r::text;
end $$;
select pg_temp.as_user('a');
do $$ begin
  assert (public.raid_role((select v::bigint from rb where k = 'raid'), 'help')->>'ok')::boolean;
  assert public.raid_list()->'raids'->0->>'role' = 'help';
  assert public.raid_role((select v::bigint from rb where k = 'raid'), 'boss')->>'error' = 'bad_role';
end $$;
select pg_temp.as_user('c');
do $$ begin
  assert public.raid_role((select v::bigint from rb where k = 'raid'), 'help')->>'error' = 'no_such_raid';
end $$;

-- 84 + 26: blocked players never meet; alone after echo_wait, three Echo teams fill the places.
select public.block((select v from rb where k = 'code_d'));
select public.raid_find(0, '');
select pg_temp.as_user('d');
select public.raid_find(0, '');
reset role;
update public.raid_queue set created_at = now() - interval '31 seconds' where user_id = pg_temp.uid('d');
set role authenticated;
do $$ begin assert not (public.raid_find(0, '')->>'found')::boolean, 'blocked: no group'; end $$;
reset role;
update public.raid_queue set created_at = now() - interval '61 seconds' where user_id = pg_temp.uid('c');
set role authenticated;
select pg_temp.as_user('c');
do $$
declare r jsonb;
begin
  r := public.raid_find(0, 'attack');
  assert (r->>'found')::boolean and (r->>'echoes')::int = 3, r::text;
  insert into rb values ('solo', r->>'raid');
  r := public.raid_list()->'raids'->0;
  assert jsonb_array_length(r->'members') = 4
    and (select count(*) from jsonb_array_elements(r->'members') m where (m->>'echo')::boolean) = 3, r::text;
end $$;
select pg_temp.as_user('d');
do $$ begin
  assert not (public.raid_find(0, '')->>'found')::boolean, 'd still waits';
  assert (public.raid_find_cancel()->>'ok')::boolean;
end $$;
reset role;
do $$
declare x public.raids;
begin
  assert not exists (select 1 from public.raid_queue where user_id = pg_temp.uid('d'));
  select * into x from public.raids where id = (select v::bigint from rb where k = 'solo');
  assert x.players = 4 and x.hp_total = public._raid_hp(4) * 70 / 100, row_to_json(x)::text;
  assert x.hp_left = x.hp_total - 3 * (x.hp_total * 15 / 100), row_to_json(x)::text;
end $$;

-- 34, 35: perks by bund rank and the bund house.
set role authenticated;
select pg_temp.as_user('a');
insert into rb values ('bund', public.bund_create(1, 2)->>'bund');
reset role;
insert into public.bund_members (user_id, bund_id) values (pg_temp.uid('b'), (select v::bigint from rb where k = 'bund'));
update public.bunds set xp = 2000 where id = (select v::bigint from rb where k = 'bund');
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb;
begin
  r := public.bund_stats();
  assert (r->>'level')::int = 5 and (r->>'donate_daily')::int = 30, r::text;
  r := public.bund_donate(1, 1, 'tonic', 25);
  assert (r->>'ok')::boolean, r::text;
  insert into rb values ('rev', r->>'rev');
end $$;
reset role;
update public.bunds set xp = 4500, goal_progress = 999, goal_week = public._week() where id = (select v::bigint from rb where k = 'bund');
set role authenticated;
do $$
declare r jsonb;
begin
  r := public.bund_goal_claim(1, (select v::int from rb where k = 'rev'));
  assert (r->>'count')::int = 4, r::text;
end $$;
reset role;
update public.bunds set xp = 0 where id = (select v::bigint from rb where k = 'bund');
set role authenticated;
select pg_temp.as_user('b');
do $$
declare r jsonb;
begin
  r := public.bund_house();
  assert (r->>'slots')::int = 3 and not (r->>'can_edit')::boolean, r::text;
  assert public.bund_house_set('["lantern"]')->>'error' = 'not_allowed';
end $$;
select pg_temp.as_user('a');
do $$ begin
  assert public.bund_house_set('["fountain"]')->>'error' = 'bad_decor';
  assert public.bund_house_set('["lantern", "banner", "bench", "map_table"]')->>'error' = 'bad_decor';
  assert public.bund_house_set('["lantern", "lantern"]')->>'error' = 'bad_decor';
  assert (public.bund_house_set('["lantern", "banner"]')->>'ok')::boolean;
end $$;
select pg_temp.as_user('b');
do $$ begin
  assert public.bund_house()->'house' = '["lantern", "banner"]', 'every member sees the house';
  assert jsonb_array_length(public.bund_house()->'members') = 2;
end $$;
reset role;
update public.bunds set xp = 1500 where id = (select v::bigint from rb where k = 'bund');
set role authenticated;
select pg_temp.as_user('a');
do $$ begin
  assert (public.bund_house()->>'slots')::int = 4;
  assert (public.bund_house_set('["lantern", "banner", "bench", "map_table"]')->>'ok')::boolean;
end $$;
select pg_temp.as_user('c');
do $$ begin assert public.bund_house()->>'error' = 'no_bund'; end $$;

-- 37: bund against bund (war_size 2 here): weekends only, paired when both are full, renown at the end.
select pg_temp.as_user('e');
insert into rb values ('ba', public.bund_create(3, 4)->>'bund');
select pg_temp.as_user('1');
insert into rb values ('bb', public.bund_create(5, 6)->>'bund');
reset role;
insert into public.bund_members (user_id, bund_id) values (pg_temp.uid('f'), (select v::bigint from rb where k = 'ba')),
  (pg_temp.uid('2'), (select v::bigint from rb where k = 'bb'));
set role authenticated;
select pg_temp.as_user('e');
do $$ begin
  assert public.bund_war_join('["Kindlop", "Puddlet"]')->>'error' = 'war_closed', 'weekends only';
end $$;
reset role;
update public.server_config set value = value || '{"war_days": [1, 2, 3, 4, 5, 6, 7]}' where key = 'bund_rules';
set role authenticated;
do $$
declare r jsonb;
begin
  r := public.bund_war_join('["Kindlop", "Puddlet"]');
  assert (r->>'joined')::boolean and r->'war' = 'null'::jsonb, r::text;
  assert public.bund_war_join('["Kindlop"]')->>'error' = 'joined';
  assert public.bund_war_fight()->>'error' = 'no_war';
end $$;
select pg_temp.as_user('f');
select public.bund_war_join('["Kindlop", "Puddlet"]');
select pg_temp.as_user('1');
select public.bund_war_join('["Kindlop", "Puddlet"]');
select pg_temp.as_user('2');
do $$ begin
  assert public.bund_war_join('["Kindlop", "Puddlet"]')->'war' <> 'null'::jsonb, 'both bunds full: paired';
end $$;
select pg_temp.as_user('c');
do $$ begin assert public.bund_war_join('["Kindlop"]')->>'error' = 'no_bund'; end $$;
-- e sends the battle like the game; the referee's verdict comes in through battle_results.
select pg_temp.as_user('e');
do $$
declare r jsonb;
begin
  r := public.bund_war_fight();
  assert (r->>'ok')::boolean and jsonb_array_length(r->'teams') = 2, r::text;
  assert public.battle_submit('bund_war', '999999999', '{"teams": []}', '{}')->>'error' = 'no_such_fight';
  r := public.battle_submit('bund_war', r->>'fight_id', '{"teams": []}', '{}');
  assert (r->>'ok')::boolean, r::text;
  insert into rb values ('battle_e', r->>'battle_id');
  assert public.bund_war_fight()->>'error' = 'fought';
end $$;
select pg_temp.as_user('f');
select public.bund_war_fight();
select pg_temp.as_user('1');
select public.bund_war_fight();
select pg_temp.as_user('2');
select public.bund_war_fight();
reset role;
insert into public.battle_results (battle_id, verdict, detail) values
  ((select v::bigint from rb where k = 'battle_e'), 'ok', '{"winner": "foe", "foe_damage": 10}');
insert into public.battles (id, user_id, kind) values (9550001, pg_temp.uid('f'), 'bund_war'),
  (9550002, pg_temp.uid('1'), 'bund_war'), (9550003, pg_temp.uid('2'), 'bund_war');
update public.bund_war_fights set state = 'submitted', battle_id = 9550001 where user_id = pg_temp.uid('f');
update public.bund_war_fights set state = 'submitted', battle_id = 9550002 where user_id = pg_temp.uid('1');
update public.bund_war_fights set state = 'submitted', battle_id = 9550003 where user_id = pg_temp.uid('2');
select public._bund_war_apply(9550001, true, '{"winner": "player"}');
select public._bund_war_apply(9550002, true, '{"winner": "foe"}');
do $$ begin
  assert (select state from public.bund_war_fights where user_id = pg_temp.uid('e')) = 'done', 'verdict applied';
  assert not (select settled from public.bund_wars where bund_a = (select v::bigint from rb where k = 'bb')
    or bund_b = (select v::bigint from rb where k = 'bb')), 'one fight still open';
end $$;
select public._bund_war_apply(9550003, true, '{"winner": "foe"}');
set role authenticated;
select pg_temp.as_user('e');
do $$
declare r jsonb;
begin
  r := public.bund_war_info()->'war';
  assert (r->>'settled')::boolean and r->>'result' = 'won' and (r->>'wins')::int = 1 and (r->>'foe_wins')::int = 0, r::text;
  assert jsonb_array_length(r->'places') = 2 and r->'places'->1->>'mine_result' = 'won', r::text;
  assert (public.bund_house()->>'war_wins')::int = 1;
end $$;
select pg_temp.as_user('1');
do $$ begin assert public.bund_war_info()->'war'->>'result' = 'lost'; end $$;
reset role;
do $$ begin
  assert (select xp from public.bunds where id = (select v::bigint from rb where k = 'ba')) = 300;
  assert (select xp from public.bunds where id = (select v::bigint from rb where k = 'bb')) = 100, 'taking part counts too';
end $$;
rollback;
