-- Pay-to-win step 8 (release 1.3.2, Ali 27 Nov 2026, docs/MONETIZATION.md "Schritt 8"): more advantages.
-- The new offers come with the catalog (20261127100000_shop_offers_v040.sql). The only server rule that
-- changes: Crit Seal IV and V, so the referee gets up to 5 Crit Seal tiers. Everything else of step 8 is
-- story only (Victory Mend, Coin Seal, Wild Purse, Gleam Lens, Rarity Compass, Training Seal, Kinship
-- Bell, Bond Head Start IV-V, Merchant Discount II, Growth Seal II): the server only counts entitlements.
-- The Fair League keeps zeros (_league_expect). Re-runnable.

create or replace function public._shop_amulets(p_uid uuid) returns jsonb
language sql stable as $$
  select jsonb_build_array(
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'crit_seal'), 0), 5),
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'status_ward'), 0), 1),
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'start_shield'), 0), 1))
$$;

revoke all on function public._shop_amulets(uuid) from public, anon, authenticated, chimora_referee;
