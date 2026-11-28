-- Online 100, area 5 (points 41-50): trade limit per day and history, wish list, two gifts a day
-- from friendship level 3, greeting cards with a Spirling motif, thanks for a gift, lending.
-- The same cases as tests/unit/test_trade_gifts.gd.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-000000000091'), ('20000000-0000-0000-0000-000000000092'),
  ('20000000-0000-0000-0000-000000000093')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000' || u, false)
$$;
create temp table gc (who text primary key, code text);
create temp table gr (k text primary key, v jsonb);
grant all on gc, gr to authenticated;
update public.feature_flags set enabled = true where key in ('trade', 'lend');
update public.server_config set value = jsonb_set(value, '{trades_per_day}', '1') where key = 'trade_gifts';

set role authenticated;
select pg_temp.as_user('91');
insert into gc values ('91', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('92');
insert into gc values ('92', public.hello(1)->'profile'->>'code');
select public.friend_request((select code from gc where who = '91'));
select pg_temp.as_user('93');
insert into gc values ('93', public.hello(1)->'profile'->>'code');
select public.friend_request((select code from gc where who = '91'));
select pg_temp.as_user('91');
select public.friend_respond((select code from gc where who = '92'), true);
select public.friend_respond((select code from gc where who = '93'), true);
reset role;
insert into public.saves (user_id, slot, rev, data) values
  ('20000000-0000-0000-0000-000000000091', 1, 4, '{"inventory": {"tonic": 5, "remedy": 3},
    "party": [{"uid": "m1", "species": "Kindlop", "level": 12, "nickname": "Bob", "held": "keen_lens", "origin_era": 2},
              {"uid": "m2", "species": "Zippit", "level": 9, "gleam": true}],
    "storage": [{"uid": "m3", "species": "Mossling", "level": 5}]}'),
  ('20000000-0000-0000-0000-000000000092', 2, 9, '{"inventory": {"remedy": 4}}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;

-- 47: one gift a day below friendship level 3, two from level 3. Wish list (46).
set role authenticated;
select pg_temp.as_user('91');
insert into gr values ('g1', public.gift_send((select code from gc where who = '92')));
insert into gr values ('g2', public.gift_send((select code from gc where who = '92')));
select pg_temp.as_user('92');
insert into gr values ('wish_bad', public.wish_set('["grapple_line"]'));
insert into gr values ('wish_many', public.wish_set('["tonic", "remedy", "spark_drop", "keen_lens"]'));
insert into gr values ('wish_twice', public.wish_set('["tonic", "tonic"]'));
insert into gr values ('wish', public.wish_set('["tonic", "keen_lens"]'));
reset role;
update public.friendships set points = 30, accepted_at = now() - interval '8 days'
where a = '20000000-0000-0000-0000-000000000091' and b = '20000000-0000-0000-0000-000000000092';
set role authenticated;
select pg_temp.as_user('91');
insert into gr values ('g3', public.gift_send((select code from gc where who = '92')));
insert into gr values ('g4', public.gift_send((select code from gc where who = '92')));
insert into gr values ('list', public.friends_list());
reset role;

do $$
declare f jsonb;
begin
  assert (select v->>'left' from gr where k = 'g1') = '0', 'level 1: one gift ' || (select v::text from gr where k = 'g1');
  assert (select v->>'error' from gr where k = 'g2') = 'already_today', 'level 1: no second gift';
  assert (select v->>'error' from gr where k = 'wish_bad') = 'bad_wish', 'gear is no wish';
  assert (select v->>'error' from gr where k = 'wish_many') = 'bad_wish', 'three wishes at most';
  assert (select v->>'error' from gr where k = 'wish_twice') = 'bad_wish', 'no wish twice';
  assert (select v->'wishes' from gr where k = 'wish') = '["tonic", "keen_lens"]', 'wishes are kept in order';
  assert (select v->>'ok' from gr where k = 'g3') = 'true', 'level 3: a second gift';
  assert (select v->>'error' from gr where k = 'g4') = 'already_today', 'level 3: two at most';
  select x into f from gr, jsonb_array_elements(v->'friends') x where k = 'list' and x->>'code' = (select code from gc where who = '92');
  assert f->'wishes' = '["tonic", "keen_lens"]', 'friends see the wish list';
  assert (f->>'gifts_left')::int = 0 and (f->>'gift_sent')::boolean, 'nothing left today';
  select x into f from gr, jsonb_array_elements(v->'friends') x where k = 'list' and x->>'code' = (select code from gc where who = '93');
  assert (f->>'gifts_left')::int = 1, 'one gift left for a new friend ';
end $$;

-- 48: greeting cards with a Spirling from the sender's journey. 49: thanks for a gift.
set role authenticated;
select pg_temp.as_user('91');
insert into gr values ('card_unseen', public.card_send((select code from gc where who = '92'), 'Voidmaw', 1));
insert into gr values ('card_phrase', public.card_send((select code from gc where who = '92'), 'Mossling', 31));
insert into gr values ('card_stranger', public.card_send('ZZZZZZZZ', 'Mossling', 1));
insert into gr values ('card', public.card_send((select code from gc where who = '92'), 'Mossling', 1));
select pg_temp.as_user('92');
insert into gr values ('mail', public.mail_list());
insert into gr values ('thank_closed', public.gift_thank((select (x->>'id')::bigint from gr, jsonb_array_elements(v) x
  where k = 'mail' and x->>'kind' = 'gift' order by (x->>'id')::bigint limit 1)));
select public.gift_open((select (x->>'id')::bigint from gr, jsonb_array_elements(v) x
  where k = 'mail' and x->>'kind' = 'gift' order by (x->>'id')::bigint limit 1));
insert into gr values ('thank', public.gift_thank((select (x->>'id')::bigint from gr, jsonb_array_elements(v) x
  where k = 'mail' and x->>'kind' = 'gift' order by (x->>'id')::bigint limit 1)));
insert into gr values ('thank_again', public.gift_thank((select (x->>'id')::bigint from gr, jsonb_array_elements(v) x
  where k = 'mail' and x->>'kind' = 'gift' order by (x->>'id')::bigint limit 1)));
insert into gr values ('mail2', public.mail_list());
reset role;

do $$
begin
  assert (select v->>'error' from gr where k = 'card_unseen') = 'no_species', 'only Spirlings of the own journey';
  assert (select v->>'error' from gr where k = 'card_phrase') = 'bad_phrase', 'only set phrases of Lantern Mail';
  assert (select v->>'error' from gr where k = 'card_stranger') = 'not_friends', 'friends only';
  assert (select count(*) from gr, jsonb_array_elements(v) x where k = 'mail' and x->>'kind' = 'card'
    and x->>'species' = 'Mossling' and x->>'phrase' = '1') = 1, 'the card arrives with its motif';
  assert (select v->>'error' from gr where k = 'thank_closed') = 'open_first', 'open the gift first';
  assert (select (v->>'points')::int from gr where k = 'thank') = 2, 'thanks bring 2 points';
  assert (select v->>'error' from gr where k = 'thank_again') = 'already', 'once per gift';
  assert (select count(*) from gr, jsonb_array_elements(v) x where k = 'mail2' and (x->>'thanked')::boolean) = 1, 'shown as thanked';
  assert (select points from public.friendships where a = '20000000-0000-0000-0000-000000000091'
    and b = '20000000-0000-0000-0000-000000000092') = 33, 'gift point plus 2 thanks points';
  assert exists (select 1 from public.mail where sender = '20000000-0000-0000-0000-000000000092'
    and recipient = '20000000-0000-0000-0000-000000000091' and kind = 'thanks'), 'the friend gets a thanks note';
end $$;

-- 42 and 50: one finished trade a day (limit set to 1 above), the history shows it.
set role authenticated;
select pg_temp.as_user('91');
insert into gr values ('t1', public.trade_open((select code from gc where who = '92')));
select public.trade_put(((select v from gr where k = 't1')->>'trade')::bigint, 1, 4, '{"tonic": 2}');
select pg_temp.as_user('92');
select public.trade_put(((select v from gr where k = 't1')->>'trade')::bigint, 2, 9, '{"remedy": 1}');
select public.trade_confirm(((select v from gr where k = 't1')->>'trade')::bigint, '{"tonic": 2}', '{}'::text[]);
select pg_temp.as_user('91');
insert into gr values ('done1', public.trade_confirm(((select v from gr where k = 't1')->>'trade')::bigint, '{"remedy": 1}', '{}'::text[]));
select public.trade_collect(((select v from gr where k = 't1')->>'trade')::bigint, 1, 5);
insert into gr values ('t2', public.trade_open((select code from gc where who = '92')));
select public.trade_put(((select v from gr where k = 't2')->>'trade')::bigint, 1, 6, '{"tonic": 1}');
insert into gr values ('limit', public.trade_confirm(((select v from gr where k = 't2')->>'trade')::bigint, '{}', '{}'::text[]));
insert into gr values ('hist', public.trade_history());
select pg_temp.as_user('92');
insert into gr values ('hist2', public.trade_history());
reset role;

do $$
begin
  assert (select (v->>'done')::boolean from gr where k = 'done1'), 'first trade finishes';
  assert (select v->>'error' from gr where k = 'limit') = 'day_limit', 'second trade waits for tomorrow';
  assert (select jsonb_array_length(v->'rows') from gr where k = 'hist') = 1, 'one row in the history';
  assert (select v->'rows'->0->'gave' from gr where k = 'hist') = '{"tonic": 2}', 'what I gave';
  assert (select v->'rows'->0->'got' from gr where k = 'hist') = '{"remedy": 1}', 'what I got';
  assert (select v->'rows'->0->>'name' from gr where k = 'hist2') is not null, 'the partner is named';
  assert (select v->'rows'->0->'gave' from gr where k = 'hist2') = '{"remedy": 1}', 'the other side sees its own view';
  assert (select (v->>'today')::int from gr where k = 'hist') = 1, 'today counted';
end $$;
-- Rows older than 30 days go.
update public.trade_log set done_at = now() - interval '31 days' where user_id = '20000000-0000-0000-0000-000000000091';
set role authenticated;
select pg_temp.as_user('91');
insert into gr values ('hist_old', public.trade_history());
reset role;
do $$
begin
  assert (select jsonb_array_length(v->'rows') from gr where k = 'hist_old') = 0, 'history keeps 30 days';
end $$;

-- 45: lending a copy of a Spirling for one raid or one live duel.
set role authenticated;
select pg_temp.as_user('91');
insert into gr values ('lend_low', public.lend_offer((select code from gc where who = '93'), 1, 'm3'));
insert into gr values ('lend_gleam', public.lend_offer((select code from gc where who = '92'), 1, 'm2'));
insert into gr values ('lend_none', public.lend_offer((select code from gc where who = '92'), 1, 'zz'));
insert into gr values ('lend', public.lend_offer((select code from gc where who = '92'), 1, 'm1'));
insert into gr values ('lend_twice', public.lend_offer((select code from gc where who = '92'), 1, 'm3'));
select pg_temp.as_user('92');
insert into gr values ('lend_list', public.lend_list());
insert into gr values ('use_bad', public.lend_use(((select v from gr where k = 'lend')->>'loan')::bigint, 'league'));
insert into gr values ('use', public.lend_use(((select v from gr where k = 'lend')->>'loan')::bigint, 'raid'));
insert into gr values ('use_again', public.lend_use(((select v from gr where k = 'lend')->>'loan')::bigint, 'raid'));
insert into gr values ('end_used', public.lend_end(((select v from gr where k = 'lend')->>'loan')::bigint));
reset role;

do $$
declare m jsonb;
begin
  assert (select v->>'error' from gr where k = 'lend_low') = 'friend_level', 'lending from friendship level 3';
  assert (select v->>'error' from gr where k = 'lend_gleam') = 'shop_boosted', 'shop boosts are never lent';
  assert (select v->>'error' from gr where k = 'lend_none') = 'no_spirling', 'only own Spirlings';
  assert (select (v->>'ok')::boolean from gr where k = 'lend'), 'lent: ' || (select v::text from gr where k = 'lend');
  assert (select v->>'error' from gr where k = 'lend_twice') = 'friend_has_one', 'a friend holds one loan at a time';
  m := (select v->'borrowed'->0->'mon' from gr where k = 'lend_list');
  assert m->>'species' = 'Kindlop' and (m->>'level')::int = 12, 'the copy keeps species and Ring';
  assert not m ? 'nickname' and not m ? 'held', 'no nickname and no Keepsake travel';
  assert (select v->>'error' from gr where k = 'use_bad') = 'bad_kind', 'only raids and live duels';
  assert (select v->'mon'->>'species' from gr where k = 'use') = 'Kindlop', 'the borrower gets the copy';
  assert (select v->>'error' from gr where k = 'use_again') = 'used', 'one battle only';
  assert (select v->>'error' from gr where k = 'end_used') = 'no_such_loan', 'a used loan cannot be ended';
  assert (select jsonb_array_length(data->'party') from public.saves
    where user_id = '20000000-0000-0000-0000-000000000091' and slot = 1) = 2, 'the original stays with the lender';
end $$;
reset role;
update public.spirling_loans set ends_at = now() - interval '1 second';
set role authenticated;
select pg_temp.as_user('92');
insert into gr values ('lend_after', public.lend_list());
reset role;
do $$
begin
  assert (select jsonb_array_length(v->'borrowed') from gr where k = 'lend_after') = 0, 'loans end after their time';
end $$;

update public.server_config set value = jsonb_set(value, '{trades_per_day}', '5') where key = 'trade_gifts';
update public.feature_flags set enabled = false where key in ('trade', 'lend');
delete from auth.users where id in ('20000000-0000-0000-0000-000000000091', '20000000-0000-0000-0000-000000000092',
  '20000000-0000-0000-0000-000000000093');
