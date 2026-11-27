-- Wayfarer Pass track (supabase/migrations/20261127140040_pass_track.sql): points with day cap and
-- rate limit, free and premium claims once each, premium only with an active pass.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000f4') on conflict do nothing;

do $$
declare
  u uuid := '20000000-0000-0000-0000-0000000000f4';
  r jsonb;
  bal int;
begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  assert jsonb_array_length(public._config('pass_track')->'tiers') = 30, '30 steps copied from data/pass_track.json';
  assert public._pass_season(date '2026-01-01') = 0 and public._pass_season(date '2026-01-30') = 0;
  assert public._pass_season(date '2026-01-31') = 1, 'a season lasts 30 days';
  assert public._pass_season_start(11) = date '2026-01-01' + 330;
  r := public.pass_state();
  assert (r->>'ok')::boolean and (r->>'points')::int = 0 and (r->>'tier')::int = 0, r::text;
  assert not (r->>'premium')::boolean;
  -- Points from play: win 10, bond 25, unknown kinds nothing, at most 3 events a report.
  r := public.pass_points_add('win', 1);
  assert (r->>'added')::int = 10, r::text;
  r := public.pass_points_add('bond', 9);
  assert (r->>'added')::int = 75, 'clamped to 3 events: ' || r::text;
  r := public.pass_points_add('cheat', 1);
  assert (r->>'added')::int = 0;
  r := public.pass_points_add('win', -5);
  assert (r->>'added')::int = 0 and (r->>'points')::int = 85;
  assert public.pass_claim(1, 'free')->>'error' = 'not_reached';
  r := public.pass_points_add('daily_task', 1);
  assert (r->>'tier')::int = 1, r::text;
  -- Free step 1: 500 coins into the deliveries bag.
  r := public.pass_claim(1, 'free');
  assert (r->>'ok')::boolean, r::text;
  assert public.pass_claim(1, 'free')->>'error' = 'claimed', 'once';
  assert (select count(*) from public.deliveries where user_id = u and claimed_at is null
    and grants = '[{"t": "coins", "n": 500}]'::jsonb) = 1, 'coins wait in deliveries';
  assert public.pass_claim(1, 'premium')->>'error' = 'no_pass', 'premium needs the pass';
  assert public.pass_claim(1, 'gold')->>'error' = 'bad_lane';
  assert public.pass_claim(31, 'free')->>'error' = 'bad_tier';
  -- With the pass the premium row opens: step 1 is 50 Riftglass.
  perform public._shop_sub_set(u, 'local', 'pass-test-1', 'de.chimora.game.pass', now() + interval '30 days', 'active', true);
  assert (public.pass_state()->>'premium')::boolean;
  bal := public._shop_balance(u);
  r := public.pass_claim(1, 'premium');
  assert (r->>'ok')::boolean and (r->>'balance')::int = bal + 50, r::text;
  assert (select reason from public.ledger where user_id = u order by id desc limit 1) = 'pass_track';
  assert public.pass_claim(1, 'premium')->>'error' = 'claimed';
  r := public.pass_state();
  assert (r->>'claimed_free')::int = 1 and (r->>'claimed_premium')::int = 1, r::text;
  -- Day cap: 400 points a day.
  update public.pass_progress set day_points = 395 where user_id = u;
  r := public.pass_points_add('bond', 1);
  assert (r->>'added')::int = 5, 'day cap: ' || r::text;
  assert (public.pass_points_add('win', 1)->>'added')::int = 0;
  -- Step 15 unlocks a look, step 30 premium a Spirling.
  update public.pass_progress set points = 3000 where user_id = u;
  assert (public.pass_claim(15, 'free')->>'ok')::boolean;
  assert exists (select 1 from public.entitlements where user_id = u and key = 'frame_lantern');
  assert (public.pass_claim(30, 'premium')->>'ok')::boolean;
  assert exists (select 1 from public.deliveries where user_id = u and grants @> '[{"t": "spirling", "species": "Vorlucent"}]'::jsonb);
  assert exists (select 1 from public.entitlements where user_id = u and key = 'hat_tricorn');
  -- Rate limit: hour_calls reports an hour.
  update public.pass_progress set hour_calls = 120, hour_at = now() where user_id = u;
  assert public.pass_points_add('win', 1)->>'error' = 'slow_down';
  update public.pass_progress set hour_at = now() - interval '2 hours' where user_id = u;
  assert (public.pass_points_add('win', 1)->>'ok')::boolean;
  -- The action queue carries pass points once.
  update public.pass_progress set day_points = 0 where user_id = u;
  r := public.action_once('pass-act-0001', 'pass_points_add', '{"p_kind": "win", "p_amount": 1}');
  assert (r->>'added')::int = 10, r::text;
  assert (public.action_once('pass-act-0001', 'pass_points_add', '{"p_kind": "win", "p_amount": 1}')->>'repeat')::boolean;
end $$;

do $$
begin
  assert not has_function_privilege('anon', 'public.pass_claim(int, text)', 'execute');
  assert not has_function_privilege('authenticated', 'public._pass_row(uuid)', 'execute');
end $$;
