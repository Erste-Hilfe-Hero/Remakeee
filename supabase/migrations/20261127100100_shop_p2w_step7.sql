-- Pay-to-win step 7 (Ali, 27 Nov 2026, docs/MONETIZATION.md): offers people really want.
-- - Riftglass tiers carry their bonus in the grant (data/shop.json). "first_buy_double": the first
--   purchase of that tier per account adds the base amount once more (ledger reason 'first_double').
--   Counted over every purchase of the tier, refunded ones too, so refund and rebuy never doubles twice.
-- - Monthly Card (grant {"t": "card", "id": "monthly_card", "n": 100, "days": 30}): one store purchase,
--   no subscription. shop_card_daily() pays n Riftglass for every card day up to today; missed days wait.
--   Buying again adds 30 days. A refund removes 30 days that were not paid yet.
-- - Rotating deals ("rotation"): sold only on their weekday or in their week (Berlin calendar, fixed by
--   the date, no chance). Same rule as ShopCatalog.deal_active.
-- - Seal tiers up to Power and Guard X and Pace VII: the referee gets the higher tiers.
-- - shop_extras(): what the shop screen needs on top of shop_state (first purchases, card, deals).
-- Re-runnable.

create table if not exists public.shop_cards (
  user_id uuid not null references auth.users (id) on delete cascade,
  card_id text not null,
  -- Card day 1 is started_on; days_total days in all (30 per purchase); days_paid of them paid.
  started_on date not null,
  days_total int not null check (days_total >= 0),
  days_paid int not null default 0 check (days_paid >= 0),
  daily int not null check (daily > 0),
  primary key (user_id, card_id)
);
alter table public.shop_cards enable row level security;
revoke all on public.shop_cards from anon, authenticated;

-- Moving to a new phone: the card follows the profile like the other shop rows.
create or replace function public._shop_cards_follow() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id = old.id then return new; end if;
  delete from public.shop_cards where user_id = new.id and exists (select 1 from public.shop_cards where user_id = old.id);
  update public.shop_cards set user_id = new.id where user_id = old.id;
  return new;
end $$;
drop trigger if exists shop_cards_follow on public.profiles;
create trigger shop_cards_follow after update of id on public.profiles
  for each row execute function public._shop_cards_follow();

-- Shop day number (days since 1 Jan 1970, Berlin calendar), weekday Monday = 0, week from Monday.
create or replace function public._shop_deal_on(r jsonb, d date) returns boolean
language sql immutable as $$
  select case
    when r is null or jsonb_typeof(r) <> 'object' then true
    when r->>'per' = 'day' then mod((d - date '1970-01-01') + 3, 7) = (r->>'weekday')::int
    when r->>'per' = 'week' then mod(((d - date '1970-01-01') + 3) / 7, greatest(coalesce((r->>'cycle')::int, 1), 1)) = (r->>'index')::int
    else false end
$$;

-- Card days due now: started days up to today, not yet paid.
create or replace function public._shop_card_due(c public.shop_cards, d date) returns int
language sql immutable as $$
  select greatest(least(d - c.started_on + 1, c.days_total) - c.days_paid, 0)
$$;

-- Step 6 rules plus the deal rotation.
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
  if o ? 'rotation' and not public._shop_deal_on(o->'rotation', public._shop_today()) then return 'not_now'; end if;
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

-- Step 2 grant plus the Monthly Card and the first purchase double.
create or replace function public._shop_grant(p_uid uuid, p_purchase bigint, o jsonb, p_choice text) returns void
language plpgsql volatile as $$
declare
  g jsonb;
  bag jsonb := '[]'::jsonb;
  today date := public._shop_today();
  c public.shop_cards;
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
      when 'card' then
        select * into c from public.shop_cards where user_id = p_uid and card_id = g->>'id' for update;
        if not found then
          insert into public.shop_cards (user_id, card_id, started_on, days_total, daily)
          values (p_uid, g->>'id', today, (g->>'days')::int, (g->>'n')::int);
        else
          -- A card that ran out starts again today; its unpaid days stay due.
          update public.shop_cards set
            started_on = case when today - c.started_on + 1 > c.days_total then today - c.days_total else c.started_on end,
            days_total = c.days_total + (g->>'days')::int, daily = (g->>'n')::int
          where user_id = p_uid and card_id = c.card_id;
        end if;
      else
        null;
    end case;
  end loop;
  if jsonb_array_length(bag) > 0 then
    insert into public.deliveries (user_id, purchase_id, grants) values (p_uid, p_purchase, bag);
  end if;
  if coalesce((o->>'first_buy_double')::boolean, false) and o->>'kind' = 'currency' then
    perform pg_advisory_xact_lock(hashtext('first_double:' || p_uid::text || ':' || (o->>'id')));
    if not exists (select 1 from public.purchases where user_id = p_uid and offer_id = o->>'id' and id <> p_purchase) then
      perform public._shop_ledger_add(p_uid, (o->>'eur_cents')::int + 1, 'first_double', 'purchase:' || p_purchase);
    end if;
  end if;
end $$;

-- Step 1 refund plus the first purchase double and the card days.
create or replace function public._shop_refund(p_store text, p_txn text, p_note text default '') returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  p public.purchases;
  o jsonb;
  g jsonb;
  extra int;
begin
  select * into p from public.purchases where store_transaction_id = p_txn and store = p_store for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'unknown_transaction'); end if;
  if p.status = 'refunded' then return jsonb_build_object('ok', true, 'duplicate', true); end if;
  update public.purchases set status = 'refunded' where id = p.id;
  insert into public.refunds (user_id, purchase_id, store, store_transaction_id, eur_cents, note)
  values (p.user_id, p.id, p_store, p_txn, p.eur_cents, left(coalesce(p_note, ''), 200));
  select data into o from public.shop_offers where id = p.offer_id;
  for g in select * from jsonb_array_elements(coalesce(o->'grants', '[]'::jsonb)) loop
    if g->>'t' = 'rg' then
      perform public._shop_ledger_add(p.user_id, -(g->>'n')::int, 'refund', 'purchase:' || p.id);
    elsif g->>'t' = 'unlock' then
      update public.entitlements set count = count - 1 where user_id = p.user_id and key = g->>'id' and count > 1;
      if not found then
        delete from public.entitlements where user_id = p.user_id and key = g->>'id';
      end if;
    elsif g->>'t' = 'card' then
      update public.shop_cards set days_total = greatest(days_total - (g->>'days')::int, days_paid)
        where user_id = p.user_id and card_id = g->>'id';
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

-- Seal tiers [power, guard, speed], clamped to the tiers the catalog sells (X, X, VII).
create or replace function public._shop_seals(p_uid uuid) returns jsonb
language sql stable as $$
  select jsonb_build_array(
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'power_seal'), 0), 10),
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'guard_seal'), 0), 10),
    least(coalesce((select count from public.entitlements where user_id = p_uid and key = 'speed_seal'), 0), 7))
$$;

-- Pays the Monthly Card days that are due (all cards of the account).
create or replace function public.shop_card_daily() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  today date := public._shop_today();
  c public.shop_cards;
  due int;
  added int := 0;
  left_days int := 0;
begin
  if not exists (select 1 from public.shop_cards where user_id = u) then
    return jsonb_build_object('ok', false, 'error', 'no_card');
  end if;
  for c in select * from public.shop_cards where user_id = u for update loop
    due := public._shop_card_due(c, today);
    if due > 0 then
      update public.shop_cards set days_paid = days_paid + due where user_id = u and card_id = c.card_id;
      perform public._shop_ledger_add(u, due * c.daily, 'card_daily', c.card_id || ':' || today);
      added := added + due * c.daily;
    end if;
    left_days := left_days + greatest(c.days_total - c.days_paid - due, 0);
  end loop;
  return jsonb_build_object('ok', true, 'added', added, 'days_left', left_days, 'balance', public._shop_balance(u));
end $$;

-- What the shop screen needs on top of shop_state: how often each first_buy_double tier was bought
-- (for the "first purchase double" tag), the Monthly Card and the deals on sale today.
create or replace function public.shop_extras() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  u uuid := public._uid();
  today date := public._shop_today();
begin
  return jsonb_build_object(
    'firsts', coalesce((select jsonb_object_agg(o.id, (select count(*) from public.purchases p where p.user_id = u and p.offer_id = o.id))
      from public.shop_offers o where coalesce((o.data->>'first_buy_double')::boolean, false)), '{}'::jsonb),
    'card', coalesce((select jsonb_object_agg(c.card_id, jsonb_build_object('daily', c.daily, 'due', public._shop_card_due(c, today),
        'days_left', greatest(c.days_total - c.days_paid - public._shop_card_due(c, today), 0)))
      from public.shop_cards c where c.user_id = u), '{}'::jsonb),
    'deals', coalesce((select jsonb_agg(o.id order by o.id) from public.shop_offers o
      where o.data ? 'rotation' and public._shop_deal_on(o.data->'rotation', today)), '[]'::jsonb),
    'shop_day', today - date '1970-01-01');
end $$;

revoke all on function public._shop_cards_follow(), public._shop_deal_on(jsonb, date),
  public._shop_card_due(public.shop_cards, date), public._shop_offer_block(uuid, jsonb, text),
  public._shop_grant(uuid, bigint, jsonb, text), public._shop_refund(text, text, text), public._shop_seals(uuid)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.shop_card_daily(), public.shop_extras() from public, anon, chimora_referee;
grant execute on function public.shop_card_daily(), public.shop_extras() to authenticated;
