-- Online 100, area 6 (points 53, 55, 56, 57, 59, 60): friendship levels 6-10 with rewards,
-- favourite friends, the joint task of the day, the league rank on the Wanderer card, recent league
-- opponents as suggestions and the invite reward. The same cases as tests/unit/test_friends_more.gd.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-000000000061'), ('20000000-0000-0000-0000-000000000062'),
  ('20000000-0000-0000-0000-000000000063'), ('20000000-0000-0000-0000-000000000064'),
  ('20000000-0000-0000-0000-000000000065')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000' || u, false)
$$;
create temp table fc (who text primary key, code text);
create temp table fr (k text primary key, v jsonb);
grant all on fc, fr to authenticated;
update public.server_config set value = value || '{"favorites_max": 1, "pair_tasks": ["wave"]}'::jsonb
where key = 'friends_more';
update public.feature_flags set enabled = true where key = 'invite';

set role authenticated;
select pg_temp.as_user('61');
insert into fc values ('61', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('62');
insert into fc values ('62', public.hello(1)->'profile'->>'code');
select public.friend_request((select code from fc where who = '61'));
select pg_temp.as_user('63');
insert into fc values ('63', public.hello(1)->'profile'->>'code');
select public.friend_request((select code from fc where who = '61'));
select pg_temp.as_user('64');
insert into fc values ('64', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('65');
insert into fc values ('65', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('61');
select public.friend_respond((select code from fc where who = '62'), true);
select public.friend_respond((select code from fc where who = '63'), true);
reset role;
insert into public.saves (user_id, slot, rev, data) values
  ('20000000-0000-0000-0000-000000000061', 1, 4, '{"inventory": {"tonic": 1}}'),
  ('20000000-0000-0000-0000-000000000062', 2, 9, '{"inventory": {}}'),
  ('20000000-0000-0000-0000-000000000065', 1, 1, '{"inventory": {}}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;
update public.friendships set points = 160
where a = '20000000-0000-0000-0000-000000000061' and b = '20000000-0000-0000-0000-000000000062';
insert into public.league_fair_entries (season, user_id, team, rating, games)
values ((public._league_season()).id, '20000000-0000-0000-0000-000000000062', '[]', 1720, 10)
on conflict do nothing;

-- 56: levels 6-10 and their rewards. 53: the rank on the card. 59: favourites first.
set role authenticated;
select pg_temp.as_user('61');
insert into fr values ('list1', public.friends_list());
insert into fr values ('lv7', public.friend_level_claim((select code from fc where who = '62'), 7, 1, 4));
insert into fr values ('lv6', public.friend_level_claim((select code from fc where who = '62'), 6, 1, 4));
insert into fr values ('lv6b', public.friend_level_claim((select code from fc where who = '62'), 6, 1, 5));
insert into fr values ('lv6c', public.friend_level_claim((select code from fc where who = '63'), 6, 1, 5));
insert into fr values ('fav1', public.friend_favorite((select code from fc where who = '63'), true));
insert into fr values ('fav2', public.friend_favorite((select code from fc where who = '62'), true));
insert into fr values ('fav3', public.friend_favorite((select code from fc where who = '64'), true));
insert into fr values ('list2', public.friends_list());
reset role;

do $$
declare b jsonb;
begin
  assert public._level(0) = 1 and public._level(10) = 2 and public._level(100) = 5, 'levels 1-5 stay';
  assert public._level(149) = 5 and public._level(150) = 6 and public._level(519) = 9 and public._level(520) = 10
    and public._level(100000) = 10, 'levels 6-10';
  select x into b from fr, jsonb_array_elements(v->'friends') x where k = 'list1' and x->>'code' = (select code from fc where who = '62');
  assert (b->>'level')::int = 6, 'level 6 at 160 points ' || b::text;
  assert b->'level_ready' = '[6]', 'level 6 reward ready';
  assert (b->>'rank')::int = 4, 'card shows the league rank';
  assert (select v->>'error' from fr where k = 'lv7') = 'friend_level', 'level 7 not reached';
  assert (select v->>'item' from fr where k = 'lv6') = 'strong_tonic' and (select v->>'rev' from fr where k = 'lv6') = '5';
  assert (select v->>'error' from fr where k = 'lv6b') = 'already', 'once per friend and level';
  assert (select v->>'error' from fr where k = 'lv6c') = 'friend_level', 'level 1 friend has none';
  assert (select data->'inventory'->>'strong_tonic' from public.saves
    where user_id = '20000000-0000-0000-0000-000000000061' and slot = 1) = '3', 'reward in the bag';
  assert (select v->>'fav' from fr where k = 'fav1') = 'true';
  assert (select v->>'error' from fr where k = 'fav2') = 'favorites_full', 'favorites_max';
  assert (select v->>'error' from fr where k = 'fav3') = 'not_friends', 'only friends';
  assert (select v->'friends'->0->>'code' from fr where k = 'list2') = (select code from fc where who = '63'), 'favourite first';
  assert (select v->'friends'->0->>'fav' from fr where k = 'list2') = 'true';
  select x into b from fr, jsonb_array_elements(v->'friends') x where k = 'list2' and x->>'code' = (select code from fc where who = '62');
  assert b->'level_ready' = '[]', 'taken reward is gone';
end $$;

-- 57: the joint task of the day (both wave), points once for the pair.
set role authenticated;
select pg_temp.as_user('61');
select public.mail_send((select code from fc where who = '62'), 'wave', 0);
insert into fr values ('t1', public.pair_task_claim((select code from fc where who = '62'), 1, 5));
select pg_temp.as_user('62');
select public.mail_send((select code from fc where who = '61'), 'wave', 0);
select pg_temp.as_user('61');
insert into fr values ('t2', public.pair_task_claim((select code from fc where who = '62'), 1, 5));
insert into fr values ('t3', public.pair_task_claim((select code from fc where who = '62'), 1, 6));
insert into fr values ('list3', public.friends_list());
select pg_temp.as_user('62');
insert into fr values ('t4', public.pair_task_claim((select code from fc where who = '61'), 2, 9));
reset role;

do $$
declare b jsonb;
begin
  assert (select v->>'error' from fr where k = 't1') = 'not_done', 'both must send ' || (select v::text from fr where k = 't1');
  assert (select v->>'item' from fr where k = 't2') = 'tonic' and (select v->>'count' from fr where k = 't2') = '2';
  assert (select v->>'error' from fr where k = 't3') = 'already_today';
  assert (select v->>'ok' from fr where k = 't4') = 'true', 'the friend takes it too';
  assert (select fs.points from public.friendships fs where fs.a = '20000000-0000-0000-0000-000000000061'
    and fs.b = '20000000-0000-0000-0000-000000000062') = 163, 'pair points once';
  select x into b from fr, jsonb_array_elements(v->'friends') x where k = 'list3' and x->>'code' = (select code from fc where who = '62');
  assert b->'task' = '{"kind": "wave", "mine": true, "theirs": true, "claimed": true}', b::text;
end $$;

-- 60: recent league opponents as suggestions, without name or code.
insert into public.league_matches (league, season, user_id, opponent, seed, teams) values
  ('fair', (public._league_season()).id, '20000000-0000-0000-0000-000000000061', '20000000-0000-0000-0000-000000000064', 1, '[]'),
  ('fair', (public._league_season()).id, '20000000-0000-0000-0000-000000000061', '20000000-0000-0000-0000-000000000062', 2, '[]'),
  ('fair', (public._league_season()).id, '20000000-0000-0000-0000-000000000063', '20000000-0000-0000-0000-000000000064', 3, '[]');
insert into fr select 'm64', to_jsonb(id) from public.league_matches
  where user_id = '20000000-0000-0000-0000-000000000061' and opponent = '20000000-0000-0000-0000-000000000064';
insert into fr select 'm63', to_jsonb(id) from public.league_matches
  where user_id = '20000000-0000-0000-0000-000000000063';
set role authenticated;
select pg_temp.as_user('61');
insert into fr values ('s1', public.friend_suggestions());
insert into fr values ('sr_other', public.friend_suggest_request((select (v #>> '{}')::bigint from fr where k = 'm63')));
insert into fr values ('sr', public.friend_suggest_request((select (v #>> '{}')::bigint from fr where k = 'm64')));
insert into fr values ('s2', public.friend_suggestions());
reset role;

do $$
declare s jsonb := (select v from fr where k = 's1');
begin
  assert jsonb_array_length(s->'rows') = 1, 'friends are no suggestion ' || s::text;
  assert (s->'rows'->0->>'ref')::bigint = (select (v #>> '{}')::bigint from fr where k = 'm64');
  assert position((select code from fc where who = '64') in s::text) = 0, 'no code';
  assert not (s->'rows'->0 ? 'name'), 'no name';
  assert (select v->>'error' from fr where k = 'sr_other') = 'no_such_code', 'only own matches';
  assert (select v->>'status' from fr where k = 'sr') = 'pending', 'request sent';
  assert jsonb_array_length((select v from fr where k = 's2')->'rows') = 0, 'asked once';
end $$;

-- 55: invite link with a reward for both.
update public.profiles set created_at = now() - interval '30 days' where id = '20000000-0000-0000-0000-000000000063';
set role authenticated;
select pg_temp.as_user('63');
insert into fr values ('i_late', public.invite_redeem((select code from fc where who = '61')));
select pg_temp.as_user('65');
insert into fr values ('i_self', public.invite_redeem((select code from fc where who = '65')));
insert into fr values ('i1', public.invite_redeem((select code from fc where who = '61')));
insert into fr values ('i2', public.invite_redeem((select code from fc where who = '61')));
insert into fr values ('ic0', public.invite_claim(1, 1));
select pg_temp.as_user('61');
select public.friend_respond((select code from fc where who = '65'), true);
insert into fr values ('ist', public.invite_state());
insert into fr values ('ic61', public.invite_claim(1, 6));
insert into fr values ('ic61b', public.invite_claim(1, 7));
select pg_temp.as_user('65');
insert into fr values ('ic65', public.invite_claim(1, 1));
reset role;

do $$ begin
  assert (select v->>'error' from fr where k = 'i_late') = 'too_late', 'only new accounts';
  assert (select v->>'error' from fr where k = 'i_self') = 'no_such_code';
  assert (select v->>'status' from fr where k = 'i1') = 'pending', 'a request goes out';
  assert (select v->>'error' from fr where k = 'i2') = 'already', 'once per account';
  assert (select v->>'error' from fr where k = 'ic0') = 'nothing', 'not before the friendship is accepted';
  assert (select (v->>'ready')::int from fr where k = 'ist') = 1 and (select (v->>'invited')::int from fr where k = 'ist') = 1;
  assert (select v->>'item' from fr where k = 'ic61') = 'strong_tonic' and (select v->>'times' from fr where k = 'ic61') = '1';
  assert (select v->>'error' from fr where k = 'ic61b') = 'nothing', 'paid once';
  assert (select v->>'count' from fr where k = 'ic65') = '2', 'the new player gets it too';
end $$;

update public.feature_flags set enabled = false where key = 'invite';
update public.server_config set value = value || '{"favorites_max": 10, "pair_tasks": ["wave", "phrase", "gift"]}'::jsonb
where key = 'friends_more';
delete from auth.users where id in ('20000000-0000-0000-0000-000000000061', '20000000-0000-0000-0000-000000000062',
  '20000000-0000-0000-0000-000000000063', '20000000-0000-0000-0000-000000000064', '20000000-0000-0000-0000-000000000065');
