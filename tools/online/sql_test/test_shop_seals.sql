-- Pay-to-win step 1: seal tiers are bought in order and reach the referee only for the Open League
-- and Raid Rifts (supabase/migrations/20261110000027_shop_seals.sql).
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000e1') on conflict do nothing;

do $$
declare
  u uuid := '20000000-0000-0000-0000-0000000000e1';
  t1 jsonb := (select data from public.shop_offers where id = 'rg_power_seal_1');
  t2 jsonb := (select data from public.shop_offers where id = 'rg_power_seal_2');
begin
  assert t1 is not null and t2 is not null, 'seal offers copied from data/shop.json';
  assert (select value from public.server_config where key = 'league_fair_blocked_sources') ? 'rg_power_seal_7',
    'the Fair League blocks the seals';
  insert into public.spend_limits (user_id, cap_cents) values (u, 10000) on conflict do nothing;
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  assert public._shop_offer_block(u, t2, null) = 'not_yet', 'tier II needs tier I';
  assert public._shop_offer_block(u, t1, null) is null;
  insert into public.entitlements (user_id, key) values (u, 'power_seal');
  assert public._shop_offer_block(u, t2, null) is null, 'tier II after tier I';
  assert public._shop_seals(u) = '[1, 0, 0]'::jsonb;
  update public.entitlements set count = 99 where user_id = u and key = 'power_seal';
  assert public._shop_seals(u) = '[7, 0, 0]'::jsonb, 'clamped to the top tier';
  assert public._league_expect(jsonb_populate_record(null::public.league_matches,
    jsonb_build_object('league', 'fair', 'user_id', u, 'seed', 1, 'teams', '[]'::jsonb)))->'seals' = '[0, 0, 0]'::jsonb,
    'never in the Fair League';
  assert public._league_expect(jsonb_populate_record(null::public.league_matches,
    jsonb_build_object('league', 'open', 'user_id', u, 'seed', 1, 'teams', '[]'::jsonb)))->'seals' = '[7, 0, 0]'::jsonb;
  assert public._raid_expect(jsonb_populate_record(null::public.raid_attempts,
    jsonb_build_object('user_id', u, 'seed', 1, 'teams', '[]'::jsonb)))->'seals' = '[7, 0, 0]'::jsonb;
end $$;
