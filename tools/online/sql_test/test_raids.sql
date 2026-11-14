-- No legendary guardians here, so strength and guardian never depend on the roll (see test_raid_more.sql).
update public.server_config set value = jsonb_set(value, '{legendary_chance}', '0') where key = 'raid_rules';
-- Plan area 7, items 2847-2851, 2871, 2691: Raid Rifts with shared strength, attempts, rewards.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000c1'), ('20000000-0000-0000-0000-0000000000c2'),
  ('20000000-0000-0000-0000-0000000000c3'), ('20000000-0000-0000-0000-0000000000c4')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000' || u, false)
$$;
create temp table rc (who text primary key, code text);
create temp table rr (k text primary key, v jsonb);
grant all on rc, rr to authenticated;
update public.feature_flags set enabled = true where key = 'raid';

set role authenticated;
select pg_temp.as_user('c1');
insert into rc values ('c1', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species": "Kindlop", "level": 30, "moves": []}]');
select pg_temp.as_user('c2');
insert into rc values ('c2', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species": "Kindlop", "level": 30, "moves": []}]');
select public.friend_request((select code from rc where who = 'c1'));
select pg_temp.as_user('c3');
insert into rc values ('c3', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('c4');
insert into rc values ('c4', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('c1');
select public.friend_respond((select code from rc where who = 'c2'), true);
insert into rr values ('stranger', public.raid_open(jsonb_build_array((select code from rc where who = 'c3'))));
insert into rr values ('alone', public.raid_open('[]'));
insert into rr values ('open', public.raid_open(jsonb_build_array((select code from rc where who = 'c2'))));
insert into rr values ('list', public.raid_list());
insert into rr values ('start', public.raid_start(((select v from rr where k = 'open')->>'raid')::bigint, '["Kindlop"]'));
insert into rr values ('submit', public.battle_submit('raid', (select v->>'attempt_id' from rr where k = 'start'),
  '{"teams": [], "inputs": []}', '{"winner": "none", "rounds": 10, "hp": [[1], [1]]}'));
select pg_temp.as_user('c4');
insert into rr values ('outsider', public.raid_start(((select v from rr where k = 'open')->>'raid')::bigint, '["Kindlop"]'));
reset role;

do $$
declare
  st jsonb := (select v from rr where k = 'start');
  r public.raids;
begin
  assert (select v->>'error' from rr where k = 'stranger') = 'no_such_code', 'only friends or bund members';
  assert (select v->>'error' from rr where k = 'alone') = 'bad_party', '2 to 4 players';
  select * into r from public.raids where id = ((select v from rr where k = 'open')->>'raid')::bigint;
  assert r.players = 2 and r.hp_total = 1200 and r.hp_left = 1200, 'strength for 2 players: ' || r.hp_total;
  assert r.closes_at between now() + interval '47 hours' and now() + interval '49 hours', 'open 48 hours';
  assert (st->>'round_limit')::int = 10, 'at most 10 rounds';
  assert st->'teams'->1->0->>'species' = r.guardian, 'the guardian';
  assert (st->'teams'->0->0->>'level')::int = 50, 'fair Ring 50 team';
  assert ((select v from rr where k = 'submit')->>'ok')::boolean, 'submitted';
  assert (select v->>'error' from rr where k = 'outsider') = 'no_such_raid', 'members only';
  assert jsonb_array_length((select v from rr where k = 'list')->'rewards') > 0, 'open reward table';
  assert public._raid_hp(3) = 1680 and public._raid_hp(4) = 2100, '140 and 175 percent';
end $$;

-- Damage counts only after the referee's "ok" (2691).
do $$
declare
  rid bigint := ((select v from rr where k = 'open')->>'raid')::bigint;
  b bigint := ((select v from rr where k = 'submit')->>'battle_id')::bigint;
begin
  assert (select hp_left from public.raids where id = rid) = 1200, 'nothing before the check';
  insert into public.battle_results (battle_id, verdict, detail) values (b, 'ok', '{"foe_damage": 1100}');
  assert (select hp_left from public.raids where id = rid) = 100, 'damage taken off';
end $$;

-- c2 finishes it: damage never goes below zero; c1 and c2 both qualify for the same reward.
set role authenticated;
select pg_temp.as_user('c2');
insert into rr values ('start2', public.raid_start(((select v from rr where k = 'open')->>'raid')::bigint, '["Kindlop"]'));
insert into rr values ('submit2', public.battle_submit('raid', (select v->>'attempt_id' from rr where k = 'start2'),
  '{"teams": [], "inputs": []}', '{"winner": "player", "rounds": 3, "hp": [[1], [0]]}'));
reset role;
insert into public.battle_results (battle_id, verdict, detail)
values (((select v from rr where k = 'submit2')->>'battle_id')::bigint, 'ok', '{"foe_damage": 400}');
set role authenticated;
select pg_temp.as_user('c2');
insert into rr values ('claim2', public.raid_claim(((select v from rr where k = 'open')->>'raid')::bigint));
insert into rr values ('claim2b', public.raid_claim(((select v from rr where k = 'open')->>'raid')::bigint));
insert into rr values ('closed', public.raid_start(((select v from rr where k = 'open')->>'raid')::bigint, '["Kindlop"]'));
select pg_temp.as_user('c1');
insert into rr values ('claim1', public.raid_claim(((select v from rr where k = 'open')->>'raid')::bigint));
reset role;
do $$
declare
  rid bigint := ((select v from rr where k = 'open')->>'raid')::bigint;
begin
  assert (select hp_left from public.raids where id = rid) = 0, 'never below zero';
  assert (select damage from public.raid_members where raid_id = rid and user_id = '20000000-0000-0000-0000-0000000000c2') = 100,
    'only the damage that was left counts';
  assert (select won_at is not null from public.raids where id = rid), 'won';
  assert (select v->>'item' from rr where k = 'claim2') is not null, 'reward for 100 of 1200 (over 5 %)';
  assert (select v->>'item' from rr where k = 'claim1') = (select v->>'item' from rr where k = 'claim2'), 'same reward for all';
  assert (select v->>'error' from rr where k = 'claim2b') = 'claimed', 'once';
  assert (select v->>'error' from rr where k = 'closed') = 'raid_closed', 'no attempts after the win';
end $$;

-- Three attempts a day; a refused battle takes nothing off.
set role authenticated;
select pg_temp.as_user('c1');
insert into rr values ('open2', public.raid_open(jsonb_build_array((select code from rc where who = 'c2'))));
select public.raid_start(((select v from rr where k = 'open2')->>'raid')::bigint, '["Kindlop"]');
select public.raid_start(((select v from rr where k = 'open2')->>'raid')::bigint, '["Kindlop"]');
insert into rr values ('t3', public.raid_start(((select v from rr where k = 'open2')->>'raid')::bigint, '["Kindlop"]'));
insert into rr values ('t3s', public.battle_submit('raid', (select v->>'attempt_id' from rr where k = 't3'),
  '{"teams": [], "inputs": []}', '{"winner": "none"}'));
insert into rr values ('t4', public.raid_start(((select v from rr where k = 'open2')->>'raid')::bigint, '["Kindlop"]'));
reset role;
insert into public.battle_results (battle_id, verdict, detail)
values (((select v from rr where k = 't3s')->>'battle_id')::bigint, 'mismatch', '{"foe_damage": 999}');
do $$ begin
  assert (select v->>'error' from rr where k = 't4') = 'no_tries', 'three a day';
  assert (select hp_left from public.raids where id = ((select v from rr where k = 'open2')->>'raid')::bigint) = 1200,
    'a mismatch counts nothing';
end $$;

update public.feature_flags set enabled = false where key = 'raid';
delete from auth.users where id::text like '20000000-0000-0000-0000-0000000000c_';
