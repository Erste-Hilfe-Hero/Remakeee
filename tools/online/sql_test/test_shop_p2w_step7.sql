-- Pay-to-win step 7: Riftglass bonus, first purchase double once per tier, Monthly Card, deal rotation.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000d7'), ('20000000-0000-0000-0000-0000000000d8')
on conflict do nothing;

-- Grants carry the bonus; the first purchase of a tier adds its base once, never twice.
do $$ declare u uuid := '20000000-0000-0000-0000-0000000000d7'; r jsonb; begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  assert (select data->'grants'->0->>'n' from public.shop_offers where id = 'rg_glass_10000') = '16000', '+60 % in the grant';
  r := public._shop_credit(u, 'apple', 'S7-1', 'de.chimora.game.glass.1000', 999);
  assert (r->>'balance')::int = 2300, 'first 1000 tier: 1300 + 1000: ' || r::text;
  r := public._shop_credit(u, 'apple', 'S7-2', 'de.chimora.game.glass.1000', 999);
  assert (r->>'balance')::int = 3600, 'second 1000 tier: 1300 only: ' || r::text;
  r := public._shop_credit(u, 'apple', 'S7-3', 'de.chimora.game.glass.100', 99);
  assert (r->>'balance')::int = 3800, 'every tier has its own first purchase: ' || r::text;
  assert (select count(*) from public.ledger where user_id = u and reason = 'first_double') = 2;
  -- A refunded first purchase takes the extra back; buying the tier again gives no new double.
  r := public._shop_refund('apple', 'S7-3');
  assert (r->>'balance')::int = 3600, 'refund takes 100 + 100 back: ' || r::text;
  r := public._shop_credit(u, 'apple', 'S7-4', 'de.chimora.game.glass.100', 99);
  assert (r->>'balance')::int = 3700, 'no second double after a refund: ' || r::text;
  assert (public.shop_extras()->'firsts'->>'rg_glass_1000')::int = 2;
  assert (public.shop_extras()->'firsts'->>'rg_glass_5000')::int = 0;
end $$;

-- Monthly Card: 300 at once, 100 a day for 30 days, missed days wait, buying again adds 30 days.
do $$ declare u uuid := '20000000-0000-0000-0000-0000000000d8'; r jsonb; begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.shop_set_age(1990, 3);
  assert public.shop_card_daily()->>'error' = 'no_card';
  r := public._shop_credit(u, 'google', 'S7-card-1', 'de.chimora.game.card.monthly', 499);
  assert (r->>'balance')::int = 300, 'instant part: ' || r::text;
  r := public.shop_card_daily();
  assert (r->>'added')::int = 100 and (r->>'days_left')::int = 29, 'day 1: ' || r::text;
  assert (public.shop_card_daily()->>'added')::int = 0, 'once a day';
  update public.shop_cards set started_on = started_on - 9 where user_id = u;
  r := public.shop_card_daily();
  assert (r->>'added')::int = 900 and (r->>'days_left')::int = 20, 'missed days wait: ' || r::text;
  update public.shop_cards set started_on = started_on - 100 where user_id = u;
  r := public.shop_card_daily();
  assert (r->>'added')::int = 2000 and (r->>'days_left')::int = 0, 'never more than 30 days: ' || r::text;
  assert public._shop_balance(u) = 3300, '3300 in total';
  -- Buying after the card ran out starts 30 new days today.
  r := public._shop_credit(u, 'google', 'S7-card-2', 'de.chimora.game.card.monthly', 499);
  r := public.shop_card_daily();
  assert (r->>'added')::int = 100 and (r->>'days_left')::int = 29, 'second card: ' || r::text;
  assert (public.shop_extras()->'card'->'monthly_card'->>'days_left')::int = 29;
  -- A refund removes the days not paid yet.
  perform public._shop_refund('google', 'S7-card-2');
  assert (public.shop_card_daily()->>'days_left')::int = 0;
end $$;

-- Deals: fixed by the Berlin date (2026-11-30 is a Monday), refused on other days.
do $$ declare u uuid := '20000000-0000-0000-0000-0000000000d7'; o jsonb; deals jsonb; begin
  assert public._shop_deal_on('{"per": "day", "weekday": 0}', '2026-11-30');
  assert not public._shop_deal_on('{"per": "day", "weekday": 0}', '2026-12-01');
  assert public._shop_deal_on('{"per": "day", "weekday": 6}', '2026-12-06');
  -- Week 0 runs from Monday 29 Dec 1969 to Sunday 4 Jan 1970.
  assert public._shop_deal_on('{"per": "week", "index": 1, "cycle": 4}', '1970-01-05')
    and public._shop_deal_on('{"per": "week", "index": 1, "cycle": 4}', '1970-01-11'), 'a week runs Monday to Sunday';
  assert public._shop_deal_on('{"per": "week", "index": 2, "cycle": 4}', '1970-01-12');
  perform set_config('request.jwt.claim.sub', u::text, true);
  deals := public.shop_extras()->'deals';
  assert jsonb_array_length(deals) = 2, 'one daily and one weekly deal on sale: ' || deals::text;
  for o in select data from public.shop_offers where data ? 'rotation' loop
    if deals ? (o->>'id') then
      assert public._shop_offer_block(u, o, null) is null, o->>'id';
    else
      assert public._shop_offer_block(u, o, null) = 'not_now', o->>'id';
    end if;
  end loop;
  -- Bought once, a deal waits for its next week.
  perform public._shop_ledger_add(u, 10000, 'support', 'test');
  assert (public.shop_buy(deals->>0, (select (data->>'rg_price')::int from public.shop_offers where id = deals->>0))->>'ok')::boolean;
  assert public.shop_buy(deals->>0, (select (data->>'rg_price')::int from public.shop_offers where id = deals->>0))->>'error' = 'offer_limit';
end $$;

-- Seal tiers above the old top: Power Seal VIII needs VII.
do $$ declare u uuid := '20000000-0000-0000-0000-0000000000d7'; begin
  assert public._shop_offer_block(u, (select data from public.shop_offers where id = 'rg_power_seal_8'), null) = 'not_yet';
  insert into public.entitlements (user_id, key, count) values (u, 'power_seal', 7);
  assert public._shop_offer_block(u, (select data from public.shop_offers where id = 'rg_power_seal_8'), null) is null;
end $$;
