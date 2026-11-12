-- Pay-to-win step 4 (plan points 16 to 19): Crit Seal I-III, Status Ward, Opening Shield.
-- Each tier offer grants 1 to the unlock crit_seal / status_ward / start_shield, like the seals.
-- The battle values live in data/shop.json (advantage_values); the server hands the tiers to the
-- referee as a second row "amulets" beside "seals": Open League and Raid Rifts get them, the
-- Fair League never does. Tier order is checked by _shop_offer_block ("tier:crit_seal:<n>").

-- Amulet tiers [crit, ward, shield] of an account, clamped to the tiers the catalog sells.
create or replace function public._shop_amulets(p_uid uuid) returns jsonb
language sql stable as $$
  select jsonb_build_array(
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'crit_seal'), 0), 3),
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'status_ward'), 0), 1),
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'start_shield'), 0), 1))
$$;

create or replace function public._league_expect(m public.league_matches) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', m.seed, 'teams', m.teams, 'ai', public._config_int('league_ai', 2),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false,
    'seals', case when m.league = 'open' then public._shop_seals(m.user_id) else '[0, 0, 0]'::jsonb end,
    'amulets', case when m.league = 'open' then public._shop_amulets(m.user_id) else '[0, 0, 0]'::jsonb end)
$$;

create or replace function public._raid_expect(a public.raid_attempts) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', a.seed, 'teams', a.teams, 'ai', public._config_int('league_ai', 2),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false,
    'round_limit', public._config_int('raid_rounds', 10), 'seals', public._shop_seals(a.user_id),
    'amulets', public._shop_amulets(a.user_id))
$$;

revoke all on function public._shop_amulets(uuid), public._league_expect(public.league_matches),
  public._raid_expect(public.raid_attempts)
  from public, anon, authenticated, chimora_referee;
