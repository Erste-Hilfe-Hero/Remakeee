-- Rate limit for shop_buy (plan item 4148): at most 30 Riftglass purchases per hour and account.
-- Receipt checks (20 per hour) are limited in server/billing/billing.py.
create or replace function public.shop_buy(p_offer text, p_expected_price int, p_choice text default null) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  o jsonb;
  price int;
  bal int;
  why text;
  cap int;
  pid bigint;
begin
  select data into o from public.shop_offers where id = p_offer;
  if o is null then return jsonb_build_object('ok', false, 'error', 'unknown_offer'); end if;
  price := coalesce((o->>'rg_price')::int, 0);
  if price <= 0 then return jsonb_build_object('ok', false, 'error', 'not_for_riftglass'); end if;
  if price <> p_expected_price then return jsonb_build_object('ok', false, 'error', 'price_changed', 'price', price); end if;
  -- Item 4148: at most 30 Riftglass purchases per hour and account.
  if (select count(*) from public.purchases
      where user_id = u and store = 'riftglass' and at > now() - interval '1 hour') >= 30 then
    return jsonb_build_object('ok', false, 'error', 'slow_down');
  end if;
  insert into public.wallets (user_id) values (u) on conflict do nothing;
  select balance into bal from public.wallets where user_id = u for update;
  why := public._shop_offer_block(u, o, p_choice);
  if why is not null then return jsonb_build_object('ok', false, 'error', why); end if;
  cap := public._shop_cap(u);
  if bal < 0 or public._shop_spent(u) > cap then
    return jsonb_build_object('ok', false, 'error', 'limit_reached');
  end if;
  if bal < price then return jsonb_build_object('ok', false, 'error', 'not_enough', 'balance', bal); end if;
  insert into public.purchases (user_id, store, offer_id, rg_spent, choice)
  values (u, 'riftglass', p_offer, price, p_choice) returning id into pid;
  bal := public._shop_ledger_add(u, -price, 'spend', 'purchase:' || pid);
  perform public._shop_grant(u, pid, o, p_choice);
  return jsonb_build_object('ok', true, 'balance', bal, 'purchase', pid);
end $$;
