-- Pay-to-win step 2 (Ali, 11 Nov 2026): Spirlings for sale, bond lures, the seal set.
-- - "spirling" grants go to the deliveries bag like items; the game builds the Spirling
--   (ShopEffects.bought_spirling) and marks it "shop": true.
-- - "requires": "none:<unlock>,<unlock>,..." means the account owns none of these unlocks
--   (the Seal Set is sold only to accounts without any seal tier).
-- - A Spirling bought in the shop never travels in a trade.

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
  if req <> '' and req not like 'rifts:%' and req not like 'tier:%' and req not like 'none:%' then return 'not_yet'; end if;
  if o ? 'choice' and (p_choice is null or not (o->'choice') ? p_choice) then return 'choice_needed'; end if;
  return null;
end $$;

create or replace function public._shop_grant(p_uid uuid, p_purchase bigint, o jsonb, p_choice text) returns void
language plpgsql volatile as $$
declare
  g jsonb;
  bag jsonb := '[]'::jsonb;
begin
  for g in select * from jsonb_array_elements(o->'grants') loop
    case g->>'t'
      when 'rg' then
        perform public._shop_ledger_add(p_uid, (g->>'n')::int, 'store', 'purchase:' || p_purchase);
      when 'unlock' then
        insert into public.entitlements (user_id, key) values (p_uid, g->>'id')
        on conflict (user_id, key) do update set count = public.entitlements.count + 1, at = now();
      when 'item', 'coins', 'spirling' then
        bag := bag || jsonb_build_array(g);
      when 'choice' then
        bag := bag || jsonb_build_array(jsonb_build_object('t', 'item', 'id', p_choice, 'n', coalesce((g->>'n')::int, 1)));
      else
        null;
    end case;
  end loop;
  if jsonb_array_length(bag) > 0 then
    insert into public.deliveries (user_id, purchase_id, grants) values (p_uid, p_purchase, bag);
  end if;
end $$;

create or replace function public._trade_mon_why(m jsonb) returns text
language sql immutable as $$
  select case
    when jsonb_typeof(m) <> 'object' or coalesce(m->>'uid', '') = '' or coalesce(m->>'species', '') = '' then 'no_spirling'
    when coalesce(m->>'held', '') <> '' then 'holds_item'
    when public._gleam_boosted(m) or coalesce(m->>'core', 'false') = 'true' or coalesce(m->>'shop', 'false') = 'true'
      or (jsonb_typeof(m->'crystal') = 'object' and m->'crystal' <> '{}'::jsonb) then 'shop_boosted'
    when coalesce(m->>'favorite', 'false') = 'true' then 'favorite'
  end
$$;

revoke all on function public._shop_offer_block(uuid, jsonb, text), public._shop_grant(uuid, bigint, jsonb, text),
  public._trade_mon_why(jsonb)
  from public, anon, authenticated, chimora_referee;
