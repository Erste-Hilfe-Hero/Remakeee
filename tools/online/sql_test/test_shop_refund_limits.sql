-- 20261128070100_shop_refund_limits.sql (1.3.2 security review findings 3 and 4): a refund takes
-- back the Riftglass the Monthly Card and the Wayfarer Pass paid out over time; a store purchase
-- over the offer limit is credited as plain Riftglass for its price, not as the pack again.
insert into auth.users (id) values
  ('2d000000-0000-0000-0000-000000000001'), ('2d000000-0000-0000-0000-000000000002'),
  ('2d000000-0000-0000-0000-000000000003'), ('2d000000-0000-0000-0000-000000000004')
on conflict do nothing;

do $$ begin
  assert public._shop_plain_rg(4999) = 7500, 'same price tier';
  assert public._shop_plain_rg(999) = 1300;
  assert public._shop_plain_rg(499) = 600, 'the Monthly Card is no plain tier';
  assert public._shop_plain_rg(299) = 300, 'no tier of that price: 1 per cent plus 1';
  assert not has_function_privilege('authenticated', 'public._shop_plain_rg(int)', 'execute');
end $$;

-- Monthly Card: all 30 days paid, then refunded: the paid days come back too.
do $$ declare u uuid := '2d000000-0000-0000-0000-000000000001'; r jsonb; begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  perform public._shop_credit(u, 'apple', 'RL-card-1', 'de.chimora.game.card.monthly', 499);
  update public.shop_cards set started_on = started_on - 29 where user_id = u;
  r := public.shop_card_daily();
  assert (r->>'added')::int = 3000 and (r->>'balance')::int = 3300, 'card paid: ' || r::text;
  r := public._shop_refund('apple', 'RL-card-1');
  assert (r->>'balance')::int = 0, 'card refund takes 300 and the 30 paid days: ' || r::text;
  assert (public.shop_card_daily()->>'days_left')::int = 0;
end $$;

-- Two cards, 10 days paid, the second refunded: its 30 unpaid days go, nothing paid comes back.
-- Then the first is refunded too: its 10 paid days come back.
do $$ declare u uuid := '2d000000-0000-0000-0000-000000000002'; r jsonb; begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  perform public._shop_credit(u, 'apple', 'RL-card-2', 'de.chimora.game.card.monthly', 499);
  perform public._shop_credit(u, 'apple', 'RL-card-3', 'de.chimora.game.card.monthly', 499);
  update public.shop_cards set started_on = started_on - 9 where user_id = u;
  r := public.shop_card_daily();
  assert (r->>'added')::int = 1000 and (r->>'days_left')::int = 50, 'ten days paid: ' || r::text;
  r := public._shop_refund('apple', 'RL-card-3');
  assert (r->>'balance')::int = 1300, 'second card: 300 back, no paid day: ' || r::text;
  r := public._shop_refund('apple', 'RL-card-2');
  assert (r->>'balance')::int = 0, 'first card: 300 and 10 paid days back: ' || r::text;
end $$;

-- Wayfarer Pass: daily Riftglass and premium track Riftglass go back; free track and Riftglass
-- from elsewhere stay.
do $$ declare u uuid := '2d000000-0000-0000-0000-000000000003'; r jsonb; begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  perform public._shop_ledger_add(u, 100, 'store', 'rl-other');
  perform public._shop_credit(u, 'apple', 'RL-pass', 'de.chimora.game.pass', 499);
  perform public._shop_sub_set(u, 'apple', 'RL-pass', 'de.chimora.game.pass', now() + interval '30 days', 'active', true);
  assert (public.shop_pass_daily()->>'added')::int = 30, 'pass daily';
  perform public.pass_points_add('daily_task', 3);
  assert (public.pass_claim(1, 'premium')->>'ok')::boolean, 'premium tier 1';
  assert (public.pass_claim(1, 'free')->>'ok')::boolean, 'free tier 1';
  assert public._shop_balance(u) = 180, 'before refund: ' || public._shop_balance(u);
  r := public._shop_refund('apple', 'RL-pass');
  assert (r->>'balance')::int = 100, 'pass refund takes daily and premium Riftglass: ' || r::text;
  assert not (public.shop_effects_for(u)->>'pass_active')::boolean, 'pass ends';
end $$;

-- Once-per-account packs bought again in the store: plain Riftglass, no second bag.
do $$ declare u uuid := '2d000000-0000-0000-0000-000000000004'; r jsonb; begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  r := public._shop_credit(u, 'apple', 'RL-b1', 'de.chimora.game.consumable.champion_bundle', 4999);
  assert (r->>'balance')::int = 3000 and not (r->>'over_limit')::boolean, 'first bundle: ' || r::text;
  r := public._shop_credit(u, 'apple', 'RL-b2', 'de.chimora.game.consumable.champion_bundle', 4999);
  assert (r->>'ok')::boolean and (r->>'over_limit')::boolean, 'second bundle still credited: ' || r::text;
  assert (r->>'balance')::int = 10500, 'second bundle is the 49.99 tier, 7500: ' || r::text;
  assert (select count(*) from public.deliveries where user_id = u) = 1, 'one bundle bag only';
  r := public._shop_credit(u, 'apple', 'RL-s1', 'de.chimora.game.consumable.starter', 299);
  r := public._shop_credit(u, 'google', 'RL-s2', 'de.chimora.game.consumable.starter', 299);
  assert (r->>'balance')::int = 10500 + 300 + 300, 'second starter: 300 plain: ' || r::text;
  assert (select count(*) from public.deliveries where user_id = u) = 2;
  r := public._shop_credit(u, 'apple', 'RL-b2', 'de.chimora.game.consumable.champion_bundle', 4999);
  assert (r->>'duplicate')::boolean, 'same receipt again';
  -- Refunding the plain credit takes only the plain Riftglass back; the first bundle stays.
  r := public._shop_refund('apple', 'RL-b2');
  assert (r->>'balance')::int = 3000 + 600, 'plain refund: ' || r::text;
  assert (select count(*) from public.deliveries where user_id = u) = 2, 'bags of the first purchases stay';
  r := public.shop_buy('rg_champion_bundle', 5000);
  assert r->>'error' = 'offer_limit', 'Riftglass buy still refused: ' || r::text;
end $$;
