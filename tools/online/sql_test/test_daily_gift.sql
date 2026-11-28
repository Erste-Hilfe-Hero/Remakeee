-- The welcome gift cycle of the daily Riftglass (20261128060000_daily_gift_cycle.sql): 20 on the
-- first six claimed days, 60 on the seventh, then the cycle starts again; missed days in between
-- reset nothing; once a day; children refused.
insert into auth.users (id) values
  ('2c000000-0000-0000-0000-000000000001'), ('2c000000-0000-0000-0000-000000000002'),
  ('2c000000-0000-0000-0000-000000000003'), ('2c000000-0000-0000-0000-000000000004')
on conflict do nothing;

do $$ begin
  assert (public._config('daily_gift', '{}'::jsonb)->'gift_rg') = '[20, 20, 20, 20, 20, 20, 60]'::jsonb;
  assert not has_function_privilege('anon', 'public.rg_daily_claim()', 'execute'), 'anon cannot claim';
end $$;

-- A new account: step 1, 20 Riftglass, then nothing more today.
do $$ begin perform set_config('request.jwt.claim.sub', '2c000000-0000-0000-0000-000000000001', false); end $$;
do $$
declare r jsonb;
begin
  r := public.rg_daily_claim();
  assert (r->>'added')::int = 20 and (r->>'step')::int = 1, r::text;
  r := public.rg_daily_claim();
  assert (r->>'added')::int = 0 and (r->>'balance')::int = 20, 'once a day ' || r::text;
end $$;

-- Six earlier claims with long gaps between them (missed days): today is step 7 and pays 60.
do $$ begin perform set_config('request.jwt.claim.sub', '2c000000-0000-0000-0000-000000000002', false); end $$;
do $$
declare r jsonb;
begin
  insert into public.rg_daily (user_id, day, amount)
    select '2c000000-0000-0000-0000-000000000002', public._shop_today() - (g * 5), 20 from generate_series(1, 6) g;
  r := public.rg_daily_claim();
  assert (r->>'added')::int = 60 and (r->>'step')::int = 7, 'gaps do not reset the cycle ' || r::text;
end $$;

-- Seven earlier claims: the cycle starts again at 20.
do $$ begin perform set_config('request.jwt.claim.sub', '2c000000-0000-0000-0000-000000000003', false); end $$;
do $$
declare r jsonb;
begin
  insert into public.rg_daily (user_id, day, amount)
    select '2c000000-0000-0000-0000-000000000003', public._shop_today() - g, 20 from generate_series(1, 7) g;
  r := public.rg_daily_claim();
  assert (r->>'added')::int = 20 and (r->>'step')::int = 1, r::text;
end $$;

-- Children's accounts: nothing.
do $$ begin perform set_config('request.jwt.claim.sub', '2c000000-0000-0000-0000-000000000004', false); end $$;
do $$ begin
  assert public.shop_set_age(extract(year from now())::int - 9, 1)->>'band' = '0';
  assert public.rg_daily_claim()->>'error' = 'age';
end $$;
