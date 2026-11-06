-- Plan area 7, items 2791-2795, 2900: trading through the server as trustee.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000d1'), ('20000000-0000-0000-0000-0000000000d2'),
  ('20000000-0000-0000-0000-0000000000d3')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000' || u, false)
$$;
create temp table tc (who text primary key, code text);
create temp table tr (k text primary key, v jsonb);
grant all on tc, tr to authenticated;
update public.feature_flags set enabled = true where key = 'trade';

set role authenticated;
select pg_temp.as_user('d1');
insert into tc values ('d1', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('d2');
insert into tc values ('d2', public.hello(1)->'profile'->>'code');
select public.friend_request((select code from tc where who = 'd1'));
select pg_temp.as_user('d3');
insert into tc values ('d3', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('d1');
select public.friend_respond((select code from tc where who = 'd2'), true);
insert into tr values ('new', public.trade_open((select code from tc where who = 'd2')));
insert into tr values ('stranger', public.trade_open((select code from tc where who = 'd3')));
reset role;

-- A friendship of level 1 that is new: not yet. Then level 3 and 8 days old.
do $$
begin
  assert (select v->>'error' from tr where k = 'new') = 'friend_level', 'level 3 first: ' || (select v::text from tr where k = 'new');
  assert (select v->>'error' from tr where k = 'stranger') = 'no_such_code', 'friends only';
  assert (select accepted_at from public.friendships where a = least('20000000-0000-0000-0000-0000000000d1'::uuid,
    '20000000-0000-0000-0000-0000000000d2'::uuid)) > now() - interval '1 minute', 'accepted_at is set';
end $$;
update public.friendships set points = 30
where a = least('20000000-0000-0000-0000-0000000000d1'::uuid, '20000000-0000-0000-0000-0000000000d2'::uuid);
set role authenticated;
select pg_temp.as_user('d1');
insert into tr values ('young', public.trade_open((select code from tc where who = 'd2')));
reset role;
update public.friendships set accepted_at = now() - interval '8 days'
where a = least('20000000-0000-0000-0000-0000000000d1'::uuid, '20000000-0000-0000-0000-0000000000d2'::uuid);
insert into public.saves (user_id, slot, rev, data) values
  ('20000000-0000-0000-0000-0000000000d1', 1, 4, '{"inventory": {"tonic": 5, "keen_lens": 1, "grapple_line": 1}}'),
  ('20000000-0000-0000-0000-0000000000d2', 2, 9, '{"inventory": {"remedy": 2}}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;

set role authenticated;
select pg_temp.as_user('d1');
insert into tr values ('open', public.trade_open((select code from tc where who = 'd2')));
insert into tr values ('again', public.trade_open((select code from tc where who = 'd2')));
insert into tr values ('gear', public.trade_put(((select v from tr where k = 'open')->>'trade')::bigint, 1, 4, '{"grapple_line": 1}'));
insert into tr values ('shop', public.trade_put(((select v from tr where k = 'open')->>'trade')::bigint, 1, 4, '{"rg_ring_tonic": 1}'));
insert into tr values ('stale', public.trade_put(((select v from tr where k = 'open')->>'trade')::bigint, 1, 3, '{"tonic": 2}'));
insert into tr values ('much', public.trade_put(((select v from tr where k = 'open')->>'trade')::bigint, 1, 4, '{"tonic": 6}'));
insert into tr values ('put1', public.trade_put(((select v from tr where k = 'open')->>'trade')::bigint, 1, 4, '{"tonic": 3, "keen_lens": 1}'));
select pg_temp.as_user('d2');
insert into tr values ('put2', public.trade_put(((select v from tr where k = 'open')->>'trade')::bigint, 2, 9, '{"remedy": 2}'));
select pg_temp.as_user('d1');
insert into tr values ('ok1', public.trade_confirm(((select v from tr where k = 'open')->>'trade')::bigint, '{"remedy": 2}'));
-- d1 lowers the offer: both confirmations reset (2795), so d2 confirming now only confirms its side.
insert into tr values ('change', public.trade_put(((select v from tr where k = 'open')->>'trade')::bigint, 1, 5, '{"tonic": 1}'));
select pg_temp.as_user('d2');
insert into tr values ('blind', public.trade_confirm(((select v from tr where k = 'open')->>'trade')::bigint, '{"tonic": 3, "keen_lens": 1}'));
insert into tr values ('ok2', public.trade_confirm(((select v from tr where k = 'open')->>'trade')::bigint, '{"tonic": 1}'));
insert into tr values ('list2', public.trade_list());
select pg_temp.as_user('d1');
insert into tr values ('ok1b', public.trade_confirm(((select v from tr where k = 'open')->>'trade')::bigint, '{"remedy": 2}'));
insert into tr values ('late_put', public.trade_put(((select v from tr where k = 'open')->>'trade')::bigint, 1, 6, '{"tonic": 2}'));
insert into tr values ('get1', public.trade_collect(((select v from tr where k = 'open')->>'trade')::bigint, 1, 6));
insert into tr values ('get1b', public.trade_collect(((select v from tr where k = 'open')->>'trade')::bigint, 1, 7));
select pg_temp.as_user('d2');
insert into tr values ('get2', public.trade_collect(((select v from tr where k = 'open')->>'trade')::bigint, 2, 10));
reset role;

do $$
declare tid bigint := ((select v from tr where k = 'open')->>'trade')::bigint;
begin
  assert (select v->>'error' from tr where k = 'young') = 'too_new', '7 days of friendship';
  assert ((select v from tr where k = 'again')->>'trade')::bigint = tid, 'one open trade per pair';
  assert (select v->>'error' from tr where k = 'gear') = 'not_tradeable', 'gear is not tradeable';
  assert (select v->>'error' from tr where k = 'shop') = 'not_tradeable', 'shop items are never tradeable';
  assert (select v->>'error' from tr where k = 'stale') = 'sync_first', 'the device must know the save';
  assert (select v->>'error' from tr where k = 'much') = 'not_enough', 'only what is in the bag';
  assert (select v from tr where k = 'put1')->'bag' = '{"tonic": -3, "keen_lens": -1}', 'left the bag';
  assert ((select v from tr where k = 'change')->>'rev')::int = 6, 'a new revision for each change';
  assert (select v from tr where k = 'change')->'bag' = '{"tonic": 2, "keen_lens": 1}', 'came back';
  assert (select v->>'error' from tr where k = 'blind') = 'changed', 'confirming an old offer fails';
  assert not ((select v from tr where k = 'ok2')->>'done')::boolean, 'd1 has to confirm again';
  assert not ((select v from tr where k = 'list2')->'trades'->0->>'their_ok')::boolean, 'd1 confirmation was reset';
  assert ((select v from tr where k = 'ok1b')->>'done')::boolean, 'both confirmed: done';
  assert (select v->>'error' from tr where k = 'late_put') = 'no_such_trade', 'no change after the trade';
  assert (select v from tr where k = 'get1')->'bag' = '{"remedy": 2}', 'd1 gets the remedies';
  assert (select v->>'error' from tr where k = 'get1b') = 'already', 'only once';
  assert (select v from tr where k = 'get2')->'bag' = '{"tonic": 1}', 'd2 gets the tonic';
  assert (select data->'inventory' from public.saves where user_id = '20000000-0000-0000-0000-0000000000d1' and slot = 1)
    = '{"tonic": 4, "keen_lens": 1, "remedy": 2, "grapple_line": 1}', 'd1 bag';
  assert (select data->'inventory' from public.saves where user_id = '20000000-0000-0000-0000-0000000000d2' and slot = 2)
    = '{"tonic": 1}', 'd2 bag';
  assert not exists (select 1 from public.trades where id = tid), 'a collected trade goes away';
end $$;

-- Blocking ends trading at once (2900); a cancelled trade gives the items back.
set role authenticated;
select pg_temp.as_user('d1');
insert into tr values ('open2', public.trade_open((select code from tc where who = 'd2')));
insert into tr values ('put3', public.trade_put(((select v from tr where k = 'open2')->>'trade')::bigint, 1, 7, '{"tonic": 4}'));
select pg_temp.as_user('d2');
select public.block((select code from tc where who = 'd1'));
insert into tr values ('blocked_put', public.trade_put(((select v from tr where k = 'open2')->>'trade')::bigint, 2, 11, '{"tonic": 1}'));
insert into tr values ('blocked_open', public.trade_open((select code from tc where who = 'd1')));
select pg_temp.as_user('d1');
insert into tr values ('cancel', public.trade_cancel(((select v from tr where k = 'open2')->>'trade')::bigint));
insert into tr values ('back', public.trade_collect(((select v from tr where k = 'open2')->>'trade')::bigint, 1, 8));
reset role;

do $$
begin
  assert (select v->>'error' from tr where k = 'blocked_put') = 'partner_gone', 'no trading with a blocked player';
  assert (select v->>'error' from tr where k = 'blocked_open') = 'no_such_code', 'no new trade either';
  assert ((select v from tr where k = 'cancel')->>'ok')::boolean, 'cancel';
  assert (select v from tr where k = 'back')->'bag' = '{"tonic": 4}', 'own items come back';
  assert (select data->'inventory'->>'tonic' from public.saves where user_id = '20000000-0000-0000-0000-0000000000d1' and slot = 1) = '4', 'bag again';
end $$;
