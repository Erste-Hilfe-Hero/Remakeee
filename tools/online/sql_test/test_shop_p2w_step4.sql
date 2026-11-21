-- Pay-to-win step 4: Crit Seal tiers in order, amulets reach the referee only for the Open League
-- and Raid Rifts (supabase/migrations/20261112120040_shop_p2w_step4.sql).
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000e4') on conflict do nothing;

do $$
declare
  u uuid := '20000000-0000-0000-0000-0000000000e4';
  c1 jsonb := (select data from public.shop_offers where id = 'rg_crit_seal_1');
  c2 jsonb := (select data from public.shop_offers where id = 'rg_crit_seal_2');
  ward jsonb := (select data from public.shop_offers where id = 'rg_status_ward');
begin
  assert c1 is not null and c2 is not null and ward is not null, 'step 4 offers copied from data/shop.json';
  assert (select value from public.server_config where key = 'league_fair_blocked_sources') ? 'rg_start_shield',
    'the Fair League blocks the amulets';
  insert into public.spend_limits (user_id, cap_cents) values (u, 10000) on conflict do nothing;
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  assert public._shop_offer_block(u, c2, null) = 'not_yet', 'tier II needs tier I';
  assert public._shop_offer_block(u, c1, null) is null;
  assert public._shop_offer_block(u, ward, null) is null;
  insert into public.entitlements (user_id, key) values (u, 'crit_seal'), (u, 'status_ward');
  assert public._shop_offer_block(u, c2, null) is null, 'tier II after tier I';
  assert public._shop_amulets(u) = '[1, 1, 0]'::jsonb;
  update public.entitlements set count = 99 where user_id = u;
  assert public._shop_amulets(u) = '[3, 1, 0]'::jsonb, 'clamped to the top tier';
  assert public._league_expect(jsonb_populate_record(null::public.league_matches,
    jsonb_build_object('league', 'fair', 'user_id', u, 'seed', 1, 'teams', '[]'::jsonb)))->'amulets' = '[0, 0, 0]'::jsonb,
    'never in the Fair League';
  assert public._league_expect(jsonb_populate_record(null::public.league_matches,
    jsonb_build_object('league', 'open', 'user_id', u, 'seed', 1, 'teams', '[]'::jsonb)))->'amulets' = '[3, 1, 0]'::jsonb;
  assert public._raid_expect(jsonb_populate_record(null::public.raid_attempts,
    jsonb_build_object('user_id', u, 'seed', 1, 'teams', '[]'::jsonb)))->'amulets' = '[3, 1, 0]'::jsonb;
end $$;
