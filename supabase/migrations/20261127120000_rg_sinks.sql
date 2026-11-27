-- Riftglass in play (Ali, 27 Nov 2026: bought Riftglass must be felt in the game). The game spends
-- Riftglass on fixed sinks: continue a lost story battle, heal the team, boost one bond try, bring a
-- roaming trip home, light the lamp again, stay before a Warden, Growth x2. The price table lives
-- here (server_config 'rg_sinks', the same values as data/riftglass_sinks.json, compared by
-- tests/unit/test_riftglass_sinks.gd); the client only says which sink and what price it showed.
-- A small free amount comes once a day per account (rg_daily_claim), so players learn the
-- currency. Children's accounts (age band 0) get neither. Fixed values, nothing random.
--
-- Same security model as the shop: tables with row level security and no rights, players only
-- call the security-definer functions, which find the caller through public._uid().

create table if not exists public.rg_spends (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  reason text not null,
  -- The battle (continue, bond boost), the started hours left (trip skip) or ''.
  ref text not null default '',
  price int not null check (price > 0),
  -- Server day (Europe/Berlin) for the per-day limits.
  day date not null,
  at timestamptz not null default now()
);
create index if not exists rg_spends_user on public.rg_spends (user_id, reason, ref);

create table if not exists public.rg_daily (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  amount int not null,
  primary key (user_id, day)
);

alter table public.rg_spends enable row level security;
alter table public.rg_daily enable row level security;

-- Prices in Riftglass. "continue": price of the 1st, 2nd, 3rd continue in one battle.
-- "trip_skip": per started hour left. "max_per_ref": per battle, "max_per_day": per server day.
insert into public.server_config (key, value) values
  ('rg_sinks', '{"daily_rg": 20, "spends_per_hour": 60, "sinks": {"continue": {"prices": [200, 400, 800], "max_per_ref": 3}, "heal": {"price": 100}, "bond_boost": {"price": 200, "bonus": 0.3, "max_per_ref": 5}, "trip_skip": {"price_per_hour": 100, "max_hours": 12}, "lamp_relight": {"price": 200, "max_per_day": 3}, "warden_retry": {"price": 100}, "growth_x2": {"price": 100, "battles": 5, "mult": 2.0}}}')
on conflict (key) do nothing;

-- Price of [p_reason] after [p_used] uses for this battle, with [p_hours] started hours left
-- (trip skip). 0 = not for sale.
create or replace function public._rg_sink_price(p_reason text, p_used int, p_hours int) returns int
language plpgsql stable as $$
declare
  s jsonb := public._config('rg_sinks', '{}'::jsonb)->'sinks'->p_reason;
  n int;
begin
  if s is null then return 0; end if;
  if p_reason = 'continue' then
    n := least(jsonb_array_length(coalesce(s->'prices', '[]'::jsonb)), coalesce((s->>'max_per_ref')::int, 0));
    if p_used < 0 or p_used >= n then return 0; end if;
    return (s->'prices'->>p_used)::int;
  elsif p_reason = 'trip_skip' then
    if p_hours < 1 or p_hours > coalesce((s->>'max_hours')::int, 0) then return 0; end if;
    return p_hours * coalesce((s->>'price_per_hour')::int, 0);
  end if;
  return coalesce((s->>'price')::int, 0);
end $$;

-- Spends Riftglass on a sink. [p_expected] is the price the game showed; a different server price
-- is refused with the real one, so nobody pays what they did not see.
create or replace function public.rg_spend(p_reason text, p_ref text default '', p_expected int default null) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  cfg jsonb := public._config('rg_sinks', '{}'::jsonb);
  s jsonb := cfg->'sinks'->p_reason;
  v_ref text := left(coalesce(p_ref, ''), 64);
  band int;
  used int := 0;
  hours int := 0;
  cost int;
  bal int;
begin
  if s is null then return public._fail('unknown_reason'); end if;
  band := public._shop_band_of(u);
  if band is not null and band < 13 then return public._fail('age'); end if;
  if not public._rate_ok(u, 'rg_spend', coalesce((cfg->>'spends_per_hour')::int, 60)) then
    return public._fail('slow_down');
  end if;
  -- The wallet row is the lock: two spends of one player run one after the other.
  insert into public.wallets (user_id) values (u) on conflict do nothing;
  select balance into bal from public.wallets where user_id = u for update;
  if s ? 'max_per_ref' then
    if v_ref = '' then return public._fail('bad_ref'); end if;
    select count(*) into used from public.rg_spends r where r.user_id = u and r.reason = p_reason and r.ref = v_ref;
    if used >= (s->>'max_per_ref')::int then return public._fail('used_up'); end if;
  end if;
  if s ? 'max_per_day' and (select count(*) from public.rg_spends r
      where r.user_id = u and r.reason = p_reason and r.day = public._shop_today()) >= (s->>'max_per_day')::int then
    return public._fail('used_up');
  end if;
  if p_reason = 'trip_skip' then
    if v_ref !~ '^[0-9]{1,3}$' then return public._fail('bad_ref'); end if;
    hours := v_ref::int;
  end if;
  cost := public._rg_sink_price(p_reason, used, hours);
  if cost <= 0 then return public._fail('bad_ref'); end if;
  if p_expected is distinct from cost then
    return jsonb_build_object('ok', false, 'error', 'price_changed', 'price', cost);
  end if;
  if bal < 0 or public._shop_spent(u) > public._shop_cap(u) then return public._fail('limit_reached'); end if;
  if bal < cost then return jsonb_build_object('ok', false, 'error', 'not_enough', 'balance', bal); end if;
  insert into public.rg_spends (user_id, reason, ref, price, day) values (u, p_reason, v_ref, cost, public._shop_today());
  bal := public._shop_ledger_add(u, -cost, 'sink', p_reason || ':' || v_ref);
  return jsonb_build_object('ok', true, 'balance', bal, 'price', cost, 'used', used + 1);
end $$;

-- The free Riftglass of the day, once per server day (Europe/Berlin) and account.
create or replace function public.rg_daily_claim() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  n int := coalesce((public._config('rg_sinks', '{}'::jsonb)->>'daily_rg')::int, 0);
  band int;
  bal int;
begin
  band := public._shop_band_of(u);
  if band is not null and band < 13 then return public._fail('age'); end if;
  insert into public.rg_daily (user_id, day, amount) values (u, public._shop_today(), n) on conflict do nothing;
  if not found or n <= 0 then
    return jsonb_build_object('ok', true, 'added', 0, 'balance', public._shop_balance(u));
  end if;
  bal := public._shop_ledger_add(u, n, 'daily', public._shop_today()::text);
  return jsonb_build_object('ok', true, 'added', n, 'balance', bal);
end $$;

revoke all on function public._rg_sink_price(text, int, int) from public, anon, authenticated;
revoke all on function public.rg_spend(text, text, int), public.rg_daily_claim() from public, anon;
grant execute on function public.rg_spend(text, text, int), public.rg_daily_claim() to authenticated;
