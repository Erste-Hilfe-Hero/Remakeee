-- Pay-to-win step 8: new tier offers in order, Crit Seal up to V for the referee, never in the Fair League
-- (supabase/migrations/20261127210000_shop_p2w_step8.sql).
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000e8') on conflict do nothing;

do $$
declare
  u uuid := '20000000-0000-0000-0000-0000000000e8';
  m1 jsonb := (select data from public.shop_offers where id = 'rg_victory_mend_1');
  m2 jsonb := (select data from public.shop_offers where id = 'rg_victory_mend_2');
  c4 jsonb := (select data from public.shop_offers where id = 'rg_crit_seal_4');
  g2 jsonb := (select data from public.shop_offers where id = 'rg_growth_plus_2');
  k text;
begin
  assert m1 is not null and m2 is not null and c4 is not null and g2 is not null, 'step 8 offers copied from data/shop.json';
  foreach k in array array['rg_victory_mend_3', 'rg_coin_seal_3', 'rg_wild_purse', 'rg_gleam_lens', 'rg_rare_compass',
      'rg_spark_seal', 'rg_kinship_bell', 'rg_bond_edge_5', 'rg_crit_seal_5', 'rg_merchant_discount_2'] loop
    assert (select value from public.server_config where key = 'league_fair_blocked_sources') ? k,
      'the Fair League blocks ' || k;
  end loop;
  insert into public.spend_limits (user_id, cap_cents) values (u, 10000) on conflict do nothing;
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  assert public._shop_offer_block(u, m2, null) = 'not_yet', 'tier II needs tier I';
  assert public._shop_offer_block(u, m1, null) is null;
  assert public._shop_offer_block(u, c4, null) = 'not_yet', 'Crit Seal IV needs III';
  assert public._shop_offer_block(u, g2, null) = 'not_yet', 'Growth Seal II needs the Growth Seal';
  insert into public.entitlements (user_id, key, count) values (u, 'victory_mend', 1), (u, 'crit_seal', 3), (u, 'growth_plus', 1);
  assert public._shop_offer_block(u, m2, null) is null, 'tier II after tier I';
  assert public._shop_offer_block(u, c4, null) is null, 'tier IV after tier III';
  assert public._shop_offer_block(u, g2, null) is null;
  update public.entitlements set count = 99 where user_id = u and key = 'crit_seal';
  assert public._shop_amulets(u) = '[5, 0, 0]'::jsonb, 'clamped to Crit Seal V';
  assert public._league_expect(jsonb_populate_record(null::public.league_matches,
    jsonb_build_object('league', 'fair', 'user_id', u, 'seed', 1, 'teams', '[]'::jsonb)))->'amulets' = '[0, 0, 0]'::jsonb,
    'never in the Fair League';
  assert public._league_expect(jsonb_populate_record(null::public.league_matches,
    jsonb_build_object('league', 'open', 'user_id', u, 'seed', 1, 'teams', '[]'::jsonb)))->'amulets' = '[5, 0, 0]'::jsonb;
end $$;
