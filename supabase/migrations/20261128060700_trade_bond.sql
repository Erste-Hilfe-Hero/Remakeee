-- Bond unfurling (1.3.2): some Spirlings unfurl when they bond with a new Wayfarer
-- (scripts/core/TradeBond.gd, unfold rule "bond" in data/spirlings.json). The server decides
-- which Spirling bonded: trade_collect stamps every Spirling handed over in a finished trade with
-- "bond_form" (its species right then) and "bond_item" (the Keepsake it held). Spirlings coming
-- back from an ended trade are the caller's own and get no stamp. A stamp never travels: a
-- traded Spirling leaves without the one from its earlier Wayfarer.
-- A Spirling may keep exactly the Keepsake its own bond path asks for on during a trade
-- (server_config trade_bond_keys, species -> item; tests/unit/test_trade_bond.gd keeps it equal to
-- data/spirlings.json). Those items are all in trade_items, so nothing bought changes hands.
-- Mirrors LocalBackend.trade_mon_why / trade_mon_clean / _fn_trade_collect. Re-runnable.

insert into public.server_config (key, value) values
  ('trade_bond_keys', '{"Brassjack": "spark_coil", "Quenchcoil": "keen_lens", "Snagwhisk": "iron_burr", "Vanecrow": "swift_feather"}')
on conflict (key) do update set value = excluded.value;

create or replace function public._trade_mon_why(m jsonb) returns text
language sql stable as $$
  select case
    when jsonb_typeof(m) <> 'object' or coalesce(m->>'uid', '') = '' or coalesce(m->>'species', '') = '' then 'no_spirling'
    when coalesce(m->>'held', '') <> ''
      and (public._config('trade_bond_keys', '{}'::jsonb)->>(m->>'species')) is distinct from (m->>'held') then 'holds_item'
    when public._gleam_boosted(m) or coalesce(m->>'core', 'false') = 'true' or coalesce(m->>'shop', 'false') = 'true'
      or coalesce(m->>'gift_slot', 'false') = 'true'
      or (jsonb_typeof(m->'crystal') = 'object' and m->'crystal' <> '{}'::jsonb) then 'shop_boosted'
    when coalesce(m->>'favorite', 'false') = 'true' then 'favorite'
  end
$$;

create or replace function public._trade_mon_clean(m jsonb) returns jsonb
language sql immutable as $$
  select (m - 'nickname' - 'box' - 'favorite' - 'gleam_kind' - 'bond_form' - 'bond_item') || jsonb_build_object('origin_era',
    case when coalesce(m->>'origin_era', '') ~ '^[1-5]$' then (m->>'origin_era')::int else 1 end)
    || case when public._gleam_kind(m) is null then '{}'::jsonb
      else jsonb_build_object('gleam_kind', public._gleam_kind(m)) end
$$;

-- The Spirling as the receiver gets it from a finished trade: bonded in its current form.
create or replace function public._trade_mon_bond(m jsonb) returns jsonb
language sql immutable as $$
  select (m - 'bond_form' - 'bond_item') || jsonb_build_object('bond_form', m->>'species')
    || case when coalesce(m->>'held', '') <> '' then jsonb_build_object('bond_item', m->>'held') else '{}'::jsonb end
$$;

-- The trade_collect of online step 1; Spirlings of a finished trade carry the bond stamp.
create or replace function public.trade_collect(p_trade bigint, p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  m public.trade_sides;
  st text;
  mons jsonb;
  r jsonb;
begin
  perform public._trade_tidy();
  select x.* into m from public.trade_sides x join public.trades t on t.id = x.trade_id
  where x.trade_id = p_trade and x.user_id = u and t.state <> 'open' for update of x;
  if not found then return public._fail('no_such_trade'); end if;
  select t.state into st from public.trades t where t.id = p_trade;
  if m.collected then return public._fail('already'); end if;
  mons := coalesce(m.receive_mons, '[]'::jsonb);
  if st = 'done' and jsonb_typeof(mons) = 'array' then
    mons := coalesce((select jsonb_agg(public._trade_mon_bond(x)) from jsonb_array_elements(mons) x), '[]'::jsonb);
  end if;
  r := public._trade_save(u, p_slot, p_rev, coalesce(m.receive, '{}'::jsonb), '{}'::text[], mons);
  if not (r->>'ok')::boolean then return r; end if;
  update public.trade_sides set collected = true where trade_id = p_trade and user_id = u;
  perform public._trade_tidy();
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'bag', coalesce(m.receive, '{}'::jsonb), 'mons', mons);
end $$;

revoke all on function public._trade_mon_why(jsonb), public._trade_mon_clean(jsonb), public._trade_mon_bond(jsonb)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.trade_collect(bigint, int, int) from public, anon, chimora_referee;
grant execute on function public.trade_collect(bigint, int, int) to authenticated;
