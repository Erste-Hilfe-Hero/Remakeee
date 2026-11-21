-- Pay-to-win step 1 (Ali, 10 Nov 2026): Power, Guard and Pace Seals bought in tiers.
-- Each tier offer grants 1 to the unlock power_seal / guard_seal / speed_seal, so the count is the
-- tier. A tier offer carries "requires": "tier:<unlock>:<n>": the account must own exactly n tiers,
-- so tier n+1 costs only the difference. The battle values live in data/shop.json
-- (advantage_values); the server only hands the tiers to the referee: Open League and Raid Rifts
-- get them, the Fair League never does.

create or replace function public._shop_offer_block(p_uid uuid, o jsonb, p_choice text) returns text
language plpgsql volatile as $$
declare
  band int := public._shop_band_of(p_uid);
  req text := coalesce(o->>'requires', '');
begin
  if not coalesce((public._config('shop_open', 'true'))::text::boolean, true) then return 'shop_closed'; end if;
  if band is null then return 'age_needed'; end if;
  if band < greatest(13, coalesce((o->>'min_band')::int, 13)) then return 'age'; end if;
  if not coalesce((o->>'ready')::boolean, false) then return 'not_available'; end if;
  if o ? 'limit' and public._shop_bought(p_uid, o->>'id', o->'limit'->>'per') >= (o->'limit'->>'n')::int then
    return 'offer_limit';
  end if;
  if req like 'rifts:%' and public._shop_rifts(p_uid) < split_part(req, ':', 2)::int then return 'not_yet'; end if;
  if req like 'tier:%' and coalesce((select count from public.entitlements
      where user_id = p_uid and key = split_part(req, ':', 2)), 0) <> split_part(req, ':', 3)::int then
    return 'not_yet';
  end if;
  if req <> '' and req not like 'rifts:%' and req not like 'tier:%' then return 'not_yet'; end if;
  if o ? 'choice' and (p_choice is null or not (o->'choice') ? p_choice) then return 'choice_needed'; end if;
  return null;
end $$;

-- Seal tiers [power, guard, speed] of an account, clamped to the tiers the catalog sells.
create or replace function public._shop_seals(p_uid uuid) returns jsonb
language sql stable as $$
  select jsonb_build_array(
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'power_seal'), 0), 7),
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'guard_seal'), 0), 7),
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'speed_seal'), 0), 5))
$$;

create or replace function public._league_expect(m public.league_matches) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', m.seed, 'teams', m.teams, 'ai', public._config_int('league_ai', 2),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false,
    'seals', case when m.league = 'open' then public._shop_seals(m.user_id) else '[0, 0, 0]'::jsonb end)
$$;

create or replace function public._raid_expect(a public.raid_attempts) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', a.seed, 'teams', a.teams, 'ai', public._config_int('league_ai', 2),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false,
    'round_limit', public._config_int('raid_rounds', 10), 'seals', public._shop_seals(a.user_id))
$$;

revoke all on function public._shop_seals(uuid), public._shop_offer_block(uuid, jsonb, text),
  public._league_expect(public.league_matches), public._raid_expect(public.raid_attempts)
  from public, anon, authenticated, chimora_referee;
