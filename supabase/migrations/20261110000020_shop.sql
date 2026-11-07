-- Chimora shop (5000-point plan, area 10): Riftglass wallet, ledger, store purchases, unlocks,
-- deliveries to the bag, the Wayfarer Pass, age bands and monthly spending limits, refunds.
-- Rules: docs/MONETIZATION.md and docs/legal/SHOP_COMPLIANCE.md.
--
-- Same security model as the other migrations: tables have row level security without policies
-- and no table rights; players only call the security-definer functions below. Store receipts are
-- checked by the billing service (server/billing), which calls the _shop_credit / _shop_refund /
-- _shop_sub_set functions with the service role. The client never credits anything itself.
--
-- The offers themselves come from data/shop.json (tools/shop/build_offers_sql.py writes them into
-- 20261110000021_shop_offers.sql).

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
end $$;

create table if not exists public.shop_offers (
  id text primary key,
  product_id text not null unique,
  data jsonb not null
);

-- Age band only (items 4247-4253): 0 = under 13, 13 = 13-15, 16 = 16-17, 18 = adult.
-- No birth date is stored, only the day the next band starts.
create table if not exists public.shop_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  age_band smallint not null check (age_band in (0, 13, 16, 18)),
  band_rises_at date,
  -- Seen the note on the right of withdrawal before the first purchase (item 4025).
  withdrawal_ok boolean not null default false,
  created_at timestamptz not null default now()
);

-- Riftglass balance (item 4131). Always the sum of the ledger rows (item 4132). Can go below 0
-- after a refund of Riftglass that was already spent; the shop is locked until it is back at 0.
create table if not exists public.wallets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  balance int not null default 0
);

create table if not exists public.ledger (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount int not null,
  -- 'store' (bought Riftglass), 'spend' (shop_buy), 'pass_daily', 'refund', 'support'
  reason text not null,
  ref text not null default '',
  at timestamptz not null default now()
);
create index if not exists ledger_user on public.ledger (user_id, at);

-- Every purchase: store purchases (apple, google, local test store) and Riftglass purchases.
create table if not exists public.purchases (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  store text not null check (store in ('apple', 'google', 'local', 'riftglass')),
  -- Apple transactionId, Google orderId. Unique, so no receipt is credited twice (item 4128).
  store_transaction_id text unique,
  product_id text not null default '',
  offer_id text not null,
  eur_cents int not null default 0,
  rg_spent int not null default 0,
  choice text,
  status text not null default 'credited' check (status in ('credited', 'refunded')),
  at timestamptz not null default now()
);
create index if not exists purchases_user on public.purchases (user_id, at);

-- Permanent unlocks (team slot, cosmetics, ...). count > 1 for stackable ones (storage +50).
create table if not exists public.entitlements (
  user_id uuid not null references auth.users (id) on delete cascade,
  key text not null,
  count int not null default 1 check (count > 0),
  at timestamptz not null default now(),
  primary key (user_id, key)
);

-- Bag items and coins wait here until the game picks them up with shop_claim() (item 4344).
create table if not exists public.deliveries (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  purchase_id bigint references public.purchases (id) on delete cascade,
  grants jsonb not null,
  claimed_at timestamptz,
  at timestamptz not null default now()
);
create index if not exists deliveries_user on public.deliveries (user_id) where claimed_at is null;

-- Wayfarer Pass (items 4629-4639). Status only comes from the store via the billing service.
create table if not exists public.subscriptions (
  original_transaction_id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  store text not null,
  product_id text not null,
  expires_at timestamptz not null,
  status text not null default 'active',
  auto_renew boolean not null default true,
  -- Last server day the daily 30 Riftglass were paid (item 4631).
  daily_paid_on date,
  updated_at timestamptz not null default now()
);
create index if not exists subscriptions_user on public.subscriptions (user_id);

-- Adults choose their own cap (default 100 EUR). Raising waits 7 days (item 4250).
create table if not exists public.spend_limits (
  user_id uuid primary key references auth.users (id) on delete cascade,
  cap_cents int not null default 10000,
  raise_to_cents int,
  raise_at timestamptz
);

create table if not exists public.refunds (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  purchase_id bigint references public.purchases (id) on delete set null,
  store text not null,
  store_transaction_id text not null,
  eur_cents int not null default 0,
  note text not null default '',
  at timestamptz not null default now()
);

insert into public.server_config (key, value) values
  -- Monthly caps in cent per age band (items 4249, 4250).
  ('shop_caps', '{"13": 1500, "16": 3000, "18": 10000, "18_max": 30000}'),
  -- Riftglass the pass pays per day, and how many missed days are paid later (items 4631, 4637).
  ('shop_pass_daily', '{"rg": 30, "max_days": 7}'),
  -- Set to false to close the shop for everyone (store review, incident).
  ('shop_open', 'true')
on conflict (key) do nothing;

alter table public.shop_offers enable row level security;
alter table public.shop_profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.ledger enable row level security;
alter table public.purchases enable row level security;
alter table public.entitlements enable row level security;
alter table public.deliveries enable row level security;
alter table public.subscriptions enable row level security;
alter table public.spend_limits enable row level security;
alter table public.refunds enable row level security;
revoke all on public.shop_offers, public.shop_profiles, public.wallets, public.ledger, public.purchases,
  public.entitlements, public.deliveries, public.subscriptions, public.spend_limits, public.refunds
  from anon, authenticated;

-- ---------------------------------------------------------------------------------------
-- Helpers (not callable by players)

-- Server calendar (German time): months for the limit, weeks for weekly offer limits.
create or replace function public._shop_today() returns date
language sql stable as $$ select (now() at time zone 'Europe/Berlin')::date $$;

create or replace function public._shop_month_start() returns timestamptz
language sql stable as $$ select (date_trunc('month', now() at time zone 'Europe/Berlin')) at time zone 'Europe/Berlin' $$;

-- Age band for a birth month on [p_today] and the day the next band starts.
create or replace function public._shop_band(p_year int, p_month int, p_today date) returns jsonb
language plpgsql immutable as $$
declare
  born date := make_date(p_year, p_month, 1);
  age int := extract(year from age(p_today, born))::int;
  band int;
  rises date;
begin
  if age < 13 then band := 0; rises := (born + interval '13 years')::date;
  elsif age < 16 then band := 13; rises := (born + interval '16 years')::date;
  elsif age < 18 then band := 16; rises := (born + interval '18 years')::date;
  else band := 18; rises := null;
  end if;
  return jsonb_build_object('band', band, 'rises_at', rises);
end $$;

-- The player's age band, moved up when the day has come (null = not asked yet).
create or replace function public._shop_band_of(p_uid uuid) returns int
language plpgsql volatile as $$
declare sp public.shop_profiles;
begin
  select * into sp from public.shop_profiles where user_id = p_uid for update;
  if not found then return null; end if;
  while sp.band_rises_at is not null and sp.band_rises_at <= public._shop_today() loop
    if sp.age_band = 0 then
      sp.age_band := 13; sp.band_rises_at := (sp.band_rises_at + interval '3 years')::date;
    elsif sp.age_band = 13 then
      sp.age_band := 16; sp.band_rises_at := (sp.band_rises_at + interval '2 years')::date;
    else
      sp.age_band := 18; sp.band_rises_at := null;
    end if;
    update public.shop_profiles set age_band = sp.age_band, band_rises_at = sp.band_rises_at where user_id = p_uid;
  end loop;
  return sp.age_band;
end $$;

-- Monthly cap in cent for the player (0 = shop closed).
create or replace function public._shop_cap(p_uid uuid) returns int
language plpgsql volatile as $$
declare
  band int := public._shop_band_of(p_uid);
  caps jsonb := public._config('shop_caps', '{"13": 1500, "16": 3000, "18": 10000, "18_max": 30000}');
  sl public.spend_limits;
begin
  if band is null or band < 13 then return 0; end if;
  if band < 18 then return (caps->>band::text)::int; end if;
  select * into sl from public.spend_limits where user_id = p_uid for update;
  if not found then return (caps->>'18')::int; end if;
  if sl.raise_to_cents is not null and sl.raise_at <= now() then
    update public.spend_limits set cap_cents = raise_to_cents, raise_to_cents = null, raise_at = null
      where user_id = p_uid returning * into sl;
  end if;
  return sl.cap_cents;
end $$;

-- Money spent in store purchases this calendar month (refunds do not count).
create or replace function public._shop_spent(p_uid uuid) returns int
language sql stable as $$
  select coalesce(sum(eur_cents), 0)::int from public.purchases
  where user_id = p_uid and store <> 'riftglass' and status = 'credited' and at >= public._shop_month_start()
$$;

create or replace function public._shop_balance(p_uid uuid) returns int
language sql stable as $$ select coalesce((select balance from public.wallets where user_id = p_uid), 0) $$;

create or replace function public._shop_ledger_add(p_uid uuid, p_amount int, p_reason text, p_ref text) returns int
language plpgsql volatile as $$
declare b int;
begin
  insert into public.ledger (user_id, amount, reason, ref) values (p_uid, p_amount, p_reason, coalesce(p_ref, ''));
  insert into public.wallets (user_id, balance) values (p_uid, p_amount)
  on conflict (user_id) do update set balance = public.wallets.balance + excluded.balance
  returning balance into b;
  return b;
end $$;

create or replace function public._shop_pass_until(p_uid uuid) returns timestamptz
language sql stable as $$
  select max(expires_at) from public.subscriptions where user_id = p_uid and status in ('active', 'grace')
$$;

-- How often [p_offer] was bought in its limit window (account / week / month).
create or replace function public._shop_bought(p_uid uuid, p_offer text, p_per text) returns int
language sql stable as $$
  select count(*)::int from public.purchases
  where user_id = p_uid and offer_id = p_offer and status = 'credited'
    and at >= case p_per
      when 'week' then (date_trunc('week', now() at time zone 'Europe/Berlin')) at time zone 'Europe/Berlin'
      when 'month' then public._shop_month_start()
      else '-infinity'::timestamptz end
$$;

-- Sealed Rifts in the player's furthest journey (for offers that need them, item 4685).
create or replace function public._shop_rifts(p_uid uuid) returns int
language sql stable as $$
  select coalesce(max(jsonb_array_length(case when jsonb_typeof(data->'rifts') = 'array' then data->'rifts' else '[]'::jsonb end)), 0)::int
  from public.saves where user_id = p_uid
$$;

-- Why [p_offer] cannot be had now, or null. Shared by Riftglass and store purchases.
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
  if req <> '' and req not like 'rifts:%' then return 'not_yet'; end if;
  if o ? 'choice' and (p_choice is null or not (o->'choice') ? p_choice) then return 'choice_needed'; end if;
  return null;
end $$;

-- Hands out what an offer contains: Riftglass to the ledger, unlocks to entitlements, bag items and
-- coins to deliveries, pass days to subscriptions (the store path sets those itself).
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
      when 'item', 'coins' then
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

-- ---------------------------------------------------------------------------------------
-- Player API

-- Everything the shop screen needs: age band, balance, limit, pass, unlocks, offer counts.
create or replace function public.shop_state() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  band int := public._shop_band_of(u);
  cap int := public._shop_cap(u);
  spent int := public._shop_spent(u);
  bal int := public._shop_balance(u);
  until_ts timestamptz := public._shop_pass_until(u);
  sl public.spend_limits;
  bought jsonb;
begin
  select * into sl from public.spend_limits where user_id = u;
  select coalesce(jsonb_object_agg(o.id, public._shop_bought(u, o.id, o.data->'limit'->>'per')), '{}'::jsonb) into bought
    from public.shop_offers o where o.data ? 'limit';
  return jsonb_build_object(
    'open', coalesce((public._config('shop_open', 'true'))::text::boolean, true),
    'band', band,
    'withdrawal_ok', coalesce((select withdrawal_ok from public.shop_profiles where user_id = u), false),
    'balance', bal,
    'cap_cents', cap,
    'spent_cents', spent,
    'locked', bal < 0 or spent > cap,
    'raise_to_cents', sl.raise_to_cents,
    'raise_at', extract(epoch from sl.raise_at)::bigint,
    'pass_until', extract(epoch from until_ts)::bigint,
    'pass_active', until_ts is not null and until_ts > now(),
    'unlocks', coalesce((select jsonb_object_agg(key, count) from public.entitlements where user_id = u), '{}'::jsonb),
    'bought', bought,
    'pending', (select count(*) from public.deliveries where user_id = u and claimed_at is null),
    'rifts', public._shop_rifts(u),
    -- Apple appAccountToken and Google obfuscatedExternalAccountId tie a store purchase to this account.
    'account_token', u::text,
    'account_hash', encode(sha256(convert_to(u::text, 'UTF8')), 'hex'),
    'server_time', extract(epoch from now())::bigint);
end $$;

-- Age question on first opening (items 4247, 4253). A band can only go down here; it goes up by
-- itself on the day the given birth month allows it.
create or replace function public.shop_set_age(p_year int, p_month int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  today date := public._shop_today();
  cur int := public._shop_band_of(u);
  b jsonb;
begin
  if p_month not between 1 and 12 or p_year < extract(year from today)::int - 120 or make_date(p_year, p_month, 1) > today then
    return jsonb_build_object('ok', false, 'error', 'bad_date');
  end if;
  b := public._shop_band(p_year, p_month, today);
  if cur is not null and (b->>'band')::int > cur then
    return jsonb_build_object('ok', false, 'error', 'age_locked', 'band', cur);
  end if;
  insert into public.shop_profiles (user_id, age_band, band_rises_at)
  values (u, (b->>'band')::int, (b->>'rises_at')::date)
  on conflict (user_id) do update set age_band = excluded.age_band, band_rises_at = excluded.band_rises_at;
  return jsonb_build_object('ok', true, 'band', (b->>'band')::int);
end $$;

-- The player confirmed the note on the right of withdrawal (item 4025).
create or replace function public.shop_withdrawal_ok() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  update public.shop_profiles set withdrawal_ok = true where user_id = u;
  return jsonb_build_object('ok', found);
end $$;

-- Adults change their monthly cap: lower at once, higher after 7 days, at most 300 EUR (item 4250).
create or replace function public.shop_set_limit(p_cap_cents int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  cur int := public._shop_cap(u);
  caps jsonb := public._config('shop_caps', '{"18_max": 30000}');
begin
  if coalesce(public._shop_band_of(u), 0) < 18 then
    return jsonb_build_object('ok', false, 'error', 'fixed_limit');
  end if;
  if p_cap_cents < 0 or p_cap_cents > (caps->>'18_max')::int then
    return jsonb_build_object('ok', false, 'error', 'bad_limit');
  end if;
  if p_cap_cents <= cur then
    insert into public.spend_limits (user_id, cap_cents) values (u, p_cap_cents)
    on conflict (user_id) do update set cap_cents = excluded.cap_cents, raise_to_cents = null, raise_at = null;
    return jsonb_build_object('ok', true, 'cap_cents', p_cap_cents);
  end if;
  insert into public.spend_limits (user_id, cap_cents, raise_to_cents, raise_at) values (u, cur, p_cap_cents, now() + interval '7 days')
  on conflict (user_id) do update set raise_to_cents = excluded.raise_to_cents, raise_at = excluded.raise_at;
  return jsonb_build_object('ok', true, 'cap_cents', cur, 'raise_to_cents', p_cap_cents,
    'raise_at', extract(epoch from now() + interval '7 days')::bigint);
end $$;

-- Buys an offer with Riftglass (item 4133): price, balance, limit and account checked in one transaction.
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

-- Bag items and coins from purchases, handed to the game once (item 4344).
create or replace function public.shop_claim() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  r jsonb;
begin
  with c as (
    update public.deliveries set claimed_at = now()
    where user_id = u and claimed_at is null returning id, grants)
  select jsonb_agg(jsonb_build_object('id', id, 'grants', grants) order by id) into r from c;
  return coalesce(r, '[]'::jsonb);
end $$;

-- "My purchases" (item 4184): newest first.
create or replace function public.shop_history() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'offer', offer_id, 'store', store, 'eur_cents', eur_cents,
      'rg', rg_spent, 'status', status, 'at', extract(epoch from at)::bigint) order by at desc, id desc), '[]'::jsonb)
  from (select * from public.purchases where user_id = public._uid() order by at desc, id desc limit 100) p
$$;

-- Daily Riftglass of the Wayfarer Pass (items 4631, 4637): missed days are paid later, at most 7.
create or replace function public.shop_pass_daily() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  today date := public._shop_today();
  cfg jsonb := public._config('shop_pass_daily', '{"rg": 30, "max_days": 7}');
  s public.subscriptions;
  days int;
  bal int;
begin
  select * into s from public.subscriptions where user_id = u and status in ('active', 'grace') and expires_at > now()
    order by expires_at desc limit 1 for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'no_pass'); end if;
  days := least(coalesce(today - s.daily_paid_on, 1), (cfg->>'max_days')::int);
  if days <= 0 then return jsonb_build_object('ok', true, 'added', 0, 'balance', public._shop_balance(u)); end if;
  update public.subscriptions set daily_paid_on = today where original_transaction_id = s.original_transaction_id;
  bal := public._shop_ledger_add(u, days * (cfg->>'rg')::int, 'pass_daily', today::text);
  return jsonb_build_object('ok', true, 'added', days * (cfg->>'rg')::int, 'balance', bal);
end $$;

-- ---------------------------------------------------------------------------------------
-- Billing service API (service role only): verified store receipts, refunds, pass status.

-- Credits a verified store purchase. Safe to call twice with the same transaction (item 4128).
-- Over the monthly cap: still credited (the money is paid), but the shop locks until the month
-- ends (item 4251).
create or replace function public._shop_credit(p_uid uuid, p_store text, p_txn text, p_product text, p_eur_cents int,
    p_choice text default null) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  o jsonb;
  pid bigint;
  prev public.purchases;
  why text;
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
  insert into public.purchases (user_id, store, store_transaction_id, product_id, offer_id, eur_cents, choice)
  values (p_uid, p_store, p_txn, p_product, o->>'id', greatest(coalesce(p_eur_cents, 0), 0),
    case when o ? 'choice' and (o->'choice') ? p_choice then p_choice else o->'choice'->>0 end)
  returning id into pid;
  perform public._shop_grant(p_uid, pid, o, case when o ? 'choice' and (o->'choice') ? p_choice then p_choice else o->'choice'->>0 end);
  return jsonb_build_object('ok', true, 'purchase', pid, 'balance', public._shop_balance(p_uid),
    'locked', public._shop_spent(p_uid) > public._shop_cap(p_uid));
end $$;

-- Takes back a refunded or revoked purchase (items 4134-4136). Riftglass is taken back even if it
-- was spent (the balance can go below 0); unlocks go; unclaimed bag items go.
create or replace function public._shop_refund(p_store text, p_txn text, p_note text default '') returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  p public.purchases;
  o jsonb;
  g jsonb;
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
    end if;
  end loop;
  delete from public.deliveries where purchase_id = p.id and claimed_at is null;
  update public.subscriptions set status = 'revoked', expires_at = least(expires_at, now())
    where user_id = p.user_id and original_transaction_id = p_txn;
  return jsonb_build_object('ok', true, 'balance', public._shop_balance(p.user_id));
end $$;

-- Pass status from the store (renewal, expiry, billing problems).
create or replace function public._shop_sub_set(p_uid uuid, p_store text, p_original_txn text, p_product text,
    p_expires timestamptz, p_status text, p_auto_renew boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  if p_status not in ('active', 'grace', 'expired', 'revoked', 'billing_retry') then
    return jsonb_build_object('ok', false, 'error', 'bad_status');
  end if;
  insert into public.subscriptions (original_transaction_id, user_id, store, product_id, expires_at, status, auto_renew, updated_at)
  values (p_original_txn, p_uid, p_store, p_product, p_expires, p_status, p_auto_renew, now())
  on conflict (original_transaction_id) do update set expires_at = excluded.expires_at, status = excluded.status,
    auto_renew = excluded.auto_renew, updated_at = now();
  return jsonb_build_object('ok', true);
end $$;

-- Which shop advantages an account has (item 4925), for the league service of area 7.
create or replace function public.shop_effects_for(p_uid uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'unlocks', coalesce((select jsonb_object_agg(key, count) from public.entitlements where user_id = p_uid), '{}'::jsonb),
    'pass_active', coalesce(public._shop_pass_until(p_uid) > now(), false))
$$;

-- Moving to a new phone (transfer_claim) moves the profile id; the shop rows follow it.
create or replace function public._shop_follow_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id = old.id then return new; end if;
  -- A fresh account on the new phone has nothing worth keeping except possible purchases: merge.
  update public.ledger set user_id = new.id where user_id = old.id;
  update public.purchases set user_id = new.id where user_id = old.id;
  update public.deliveries set user_id = new.id where user_id = old.id;
  update public.subscriptions set user_id = new.id where user_id = old.id;
  update public.refunds set user_id = new.id where user_id = old.id;
  insert into public.entitlements (user_id, key, count, at)
    select new.id, key, count, at from public.entitlements where user_id = old.id
  on conflict (user_id, key) do update set count = public.entitlements.count + excluded.count;
  delete from public.entitlements where user_id = old.id;
  delete from public.shop_profiles where user_id = new.id and exists (select 1 from public.shop_profiles where user_id = old.id);
  update public.shop_profiles set user_id = new.id where user_id = old.id;
  delete from public.spend_limits where user_id = new.id and exists (select 1 from public.spend_limits where user_id = old.id);
  update public.spend_limits set user_id = new.id where user_id = old.id;
  delete from public.wallets where user_id in (old.id, new.id);
  insert into public.wallets (user_id, balance)
    select new.id, coalesce(sum(amount), 0)::int from public.ledger where user_id = new.id;
  return new;
end $$;

drop trigger if exists shop_follow_profile on public.profiles;
create trigger shop_follow_profile after update of id on public.profiles
  for each row execute function public._shop_follow_profile();

revoke all on function public._shop_today(), public._shop_month_start(), public._shop_band(int, int, date),
  public._shop_band_of(uuid), public._shop_cap(uuid), public._shop_spent(uuid), public._shop_balance(uuid),
  public._shop_ledger_add(uuid, int, text, text), public._shop_pass_until(uuid), public._shop_bought(uuid, text, text),
  public._shop_rifts(uuid), public._shop_offer_block(uuid, jsonb, text), public._shop_grant(uuid, bigint, jsonb, text),
  public._shop_follow_profile() from public, anon, authenticated;
revoke all on function public._shop_credit(uuid, text, text, text, int, text), public._shop_refund(text, text, text),
  public._shop_sub_set(uuid, text, text, text, timestamptz, text, boolean), public.shop_effects_for(uuid)
  from public, anon, authenticated;
grant execute on function public._shop_credit(uuid, text, text, text, int, text), public._shop_refund(text, text, text),
  public._shop_sub_set(uuid, text, text, text, timestamptz, text, boolean), public.shop_effects_for(uuid) to service_role;
revoke all on function public.shop_state(), public.shop_set_age(int, int), public.shop_withdrawal_ok(),
  public.shop_set_limit(int), public.shop_buy(text, int, text), public.shop_claim(), public.shop_history(),
  public.shop_pass_daily() from public, anon;
grant execute on function public.shop_state(), public.shop_set_age(int, int), public.shop_withdrawal_ok(),
  public.shop_set_limit(int), public.shop_buy(text, int, text), public.shop_claim(), public.shop_history(),
  public.shop_pass_daily() to authenticated;
