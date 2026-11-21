-- Pay-to-win step 6 (plan points 10-14, 27, 30, 31, 33, 35-38, 40, 50, 51, 57, 58, 60).
-- - Seventh Team Place (offer rg_team_slot_7, unlock team_slot_7): the save check allows one more
--   Spirling in the team, so 7 with both bought places. Echo teams stay at the base party_max.
-- - "requires": "max:<unlock>:<n>" means the account owns at most n of the unlock. Single Storage
--   Boxes use it ("max:storage_box:11"), so boxes from them and from the Storage Wing steps
--   together never pass 12 (600 places).
-- - A Spirling with the shop's Second Gift Slot ("gift_slot": true) never travels in a trade.

create or replace function public._party_max(u uuid) returns int
language sql stable security definer set search_path = public as $$
  select public._config_int('party_max', 5)
    + case when u is not null and exists (select 1 from public.entitlements e where e.user_id = u and e.key = 'team_slot_6' and e.count > 0)
      then 1 else 0 end
    + case when u is not null and exists (select 1 from public.entitlements e where e.user_id = u and e.key = 'team_slot_7' and e.count > 0)
      then 1 else 0 end
$$;

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
  if req like 'none:%' and exists (select 1 from public.entitlements
      where user_id = p_uid and count > 0 and key = any (string_to_array(split_part(req, ':', 2), ','))) then
    return 'not_yet';
  end if;
  if req like 'max:%' and coalesce((select count from public.entitlements
      where user_id = p_uid and key = split_part(req, ':', 2)), 0) > split_part(req, ':', 3)::int then
    return 'offer_limit';
  end if;
  if req <> '' and req not like 'rifts:%' and req not like 'tier:%' and req not like 'none:%' and req not like 'max:%' then
    return 'not_yet';
  end if;
  if o ? 'choice' and (p_choice is null or not (o->'choice') ? p_choice) then return 'choice_needed'; end if;
  return null;
end $$;

create or replace function public._trade_mon_why(m jsonb) returns text
language sql immutable as $$
  select case
    when jsonb_typeof(m) <> 'object' or coalesce(m->>'uid', '') = '' or coalesce(m->>'species', '') = '' then 'no_spirling'
    when coalesce(m->>'held', '') <> '' then 'holds_item'
    when public._gleam_boosted(m) or coalesce(m->>'core', 'false') = 'true' or coalesce(m->>'shop', 'false') = 'true'
      or coalesce(m->>'gift_slot', 'false') = 'true'
      or (jsonb_typeof(m->'crystal') = 'object' and m->'crystal' <> '{}'::jsonb) then 'shop_boosted'
    when coalesce(m->>'favorite', 'false') = 'true' then 'favorite'
  end
$$;

revoke all on function public._party_max(uuid) from public, anon, authenticated;
revoke all on function public._shop_offer_block(uuid, jsonb, text), public._trade_mon_why(jsonb)
  from public, anon, authenticated, chimora_referee;
