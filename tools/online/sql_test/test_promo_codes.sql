-- Promo codes (20261115100000_promo_codes.sql): once per account, use limit, time window,
-- items into the bag of the stored save. The same cases as tests/unit/test_promo_codes.gd.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-000000000071'), ('20000000-0000-0000-0000-000000000072'),
  ('20000000-0000-0000-0000-000000000073')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000' || u, false)
$$;
create temp table pr (k text primary key, v jsonb);
grant all on pr to authenticated;
insert into public.promo_codes (code, reward, max_uses, ends_at, note) values
  ('DISCORD1', '{"tonic": 3, "revival_leaf": 1}', null, null, 'test'),
  ('ONLYONE1', '{"tonic": 1}', 1, null, 'test'),
  ('OLDCODE1', '{"tonic": 1}', null, now() - interval '1 day', 'test')
on conflict (code) do nothing;
insert into public.promo_codes (code, reward, starts_at, note) values
  ('LATER001', '{"tonic": 1}', now() + interval '1 day', 'test')
on conflict (code) do nothing;
insert into public.saves (user_id, slot, rev, data) values
  ('20000000-0000-0000-0000-000000000071', 1, 4, '{"inventory": {"tonic": 1}}'),
  ('20000000-0000-0000-0000-000000000072', 1, 2, '{"inventory": {}}'),
  ('20000000-0000-0000-0000-000000000073', 1, 1, '{"inventory": {}}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;

set role authenticated;
select pg_temp.as_user('71');
insert into pr values ('stale', public.promo_redeem('DISCORD1', 1, 3));
insert into pr values ('ok', public.promo_redeem('disc-ord1', 1, 4));
insert into pr values ('again', public.promo_redeem('DISCORD1', 1, 5));
insert into pr values ('nope', public.promo_redeem('NOSUCH99', 1, 5));
insert into pr values ('old', public.promo_redeem('OLDCODE1', 1, 5));
insert into pr values ('later', public.promo_redeem('LATER001', 1, 5));
insert into pr values ('one', public.promo_redeem('ONLYONE1', 1, 5));
select pg_temp.as_user('72');
insert into pr values ('one2', public.promo_redeem('ONLYONE1', 1, 2));
insert into pr values ('ok2', public.promo_redeem('DISCORD1', 1, 2));
select pg_temp.as_user('73');
insert into pr values ('noslot', public.promo_redeem('DISCORD1', 2, 0));
reset role;

do $$
begin
  assert (select v->>'error' from pr where k = 'stale') = 'sync_first', 'old save rev';
  assert (select v->>'ok' from pr where k = 'ok') = 'true' and (select v->>'rev' from pr where k = 'ok') = '5', 'redeemed';
  assert (select v->'bag' from pr where k = 'ok') = '{"tonic": 3, "revival_leaf": 1}', 'bag delta';
  assert (select data->'inventory' from public.saves where user_id = '20000000-0000-0000-0000-000000000071' and slot = 1)
    = '{"tonic": 5, "revival_leaf": 1}', 'items in the bag (+1 from ONLYONE1) ' || (select data::text from public.saves where user_id = '20000000-0000-0000-0000-000000000071' and slot = 1);
  assert (select v->>'error' from pr where k = 'again') = 'code_used', 'once per account';
  assert (select v->>'error' from pr where k = 'nope') = 'no_such_code';
  assert (select v->>'error' from pr where k = 'old') = 'code_expired';
  assert (select v->>'error' from pr where k = 'later') = 'no_such_code', 'not started yet';
  assert (select v->>'ok' from pr where k = 'one') = 'true';
  assert (select v->>'error' from pr where k = 'one2') = 'code_used_up', 'use limit';
  assert (select v->>'ok' from pr where k = 'ok2') = 'true', 'others can still redeem';
  assert (select v->>'error' from pr where k = 'noslot') = 'no_save';
  assert (select uses from public.promo_codes where code = 'DISCORD1') = 2, 'uses counted';
  assert (select count(*) from public.promo_redemptions where code = 'DISCORD1') = 2;
end $$;

-- 10 tries an hour against guessing.
set role authenticated;
select pg_temp.as_user('73');
do $$
declare i int; last jsonb;
begin
  for i in 1..10 loop last := public.promo_redeem('GUESS' || lpad(i::text, 3, '0'), 1, 1); end loop;
  assert last->>'error' = 'slow_down', 'rate limit ' || last::text;
end $$;
reset role;

do $$
begin
  assert not has_table_privilege('authenticated', 'public.promo_codes', 'select') or
    not exists (select 1 from pg_policies where tablename = 'promo_codes'), 'codes not readable by players';
end $$;
delete from public.promo_redemptions where code in ('DISCORD1', 'ONLYONE1');
delete from public.promo_codes where note = 'test';
delete from public.rate_events where kind = 'promo';
