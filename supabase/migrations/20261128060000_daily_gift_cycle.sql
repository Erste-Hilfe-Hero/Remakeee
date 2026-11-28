-- The welcome gift of the daily card (Chimora 1.3.2, data/daily.json, DailyBoard.gd): the free
-- Riftglass of the day (rg_daily_claim, 20261127120000_rg_sinks.sql) now follows a 7-step cycle.
-- The step is the number of days this account has claimed so far, modulo the cycle length, so a
-- missed day never resets or lowers anything: the cycle only moves on when a gift is taken.
-- Step 7 gives more. server_config 'daily_gift' holds the same "gift_rg" list as data/daily.json
-- (tests/unit/test_daily_card.gd compares them). Children's accounts still get nothing.

insert into public.server_config (key, value) values
  ('daily_gift', '{"gift_rg": [20, 20, 20, 20, 20, 20, 60]}')
on conflict (key) do nothing;

create or replace function public.rg_daily_claim() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  cyc jsonb := public._config('daily_gift', '{}'::jsonb)->'gift_rg';
  len int := 0;
  taken int;
  n int;
  band int;
  bal int;
begin
  band := public._shop_band_of(u);
  if band is not null and band < 13 then return public._fail('age'); end if;
  if exists (select 1 from public.rg_daily where user_id = u and day = public._shop_today()) then
    return jsonb_build_object('ok', true, 'added', 0, 'balance', public._shop_balance(u));
  end if;
  select count(*) into taken from public.rg_daily where user_id = u;
  if jsonb_typeof(cyc) = 'array' then len := jsonb_array_length(cyc); end if;
  if len > 0 then
    n := coalesce((cyc->>(taken % len))::int, 0);
  else
    n := coalesce((public._config('rg_sinks', '{}'::jsonb)->>'daily_rg')::int, 0);
  end if;
  insert into public.rg_daily (user_id, day, amount) values (u, public._shop_today(), n) on conflict do nothing;
  if not found or n <= 0 then
    return jsonb_build_object('ok', true, 'added', 0, 'balance', public._shop_balance(u));
  end if;
  bal := public._shop_ledger_add(u, n, 'daily', public._shop_today()::text);
  return jsonb_build_object('ok', true, 'added', n, 'balance', bal, 'step', taken % greatest(len, 1) + 1);
end $$;

revoke all on function public.rg_daily_claim() from public, anon;
grant execute on function public.rg_daily_claim() to authenticated;
