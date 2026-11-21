-- Promo codes give free bag items only, never what the shop sells (App Store guideline 3.1.1,
-- Chimora 100 pre-check). Until now this rule was only a comment in tools/online/promo_code.sql:
-- promo_redeem now refuses a code whose reward holds an rg_* id or any item a shop offer grants
-- (public.shop_offers, data/shop.json). Such a code looks like an unknown code to the player.
-- LocalBackend does the same (scripts/online/LocalPromo.gd), tests:
-- tools/online/sql_test/test_promo_codes.sql and tests/unit/test_promo_codes.gd. Re-runnable.

-- True when the item id is sold in the shop: an rg_* id, an offer id or an item an offer grants.
create or replace function public._promo_paid_item(p_id text) returns boolean
language sql stable security definer set search_path = public as $$
  select p_id like 'rg\_%'
    or exists (select 1 from public.shop_offers o where o.id = p_id or o.product_id = p_id)
    or exists (select 1 from public.shop_offers o,
      jsonb_array_elements(case when jsonb_typeof(o.data->'grants') = 'array' then o.data->'grants' else '[]'::jsonb end) g
      where g->>'id' = p_id)
$$;

create or replace function public.promo_redeem(p_code text, p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  c text := public._promo_norm(p_code);
  p public.promo_codes;
  k text;
  v jsonb;
  r jsonb;
begin
  if not public._flag_on('promo', 2147483647) then return public._fail('feature_off'); end if;
  -- Against guessing: 10 tries an hour.
  if not public._rate_ok(u, 'promo', 10) then return public._fail('slow_down'); end if;
  select * into p from public.promo_codes where code = c for update;
  if not found or not p.active then return public._fail('no_such_code'); end if;
  if now() < p.starts_at then return public._fail('no_such_code'); end if;
  if p.ends_at is not null and now() >= p.ends_at then return public._fail('code_expired'); end if;
  if exists (select 1 from public.promo_redemptions where code = c and user_id = u) then
    return public._fail('code_used');
  end if;
  if p.max_uses is not null and p.uses >= p.max_uses then return public._fail('code_used_up'); end if;
  for k, v in select * from jsonb_each(p.reward) loop
    if jsonb_typeof(v) <> 'number' or (v #>> '{}')::numeric not between 1 and 999 then
      return public._fail('no_such_code');
    end if;
    -- Free items only: nothing the shop sells (3.1.1).
    if public._promo_paid_item(k) then return public._fail('no_such_code'); end if;
  end loop;
  r := public._trade_save(u, p_slot, p_rev, p.reward, '{}'::text[], '[]'::jsonb);
  if not (r->>'ok')::boolean then return r; end if;
  insert into public.promo_redemptions (code, user_id) values (c, u);
  update public.promo_codes set uses = uses + 1 where code = c;
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'bag', p.reward);
end $$;

revoke all on function public._promo_paid_item(text) from public, anon, authenticated, chimora_referee;
revoke all on function public.promo_redeem(text, int, int) from public, anon, chimora_referee;
grant execute on function public.promo_redeem(text, int, int) to authenticated;
