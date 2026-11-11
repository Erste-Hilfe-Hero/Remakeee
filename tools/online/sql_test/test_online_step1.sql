-- Online step 1: Spirling trading, weekly Rift and league boards, daily online gift.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000e1'), ('20000000-0000-0000-0000-0000000000e2'),
  ('20000000-0000-0000-0000-0000000000e3')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000' || u, false)
$$;
create temp table ec (who text primary key, code text);
create temp table er (k text primary key, v jsonb);
grant all on ec, er to authenticated;
update public.feature_flags set enabled = true where key in ('trade', 'trade_spirling', 'rift_board', 'league_board', 'daily_gift');

set role authenticated;
select pg_temp.as_user('e1');
insert into ec values ('e1', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('e2');
insert into ec values ('e2', public.hello(1)->'profile'->>'code');
select public.friend_request((select code from ec where who = 'e1'));
select pg_temp.as_user('e3');
insert into ec values ('e3', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('e1');
select public.friend_respond((select code from ec where who = 'e2'), true);
reset role;
update public.friendships set points = 30, accepted_at = now() - interval '8 days'
where a = least('20000000-0000-0000-0000-0000000000e1'::uuid, '20000000-0000-0000-0000-0000000000e2'::uuid);
insert into public.saves (user_id, slot, rev, data) values
  ('20000000-0000-0000-0000-0000000000e1', 1, 1, '{"inventory": {"tonic": 1},
    "party": [{"uid": "a1", "species": "Kindlop", "level": 12, "nickname": "Bob", "origin_era": 2, "box": 3, "favorite": false},
              {"uid": "a2", "species": "Zippit", "level": 9}],
    "storage": [{"uid": "a3", "species": "Wickit", "level": 5, "held": "keen_lens"},
                {"uid": "a4", "species": "Wickit", "level": 5, "gleam": true},
                {"uid": "a5", "species": "Wickit", "level": 5, "favorite": true}]}'),
  ('20000000-0000-0000-0000-0000000000e2', 1, 1, '{"inventory": {},
    "party": [{"uid": "b1", "species": "Zippit", "level": 20}],
    "storage": [{"uid": "b2", "species": "Kindlop", "level": 15, "crystal": {}}]}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;

-- Spirling trading: only tradeable Spirlings, the team keeps one, both confirm the same offer.
set role authenticated;
select pg_temp.as_user('e1');
insert into er values ('open', public.trade_open((select code from ec where who = 'e2')));
insert into er values ('held', public.trade_put_spirlings(((select v from er where k = 'open')->>'trade')::bigint, 1, 1, array['a3']));
insert into er values ('gleam', public.trade_put_spirlings(((select v from er where k = 'open')->>'trade')::bigint, 1, 1, array['a4']));
insert into er values ('fav', public.trade_put_spirlings(((select v from er where k = 'open')->>'trade')::bigint, 1, 1, array['a5']));
insert into er values ('none', public.trade_put_spirlings(((select v from er where k = 'open')->>'trade')::bigint, 1, 1, array['zz']));
insert into er values ('all', public.trade_put_spirlings(((select v from er where k = 'open')->>'trade')::bigint, 1, 1, array['a1', 'a2']));
insert into er values ('four', public.trade_put_spirlings(((select v from er where k = 'open')->>'trade')::bigint, 1, 1, array['a1', 'a2', 'a3', 'a4']));
insert into er values ('stale', public.trade_put_spirlings(((select v from er where k = 'open')->>'trade')::bigint, 1, 0, array['a1']));
insert into er values ('put1', public.trade_put_spirlings(((select v from er where k = 'open')->>'trade')::bigint, 1, 1, array['a1']));
select pg_temp.as_user('e2');
insert into er values ('put2', public.trade_put_spirlings(((select v from er where k = 'open')->>'trade')::bigint, 1, 1, array['b2']));
insert into er values ('list2', public.trade_list());
select pg_temp.as_user('e1');
insert into er values ('old_confirm', public.trade_confirm(((select v from er where k = 'open')->>'trade')::bigint, '{}'::jsonb));
insert into er values ('blind', public.trade_confirm(((select v from er where k = 'open')->>'trade')::bigint, '{}'::jsonb, array['b1']));
insert into er values ('ok1', public.trade_confirm(((select v from er where k = 'open')->>'trade')::bigint, '{}'::jsonb, array['b2']));
select pg_temp.as_user('e2');
insert into er values ('ok2', public.trade_confirm(((select v from er where k = 'open')->>'trade')::bigint, '{}'::jsonb, array['a1']));
insert into er values ('get2', public.trade_collect(((select v from er where k = 'open')->>'trade')::bigint, 1, 2));
select pg_temp.as_user('e1');
insert into er values ('get1', public.trade_collect(((select v from er where k = 'open')->>'trade')::bigint, 1, 2));
reset role;

do $$
declare e1 jsonb; e2 jsonb;
begin
  select data into e1 from public.saves where user_id = '20000000-0000-0000-0000-0000000000e1' and slot = 1;
  select data into e2 from public.saves where user_id = '20000000-0000-0000-0000-0000000000e2' and slot = 1;
  assert (select v->>'error' from er where k = 'held') = 'holds_item', 'a Spirling holding an item stays';
  assert (select v->>'error' from er where k = 'gleam') = 'shop_boosted', 'shop boosts are never traded';
  assert (select v->>'error' from er where k = 'fav') = 'favorite', 'favourites stay';
  assert (select v->>'error' from er where k = 'none') = 'no_spirling', 'only own Spirlings';
  assert (select v->>'error' from er where k = 'all') = 'last_one', 'the team keeps one Spirling';
  assert (select v->>'error' from er where k = 'four') = 'too_many_spirlings', 'at most 3';
  assert (select v->>'error' from er where k = 'stale') = 'sync_first', 'the device must know the save';
  assert (select v from er where k = 'put1')->'took' = '["a1"]', 'a1 left the save: ' || (select v::text from er where k = 'put1');
  assert ((select v from er where k = 'put1')->>'rev')::int = 2, 'new revision';
  assert (select v from er where k = 'list2')->'trades'->0->'theirs_mons'->0->>'uid' = 'a1', 'e2 sees a1';
  assert (select v from er where k = 'list2')->'trades'->0->'theirs_mons'->0->>'nickname' is null, 'no nickname travels';
  assert (select v->>'error' from er where k = 'old_confirm') = 'changed', 'an old build cannot confirm unseen Spirlings';
  assert (select v->>'error' from er where k = 'blind') = 'changed', 'the other side''s Spirlings must match';
  assert not ((select v from er where k = 'ok1')->>'done')::boolean, 'one side confirmed';
  assert ((select v from er where k = 'ok2')->>'done')::boolean, 'both confirmed';
  assert (select v from er where k = 'get2')->'mons'->0->>'uid' = 'a1', 'e2 gets a1';
  assert (select v from er where k = 'get1')->'mons'->0->>'uid' = 'b2', 'e1 gets b2';
  assert (select x->>'origin_era' from jsonb_array_elements(e2->'storage') x where x->>'uid' = 'a1') = '2', 'origin era kept';
  assert (select x->>'level' from jsonb_array_elements(e2->'storage') x where x->>'uid' = 'a1') = '12', 'values kept';
  assert (select x ? 'box' from jsonb_array_elements(e2->'storage') x where x->>'uid' = 'a1') = false, 'no box';
  assert (select x->>'origin_era' from jsonb_array_elements(e1->'storage') x where x->>'uid' = 'b2') = '1', 'older saves count as era 1';
  assert jsonb_array_length(e1->'party') = 1 and e1->'party'->0->>'uid' = 'a2', 'e1 team';
  assert not exists (select 1 from jsonb_array_elements(e2->'party') x where x->>'uid' = 'b2')
    and not exists (select 1 from jsonb_array_elements(e2->'storage') x where x->>'uid' = 'b2'), 'b2 left e2';
end $$;

-- A cancelled trade gives the Spirling back; with the flag off nothing moves.
set role authenticated;
select pg_temp.as_user('e1');
insert into er values ('open2', public.trade_open((select code from ec where who = 'e2')));
insert into er values ('put3', public.trade_put_spirlings(((select v from er where k = 'open2')->>'trade')::bigint, 1, 3, array['b2']));
insert into er values ('cancel', public.trade_cancel(((select v from er where k = 'open2')->>'trade')::bigint));
insert into er values ('back', public.trade_collect(((select v from er where k = 'open2')->>'trade')::bigint, 1, 4));
reset role;
update public.feature_flags set enabled = false where key = 'trade_spirling';
set role authenticated;
select pg_temp.as_user('e1');
insert into er values ('open3', public.trade_open((select code from ec where who = 'e2')));
insert into er values ('off', public.trade_put_spirlings(((select v from er where k = 'open3')->>'trade')::bigint, 1, 5, array['b2']));
reset role;
update public.feature_flags set enabled = true where key = 'trade_spirling';

do $$
begin
  assert (select v from er where k = 'put3')->'took' = '["b2"]', 'put3';
  assert (select v from er where k = 'back')->'mons'->0->>'uid' = 'b2', 'own Spirling back';
  assert exists (select 1 from public.saves s, jsonb_array_elements(s.data->'storage') x
    where s.user_id = '20000000-0000-0000-0000-0000000000e1' and x->>'uid' = 'b2'), 'b2 is home again';
  assert (select v->>'error' from er where k = 'off') = 'feature_off', 'flag off';
end $$;

-- Weekly Rift board: only won battles of known Rifts, and only once the referee said ok.
set role authenticated;
select pg_temp.as_user('e1');
insert into er values ('r_bad', public.battle_submit('rift', 'nowhere', '{"teams": []}', '{"winner": "player", "rounds": 7}'));
insert into er values ('r_lost', public.battle_submit('rift', 'cinder', '{"teams": []}', '{"winner": "foe", "rounds": 7}'));
insert into er values ('r1', public.battle_submit('rift', 'cinder', '{"teams": []}', '{"winner": "player", "rounds": 7}'));
insert into er values ('r1b', public.battle_submit('rift', 'cinder', '{"teams": []}', '{"winner": "player", "rounds": 9}'));
select pg_temp.as_user('e2');
insert into er values ('r2', public.battle_submit('rift', 'cinder', '{"teams": []}', '{"winner": "player", "rounds": 5}'));
insert into er values ('r2b', public.battle_submit('rift', 'cinder', '{"teams": []}', '{"winner": "player", "rounds": 8}'));
insert into er values ('board_pending', public.rift_board('cinder', true));
reset role;
insert into public.battle_results (battle_id, verdict) values
  (((select v from er where k = 'r1')->>'battle_id')::bigint, 'ok'),
  (((select v from er where k = 'r1b')->>'battle_id')::bigint, 'ok'),
  (((select v from er where k = 'r2')->>'battle_id')::bigint, 'mismatch'),
  (((select v from er where k = 'r2b')->>'battle_id')::bigint, 'ok');
set role authenticated;
select pg_temp.as_user('e2');
insert into er values ('board_f', public.rift_board('cinder', true));
select pg_temp.as_user('e3');
insert into er values ('board_w', public.rift_board('cinder', false));
insert into er values ('board_e3f', public.rift_board('cinder', true));
reset role;

do $$
begin
  assert (select v->>'error' from er where k = 'r_bad') = 'no_such_rift', 'unknown Rift';
  assert (select v->>'error' from er where k = 'r_lost') = 'bad_battle', 'only wins';
  assert jsonb_array_length((select v from er where k = 'board_pending')->'rows') = 0, 'nothing before the referee';
  assert (select v from er where k = 'board_f')->'rows' =
    ('[{"rank": 1, "score": 7, "me": false, "name": "' || (select name from public.profiles where id = '20000000-0000-0000-0000-0000000000e1') ||
    '"}, {"rank": 2, "score": 8, "me": true, "name": "' || (select name from public.profiles where id = '20000000-0000-0000-0000-0000000000e2') || '"}]')::jsonb,
    'best checked run per player, fewest rounds first: ' || (select v::text from er where k = 'board_f');
  assert (select v from er where k = 'board_w')->'rows'->0->>'name' = '', 'strangers have no name';
  assert jsonb_array_length((select v from er where k = 'board_w')->'rows') = 2, 'world board';
  assert jsonb_array_length((select v from er where k = 'board_e3f')->'rows') = 0, 'friends board of a player without friends';
end $$;

-- Weekly league board: rated wins of this week only.
insert into public.league_matches (league, season, user_id, seed, teams, state, rated, score, created_at)
select 'fair', (public._league_season()).id, u::uuid, 1, '[]', st, rt, sc, at
from (values
  ('20000000-0000-0000-0000-0000000000e1', 'done', true, 1.0, now()),
  ('20000000-0000-0000-0000-0000000000e1', 'done', true, 1.0, now()),
  ('20000000-0000-0000-0000-0000000000e1', 'done', true, 0.0, now()),
  ('20000000-0000-0000-0000-0000000000e2', 'done', true, 1.0, now()),
  ('20000000-0000-0000-0000-0000000000e2', 'done', false, 1.0, now()),
  ('20000000-0000-0000-0000-0000000000e2', 'done', true, 1.0, now() - interval '8 days'),
  ('20000000-0000-0000-0000-0000000000e2', 'submitted', true, null, now())) v(u, st, rt, sc, at);
set role authenticated;
select pg_temp.as_user('e2');
insert into er values ('lb', public.league_board('fair', true));
insert into er values ('lb_bad', public.league_board('gold', true));
reset role;

do $$
begin
  assert (select v from er where k = 'lb')->'rows'->0->>'score' = '2', 'e1 has two wins: ' || (select v::text from er where k = 'lb');
  assert (select v from er where k = 'lb')->'rows'->1->>'score' = '1', 'e2: one rated win this week';
  assert ((select v from er where k = 'lb')->'rows'->1->>'me')::boolean, 'e2 is me';
  assert (select v->>'error' from er where k = 'lb_bad') = 'bad_league', 'bad league';
end $$;

-- Daily online gift: once per server day, rolled by the server into the stored save.
update public.feature_flags set enabled = false where key = 'daily_gift';
set role authenticated;
select pg_temp.as_user('e2');
insert into er values ('g_off', public.daily_gift_claim(1, 3));
reset role;
update public.feature_flags set enabled = true where key = 'daily_gift';
set role authenticated;
select pg_temp.as_user('e2');
insert into er values ('g_state', public.daily_gift_state());
insert into er values ('g_stale', public.daily_gift_claim(1, 1));
insert into er values ('g1', public.daily_gift_claim(1, 3));
insert into er values ('g2', public.daily_gift_claim(1, 4));
insert into er values ('g_state2', public.daily_gift_state());
reset role;

do $$
declare it text := (select v->>'item' from er where k = 'g1');
begin
  assert (select v->>'error' from er where k = 'g_off') = 'feature_off', 'flag';
  assert ((select v from er where k = 'g_state')->>'ready')::boolean, 'ready';
  assert (select v->>'error' from er where k = 'g_stale') = 'sync_first', 'stale revision: ' || (select v::text from er where k = 'g_stale');
  assert ((select v from er where k = 'g1')->>'ok')::boolean, 'claimed: ' || (select v::text from er where k = 'g1');
  assert exists (select 1 from jsonb_array_elements(public._config('daily_gift_table')) x where x->>'item' = it), 'from the open table';
  assert (select (data->'inventory'->>it)::int from public.saves where user_id = '20000000-0000-0000-0000-0000000000e2' and slot = 1) >= 1,
    'in the stored bag';
  assert (select v->>'error' from er where k = 'g2') = 'already_today', 'once a day';
  assert not ((select v from er where k = 'g_state2')->>'ready')::boolean, 'not ready again today';
end $$;

-- Leave the flags as the later tests expect them (all off).
update public.feature_flags set enabled = false where key in ('trade', 'trade_spirling', 'rift_board', 'league_board', 'daily_gift');
