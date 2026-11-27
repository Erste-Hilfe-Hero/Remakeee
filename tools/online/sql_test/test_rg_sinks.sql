-- Riftglass sinks in play (20261127120000_rg_sinks.sql): server prices, escalation per battle,
-- limits, daily claim once per day, children refused, not callable without signing in.
insert into auth.users (id) values
  ('2b000000-0000-0000-0000-000000000001'), ('2b000000-0000-0000-0000-000000000002'),
  ('2b000000-0000-0000-0000-000000000003'), ('2b000000-0000-0000-0000-000000000004')
on conflict do nothing;

do $$ begin
  assert not has_function_privilege('anon', 'public.rg_spend(text, text, int)', 'execute'), 'anon cannot spend';
  assert not has_function_privilege('anon', 'public.rg_daily_claim()', 'execute'), 'anon cannot claim';
  assert has_function_privilege('authenticated', 'public.rg_spend(text, text, int)', 'execute');
  assert not has_function_privilege('authenticated', 'public._rg_sink_price(text, int, int)', 'execute'), 'helper hidden';
  assert public._rg_sink_price('continue', 0, 0) = 200;
  assert public._rg_sink_price('continue', 2, 0) = 800;
  assert public._rg_sink_price('continue', 3, 0) = 0, 'no 4th continue';
  assert public._rg_sink_price('trip_skip', 0, 5) = 500;
  assert public._rg_sink_price('trip_skip', 0, 13) = 0;
  assert public._rg_sink_price('nothing', 0, 0) = 0;
end $$;

-- Daily claim: once per day, then 0. Spending: not enough, wrong price, then it works.
do $$ begin perform set_config('request.jwt.claim.sub', '2b000000-0000-0000-0000-000000000001', false); end $$;
do $$
declare r jsonb;
begin
  r := public.rg_daily_claim();
  assert (r->>'added')::int = 20 and (r->>'balance')::int = 20, r::text;
  r := public.rg_daily_claim();
  assert (r->>'added')::int = 0 and (r->>'balance')::int = 20, 'second claim today gives nothing ' || r::text;
  r := public.rg_spend('heal', '', 100);
  assert r->>'error' = 'not_enough' and (r->>'balance')::int = 20, r::text;
  perform public._shop_ledger_add('2b000000-0000-0000-0000-000000000001', 3000, 'support', 'test');
  r := public.rg_spend('heal', '', 50);
  assert r->>'error' = 'price_changed' and (r->>'price')::int = 100, 'client price must match ' || r::text;
  r := public.rg_spend('heal', '', 100);
  assert (r->>'ok')::boolean and (r->>'balance')::int = 2920, r::text;
  assert public.rg_spend('free_stuff', '', 0)->>'error' = 'unknown_reason';
  -- Continue: 200, 400, 800 in one battle, then no more; the next battle starts at 200 again.
  assert (public.rg_spend('continue', 'b1', 200)->>'ok')::boolean;
  assert public.rg_spend('continue', 'b1', 200)->>'error' = 'price_changed', 'second continue costs more';
  assert (public.rg_spend('continue', 'b1', 400)->>'ok')::boolean;
  assert (public.rg_spend('continue', 'b1', 800)->>'ok')::boolean;
  assert public.rg_spend('continue', 'b1', 800)->>'error' = 'used_up';
  assert (public.rg_spend('continue', 'b2', 200)->>'ok')::boolean;
  assert public.rg_spend('continue', '', 200)->>'error' = 'bad_ref', 'continue needs the battle';
  -- Trip skip: per started hour left, only 1..12.
  r := public.rg_spend('trip_skip', '3', 300);
  assert (r->>'ok')::boolean and (r->>'price')::int = 300, r::text;
  assert public.rg_spend('trip_skip', '13', 1300)->>'error' = 'bad_ref';
  assert public.rg_spend('trip_skip', 'x', 100)->>'error' = 'bad_ref';
  -- Lamp: 3 a day.
  assert (public.rg_spend('lamp_relight', '', 200)->>'ok')::boolean;
  assert (public.rg_spend('lamp_relight', '', 200)->>'ok')::boolean;
  assert (public.rg_spend('lamp_relight', '', 200)->>'ok')::boolean;
  assert public.rg_spend('lamp_relight', '', 200)->>'error' = 'used_up';
  -- Every spend is in the ledger, and the wallet is their sum.
  assert (select balance from public.wallets where user_id = '2b000000-0000-0000-0000-000000000001')
    = (select sum(amount) from public.ledger where user_id = '2b000000-0000-0000-0000-000000000001');
  assert (select count(*) from public.ledger where user_id = '2b000000-0000-0000-0000-000000000001' and reason = 'sink') = 9;
end $$;

-- Children's accounts: no daily Riftglass, no spending.
do $$ begin perform set_config('request.jwt.claim.sub', '2b000000-0000-0000-0000-000000000002', false); end $$;
do $$ begin
  assert public.shop_set_age(extract(year from now())::int - 9, 1)->>'band' = '0';
  assert public.rg_daily_claim()->>'error' = 'age';
  assert public.rg_spend('heal', '', 100)->>'error' = 'age';
end $$;

-- 60 spends an hour.
insert into public.rate_events (user_id, kind)
  select '2b000000-0000-0000-0000-000000000003', 'rg_spend' from generate_series(1, 60);
do $$ begin perform set_config('request.jwt.claim.sub', '2b000000-0000-0000-0000-000000000003', false); end $$;
do $$ begin
  assert public.rg_spend('heal', '', 100)->>'error' = 'slow_down';
end $$;

-- A negative balance (Riftglass refunded after it was spent) locks spending like the shop.
do $$ begin perform set_config('request.jwt.claim.sub', '2b000000-0000-0000-0000-000000000004', false); end $$;
do $$ begin
  perform public._shop_ledger_add('2b000000-0000-0000-0000-000000000004', -50, 'refund', 'test');
  assert public.rg_spend('heal', '', 100)->>'error' = 'limit_reached';
end $$;
do $$ begin perform set_config('request.jwt.claim.sub', '', false); end $$;
