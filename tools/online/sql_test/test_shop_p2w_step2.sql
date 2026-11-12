-- Pay-to-win step 2: the Seal Set only without seal tiers, Spirlings go to deliveries, bought
-- Spirlings never travel (supabase/migrations/20261111120030_shop_p2w_step2.sql).
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000e2') on conflict do nothing;

do $$
declare
  u uuid := '20000000-0000-0000-0000-0000000000e2';
  sset jsonb := (select data from public.shop_offers where id = 'rg_seal_set');
  sp jsonb := (select data from public.shop_offers where id = 'rg_spirling_velahra');
begin
  assert sset is not null and sp is not null, 'step 2 offers copied from data/shop.json';
  insert into public.spend_limits (user_id, cap_cents) values (u, 10000) on conflict do nothing;
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  assert public._shop_offer_block(u, sset, null) is null, 'set without seals';
  perform public._shop_grant(u, null::bigint, sp, null);
  assert (select grants->0->>'t' from public.deliveries where user_id = u order by id desc limit 1) = 'spirling';
  insert into public.entitlements (user_id, key) values (u, 'speed_seal');
  assert public._shop_offer_block(u, sset, null) = 'not_yet', 'no set once a seal tier is owned';
  assert public._trade_mon_why('{"uid": "a", "species": "Velahra", "shop": true}'::jsonb) = 'shop_boosted';
  assert public._trade_mon_why('{"uid": "a", "species": "Velahra"}'::jsonb) is null;
end $$;
