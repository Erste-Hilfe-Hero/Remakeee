-- 1.3.2 security review findings 3 and 4.
--
-- Refunds: Riftglass a purchase paid out over time is taken back too, like the Riftglass of a pack
-- (shop.sql: taken back even if spent, the balance can go below 0 and then blocks spending):
-- the Monthly Card days already paid of the refunded purchase, and for the Wayfarer Pass the
-- pass_daily Riftglass and the premium pass_track Riftglass taken while it ran. Bag items already
-- claimed stay, as for every other pack.
--
-- Offer limits: the stores sell a consumable as often as asked and a product type cannot change
-- once it is live. A store purchase of an offer that is over its limit (once-per-account packs:
-- Champion Bundle, Starter, Wayfarer Pack, Rift Packs, Comeback; weekly deals; storage boxes) is
-- credited as plain Riftglass for its price instead of the pack again. Rate: the Riftglass tier of
-- the same price (rg_glass_*, e.g. 4.99 -> 600, 9.99 -> 1300, 49.99 -> 7500), else 1 Riftglass
-- per cent plus 1 (the 0.99 -> 100 tier rate, also used by the first purchase double).

create or replace function public._shop_plain_rg(p_eur_cents int) returns int
language sql stable as $$
  select coalesce(
    (select max((o.data->'grants'->0->>'n')::int) from public.shop_offers o
      where o.data->>'kind' = 'currency' and (o.data->>'eur_cents')::int = p_eur_cents
        and jsonb_array_length(o.data->'grants') = 1 and o.data->'grants'->0->>'t' = 'rg'),
    greatest(p_eur_cents, 0) + 1)
$$;

create or replace function public._shop_credit(p_uid uuid, p_store text, p_txn text, p_product text, p_eur_cents int,
    p_choice text default null) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  o jsonb;
  pid bigint;
  prev public.purchases;
  why text;
  over boolean;
  pick text;
begin
  select * into prev from public.purchases where store_transaction_id = p_txn;
  if found then
    return jsonb_build_object('ok', true, 'duplicate', true, 'purchase', prev.id, 'user', prev.user_id);
  end if;
  select data into o from public.shop_offers where product_id = p_product;
  if o is null then return jsonb_build_object('ok', false, 'error', 'unknown_product'); end if;
  why := public._shop_offer_block(p_uid, o, p_choice);
  -- The store has taken the money: an offer limit or missing choice cannot undo that. Only a wrong
  -- account or a closed age band is refused (the billing service then refunds via the store).
  if why in ('age', 'age_needed') then return jsonb_build_object('ok', false, 'error', why); end if;
  over := coalesce(why = 'offer_limit', false) or (o ? 'limit'
    and public._shop_bought(p_uid, o->>'id', o->'limit'->>'per') >= (o->'limit'->>'n')::int);
  pick := case when o ? 'choice' and (o->'choice') ? p_choice then p_choice else o->'choice'->>0 end;
  insert into public.purchases (user_id, store, store_transaction_id, product_id, offer_id, eur_cents, choice)
  values (p_uid, p_store, p_txn, p_product, o->>'id', greatest(coalesce(p_eur_cents, 0), 0), pick)
  returning id into pid;
  if over then
    perform public._shop_ledger_add(p_uid, public._shop_plain_rg((o->>'eur_cents')::int), 'over_limit', 'purchase:' || pid);
  else
    perform public._shop_grant(p_uid, pid, o, pick);
  end if;
  return jsonb_build_object('ok', true, 'purchase', pid, 'balance', public._shop_balance(p_uid),
    'locked', public._shop_spent(p_uid) > public._shop_cap(p_uid), 'over_limit', over);
end $$;

create or replace function public._shop_refund(p_store text, p_txn text, p_note text default '') returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  p public.purchases;
  o jsonb;
  g jsonb;
  extra int;
  c public.shop_cards;
  cut int;
  s public.subscriptions;
begin
  select * into p from public.purchases where store_transaction_id = p_txn and store = p_store for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'unknown_transaction'); end if;
  if p.status = 'refunded' then return jsonb_build_object('ok', true, 'duplicate', true); end if;
  update public.purchases set status = 'refunded' where id = p.id;
  insert into public.refunds (user_id, purchase_id, store, store_transaction_id, eur_cents, note)
  values (p.user_id, p.id, p_store, p_txn, p.eur_cents, left(coalesce(p_note, ''), 200));
  select data into o from public.shop_offers where id = p.offer_id;
  -- Credited as plain Riftglass (over the offer limit): only that comes back.
  select coalesce(sum(amount), 0)::int into extra from public.ledger
    where user_id = p.user_id and reason = 'over_limit' and ref = 'purchase:' || p.id;
  if extra > 0 then
    o := '{}'::jsonb;
    perform public._shop_ledger_add(p.user_id, -extra, 'refund', 'purchase:' || p.id);
  end if;
  for g in select * from jsonb_array_elements(coalesce(o->'grants', '[]'::jsonb)) loop
    if g->>'t' = 'rg' then
      perform public._shop_ledger_add(p.user_id, -(g->>'n')::int, 'refund', 'purchase:' || p.id);
    elsif g->>'t' = 'unlock' then
      update public.entitlements set count = count - 1 where user_id = p.user_id and key = g->>'id' and count > 1;
      if not found then
        delete from public.entitlements where user_id = p.user_id and key = g->>'id';
      end if;
    elsif g->>'t' = 'card' then
      -- Unpaid days go; the days of this purchase that were already paid come back as Riftglass.
      select * into c from public.shop_cards where user_id = p.user_id and card_id = g->>'id' for update;
      if found then
        cut := least((g->>'days')::int, greatest(c.days_total - c.days_paid, 0));
        update public.shop_cards set days_total = c.days_total - cut where user_id = p.user_id and card_id = c.card_id;
        if (g->>'days')::int > cut then
          perform public._shop_ledger_add(p.user_id, -((g->>'days')::int - cut) * (g->>'n')::int, 'refund', 'purchase:' || p.id);
        end if;
      end if;
    elsif g->>'t' = 'pass' then
      -- The pass Riftglass taken while this pass ran: daily Riftglass and premium track Riftglass.
      select * into s from public.subscriptions where user_id = p.user_id and original_transaction_id = p_txn;
      if found then
        select coalesce(sum(amount), 0)::int into extra from public.ledger
          where user_id = p.user_id and at >= p.at and at <= greatest(s.expires_at, p.at)
            and (reason = 'pass_daily' or (reason = 'pass_track' and ref like 'pass:%:premium'));
        if extra > 0 then
          perform public._shop_ledger_add(p.user_id, -extra, 'refund', 'purchase:' || p.id);
        end if;
      end if;
    end if;
  end loop;
  select coalesce(sum(amount), 0)::int into extra from public.ledger
    where user_id = p.user_id and reason = 'first_double' and ref = 'purchase:' || p.id;
  if extra > 0 then
    perform public._shop_ledger_add(p.user_id, -extra, 'refund', 'purchase:' || p.id);
  end if;
  delete from public.deliveries where purchase_id = p.id and claimed_at is null;
  update public.subscriptions set status = 'revoked', expires_at = least(expires_at, now())
    where user_id = p.user_id and original_transaction_id = p_txn;
  return jsonb_build_object('ok', true, 'balance', public._shop_balance(p.user_id));
end $$;

revoke all on function public._shop_plain_rg(int), public._shop_credit(uuid, text, text, text, int, text),
  public._shop_refund(text, text, text) from public, anon, authenticated, chimora_referee;
