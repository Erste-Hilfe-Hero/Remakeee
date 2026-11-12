-- Online 100, area 5: wish lists, two gifts a day, thanks bonus, trade history.
insert into auth.users (id) values
  ('55000000-0000-0000-0000-00000000000a'), ('55000000-0000-0000-0000-00000000000b'),
  ('55000000-0000-0000-0000-00000000000c')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '55000000-0000-0000-0000-00000000000' || u, false)
$$;
create temp table gm (k text primary key, v text);
grant all on gm to authenticated;
begin;
set role authenticated;
select pg_temp.as_user('a');
insert into gm values ('a', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('c');
insert into gm values ('c', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('b');
insert into gm values ('b', public.hello(1)->'profile'->>'code');
select public.friend_request((select v from gm where k = 'a'));
select pg_temp.as_user('a');
select public.friend_respond((select v from gm where k = 'b'), true);
do $$
declare b text := (select v from gm where k = 'b');
begin
  assert (public.gift_send(b)->>'ok')::boolean;
  assert public.gift_send(b)->>'error' = 'already_today';
  assert public.wish_set('["tonic", "nothing_real"]')->>'error' = 'bad_wish';
  assert public.wish_set('["tonic", "tonic"]')->>'error' = 'bad_wish';
  assert (public.wish_set('["tonic", "revival_leaf"]')->>'ok')::boolean;
  assert not (public.mail_send(b, 'thanks', 0)->>'bonus')::boolean, 'no gift from b';
end $$;
reset role;
update public.friendships set points = 30 where a = least('55000000-0000-0000-0000-00000000000a'::uuid, '55000000-0000-0000-0000-00000000000b'::uuid);
set role authenticated;
select pg_temp.as_user('a');
do $$
declare b text := (select v from gm where k = 'b');
begin
  assert (public.gift_send(b)->>'ok')::boolean, 'level 3: a second gift';
  assert public.gift_send(b)->>'error' = 'already_today';
end $$;
select pg_temp.as_user('b');
do $$
declare a text := (select v from gm where k = 'a');
begin
  assert (public.mail_send(a, 'thanks', 0)->>'bonus')::boolean;
  assert not (public.mail_send(a, 'thanks', 0)->>'bonus')::boolean, 'once a day';
  assert public.wish_get(a)->'wishes' = '["tonic", "revival_leaf"]'::jsonb;
end $$;
select pg_temp.as_user('c');
do $$ begin
  assert public.wish_get((select v from gm where k = 'a'))->>'error' = 'not_friends';
end $$;
reset role;
do $$ begin
  assert (select points from public.friendships where a = least('55000000-0000-0000-0000-00000000000a'::uuid,
    '55000000-0000-0000-0000-00000000000b'::uuid)) = 32, 'gift +1 and thanks +1';
end $$;
insert into public.trades (id, state, closes_at, done_at) values (900001, 'done', now(), now()), (900002, 'done', now(), now() - interval '31 days');
insert into public.trade_sides (trade_id, user_id, items, mons) values
  (900001, '55000000-0000-0000-0000-00000000000a', '{"tonic": 2}', '[]'),
  (900001, '55000000-0000-0000-0000-00000000000b', '{"remedy": 1}', '[{}]'),
  (900002, '55000000-0000-0000-0000-00000000000a', '{"tonic": 1}', '[]'),
  (900002, '55000000-0000-0000-0000-00000000000b', '{}', '[]');
set role authenticated;
select pg_temp.as_user('a');
do $$
declare h jsonb := public.trade_history()->'trades';
begin
  assert jsonb_array_length(h) = 1 and h->0->'gave' = '{"tonic": 2}'::jsonb and h->0->'got' = '{"remedy": 1}'::jsonb
    and (h->0->>'got_mons')::int = 1, h::text;
end $$;
reset role;
rollback;
