-- Shop (area 10): age bands, limits, Riftglass purchases, store credits, refunds, pass, moving phones.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-00000000000a'), ('20000000-0000-0000-0000-00000000000b'),
  ('20000000-0000-0000-0000-00000000000c'), ('20000000-0000-0000-0000-0000000000a2')
on conflict do nothing;

create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;

-- A test offer that is ready and costs Riftglass (the real ones get ready step by step).
insert into public.shop_offers (id, product_id, data) values
  ('rg_test_tonic', 'de.chimora.game.consumable.test_tonic',
   '{"id": "rg_test_tonic", "kind": "advantage", "rg_price": 300, "eur_cents": 299, "ready": true, "min_band": 13,
     "grants": [{"t": "item", "id": "rg_ring_tonic", "n": 2}, {"t": "coins", "n": 50}]}'),
  ('rg_test_slot', 'de.chimora.game.unlock.test_slot',
   '{"id": "rg_test_slot", "kind": "advantage", "rg_price": 1500, "eur_cents": 1499, "ready": true, "min_band": 13,
     "limit": {"per": "account", "n": 1}, "grants": [{"t": "unlock", "id": "team_slot_6"}]}'),
  ('rg_test_pack', 'de.chimora.game.consumable.test_pack',
   '{"id": "rg_test_pack", "kind": "advantage", "rg_price": 0, "eur_cents": 499, "ready": true, "min_band": 13,
     "requires": "rifts:1", "choice": ["rg_prism_ember", "rg_prism_tide"],
     "grants": [{"t": "rg", "n": 300}, {"t": "choice", "n": 1}]}'),
  ('rg_test_pass', 'de.chimora.game.test_pass',
   '{"id": "rg_test_pass", "kind": "advantage", "rg_price": 0, "eur_cents": 499, "ready": true, "min_band": 13,
     "grants": [{"t": "pass", "days": 30}]}')
on conflict (id) do update set data = excluded.data;

-- The real catalog is there and the Fair League knows every shop advantage.
do $$ begin
  assert (select count(*) from public.shop_offers) > 100, 'offers copied from data/shop.json';
  assert (select data->>'rg_price' from public.shop_offers where id = 'rg_ring_tonic') = '100';
  assert (select value from public.server_config where key = 'league_fair_blocked_sources') ? 'rg_team_slot_6';
  assert not ((select value from public.server_config where key = 'league_fair_blocked_sources') ? 'rg_jacket_moss'), 'cosmetics are not blocked';
end $$;

-- Age bands (items 4247-4253).
do $$ declare d date := '2026-11-06'; begin
  assert (public._shop_band(2016, 1, d)->>'band')::int = 0;
  assert (public._shop_band(2013, 11, d)->>'band')::int = 13, 'turns 13 this month';
  assert (public._shop_band(2013, 12, d)->>'band')::int = 0, 'turns 13 next month';
  assert (public._shop_band(2013, 12, d)->>'rises_at')::date = '2026-12-01';
  assert (public._shop_band(2010, 6, d)->>'band')::int = 16;
  assert (public._shop_band(2000, 1, d)->>'band')::int = 18;
  assert public._shop_band(2000, 1, d)->>'rises_at' is null;
end $$;

set role authenticated;

-- Players cannot reach the tables or the service functions.
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ begin
  begin
    perform * from public.wallets;
    raise exception 'wallets must not be readable';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public._shop_credit('20000000-0000-0000-0000-00000000000a', 'apple', 'x', 'de.chimora.game.glass.100', 99);
    raise exception 'players must not credit themselves';
  exception when insufficient_privilege then null;
  end;
end $$;

-- A child: shop closed, the band cannot be raised by answering again.
select pg_temp.as_user('20000000-0000-0000-0000-00000000000c');
do $$ declare r jsonb; begin
  perform public.hello(1);
  r := public.shop_state();
  assert r->>'band' is null, 'not asked yet';
  assert public.shop_buy('rg_test_tonic', 300)->>'error' = 'age_needed';
  assert public.shop_set_age(2018, 3)->>'band' = '0';
  assert public.shop_set_age(1990, 3)->>'error' = 'age_locked', 'a child cannot just switch to adult';
  assert (public.shop_state()->>'cap_cents')::int = 0;
  assert public.shop_buy('rg_test_tonic', 300)->>'error' = 'age';
  assert public.shop_set_age(2030, 1)->>'error' = 'bad_date';
end $$;

-- A teenager (13-15): fixed cap of 15 EUR that cannot be raised.
select pg_temp.as_user('20000000-0000-0000-0000-00000000000b');
do $$ begin
  perform public.hello(1);
  assert (public.shop_set_age(extract(year from now())::int - 14, 1)->>'band')::int = 13;
  assert (public.shop_state()->>'cap_cents')::int = 1500;
  assert public.shop_set_limit(5000)->>'error' = 'fixed_limit';
end $$;

-- An adult buys Riftglass in the store (credited by the billing service).
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ declare r jsonb; begin
  perform public.hello(1);
  assert (public.shop_set_age(1990, 5)->>'band')::int = 18;
  r := public.shop_state();
  assert (r->>'cap_cents')::int = 10000 and (r->>'balance')::int = 0 and not (r->>'locked')::boolean;
  assert length(r->>'account_hash') = 64;
  assert public.shop_buy('rg_test_tonic', 300)->>'error' = 'not_enough';
  assert public.shop_buy('rg_glass_100', 0)->>'error' = 'not_for_riftglass';
  assert public.shop_buy('nope', 1)->>'error' = 'unknown_offer';
end $$;

reset role;
do $$ declare r jsonb; u uuid := '20000000-0000-0000-0000-00000000000a'; begin
  r := public._shop_credit(u, 'apple', 'A-1', 'de.chimora.game.glass.1000', 999);
  assert (r->>'ok')::boolean and (r->>'balance')::int = 1000, 'credited: ' || r::text;
  r := public._shop_credit(u, 'apple', 'A-1', 'de.chimora.game.glass.1000', 999);
  assert (r->>'duplicate')::boolean, 'the same receipt counts once';
  assert public._shop_balance(u) = 1000;
  assert public._shop_credit(u, 'google', 'G-x', 'de.chimora.game.nothing', 99)->>'error' = 'unknown_product';
  -- A child's store purchase is refused (the billing service refunds it in the store).
  assert public._shop_credit('20000000-0000-0000-0000-00000000000c', 'google', 'G-kid', 'de.chimora.game.glass.100', 99)->>'error' = 'age';
end $$;

set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ declare r jsonb; c jsonb; begin
  -- The client must send the price it showed; a changed price is refused.
  assert public.shop_buy('rg_test_tonic', 200)->>'error' = 'price_changed';
  r := public.shop_buy('rg_test_tonic', 300);
  assert (r->>'ok')::boolean and (r->>'balance')::int = 700, 'bought with Riftglass: ' || r::text;
  assert (public.shop_state()->>'pending')::int = 1;
  c := public.shop_claim();
  assert jsonb_array_length(c) = 1 and jsonb_array_length(c->0->'grants') = 2, 'items delivered once: ' || c::text;
  assert jsonb_array_length(public.shop_claim()) = 0, 'never twice';
  -- Once-per-account offer.
  assert public.shop_buy('rg_test_slot', 1500)->>'error' = 'not_enough';
end $$;

reset role;
select public._shop_credit('20000000-0000-0000-0000-00000000000a', 'google', 'G-2', 'de.chimora.game.glass.1000', 999);
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ declare r jsonb; begin
  assert (public.shop_buy('rg_test_slot', 1500)->>'ok')::boolean;
  assert public.shop_state()->'unlocks'->>'team_slot_6' = '1';
  assert public.shop_buy('rg_test_slot', 1500)->>'error' = 'offer_limit';
  assert (public.shop_state()->'bought'->>'rg_test_slot')::int = 1, 'offer limits are counted';
  -- History: newest first, store and Riftglass purchases.
  r := public.shop_history();
  assert jsonb_array_length(r) = 4, 'history: ' || r::text;
  assert r->0->>'offer' = 'rg_test_slot' and (r->0->>'rg')::int = 1500;
end $$;
reset role;
do $$ begin
  -- Every balance is the sum of the ledger (item 4132).
  assert not exists (select 1 from public.wallets w
    where w.balance <> (select coalesce(sum(amount), 0) from public.ledger l where l.user_id = w.user_id)), 'wallet = sum of ledger';
end $$;
set role authenticated;

-- Pack with a choice and a requirement (sealed Rifts come from the saves).
reset role;
do $$ declare r jsonb; u uuid := '20000000-0000-0000-0000-00000000000a'; begin
  update public.shop_offers set data = data || '{"rg_price": 500}' where id = 'rg_test_pack';
  perform public._shop_ledger_add(u, 1000, 'support', 'test');
end $$;
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ begin
  assert public.shop_buy('rg_test_pack', 500, 'rg_prism_ember')->>'error' = 'not_yet', 'needs a sealed Rift';
  perform public.save_put(1, '{"rifts": ["ashfall"], "party": []}', 'x', 0);
  assert public.shop_buy('rg_test_pack', 500)->>'error' = 'choice_needed', 'choice is made before buying';
  assert public.shop_buy('rg_test_pack', 500, 'rg_prism_volt')->>'error' = 'choice_needed', 'only listed choices';
  assert (public.shop_buy('rg_test_pack', 500, 'rg_prism_tide')->>'ok')::boolean;
  assert public.shop_claim()->0->'grants'->0->>'id' = 'rg_prism_tide';
end $$;

-- Monthly cap: a store purchase over the cap is credited, then the shop locks (item 4251).
reset role;
do $$ declare u uuid := '20000000-0000-0000-0000-00000000000b'; r jsonb; begin
  perform public._shop_credit(u, 'google', 'G-t1', 'de.chimora.game.glass.1000', 999);
  r := public._shop_credit(u, 'google', 'G-t2', 'de.chimora.game.glass.1000', 999);
  assert (r->>'ok')::boolean and (r->>'locked')::boolean, 'over the cap: credited but locked';
end $$;
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-00000000000b');
do $$ begin
  assert (public.shop_state()->>'locked')::boolean;
  assert public.shop_buy('rg_test_tonic', 300)->>'error' = 'limit_reached';
end $$;

-- Adults lower the cap at once and raise it only after 7 days, at most 300 EUR (item 4250).
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ declare r jsonb; begin
  assert (public.shop_set_limit(5000)->>'cap_cents')::int = 5000;
  r := public.shop_set_limit(20000);
  assert (r->>'cap_cents')::int = 5000 and (r->>'raise_to_cents')::int = 20000, 'raise waits: ' || r::text;
  assert (public.shop_state()->>'cap_cents')::int = 5000;
  assert public.shop_set_limit(40000)->>'error' = 'bad_limit';
end $$;
reset role;
update public.spend_limits set raise_at = now() - interval '1 minute' where user_id = '20000000-0000-0000-0000-00000000000a';
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ begin
  assert (public.shop_state()->>'cap_cents')::int = 20000, 'raised after the wait';
end $$;

-- Refunds take Riftglass back even when spent; the shop locks while the balance is below 0.
reset role;
do $$ declare u uuid := '20000000-0000-0000-0000-00000000000a'; b int; begin
  b := public._shop_balance(u);
  assert (public._shop_refund('apple', 'A-1', 'test')->>'ok')::boolean;
  assert public._shop_balance(u) = b - 1000;
  assert (public._shop_refund('apple', 'A-1')->>'duplicate')::boolean;
  assert (select status from public.purchases where store_transaction_id = 'A-1') = 'refunded';
  assert exists (select 1 from public.refunds where store_transaction_id = 'A-1');
  perform public._shop_refund('google', 'G-2');
  assert public._shop_balance(u) < 0;
end $$;
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ begin
  assert (public.shop_state()->>'locked')::boolean, 'negative balance locks the shop';
end $$;

-- Wayfarer Pass: status from the store, daily Riftglass, missed days paid later (at most 7).
reset role;
do $$ declare u uuid := '20000000-0000-0000-0000-00000000000a'; begin
  perform public._shop_ledger_add(u, 5000, 'support', 'test');
  assert (public._shop_sub_set(u, 'apple', 'P-1', 'de.chimora.game.pass', now() + interval '30 days', 'active', true)->>'ok')::boolean;
  assert public._shop_sub_set(u, 'apple', 'P-1', 'de.chimora.game.pass', now(), 'odd', true)->>'error' = 'bad_status';
end $$;
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ declare r jsonb; begin
  assert (public.shop_state()->>'pass_active')::boolean;
  r := public.shop_pass_daily();
  assert (r->>'added')::int = 30, 'first day: ' || r::text;
  assert (public.shop_pass_daily()->>'added')::int = 0, 'once a day';
end $$;
reset role;
update public.subscriptions set daily_paid_on = public._shop_today() - 20 where original_transaction_id = 'P-1';
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
do $$ begin
  assert (public.shop_pass_daily()->>'added')::int = 210, 'missed days paid, at most 7';
end $$;
reset role;
do $$ begin
  assert (public.shop_effects_for('20000000-0000-0000-0000-00000000000a')->>'pass_active')::boolean;
  perform public._shop_sub_set('20000000-0000-0000-0000-00000000000a', 'apple', 'P-1', 'de.chimora.game.pass', now() - interval '1 minute', 'expired', false);
  assert not (public.shop_effects_for('20000000-0000-0000-0000-00000000000a')->>'pass_active')::boolean, 'benefits end with the pass';
end $$;

-- Moving to a new phone takes the wallet, unlocks and history along.
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-00000000000a');
create temp table shop_code as select public.transfer_create()->>'code' as c, public.shop_state() as st;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000a2');
do $$ declare before jsonb := (select st from shop_code); after jsonb; begin
  perform public.hello(1);
  assert (public.transfer_claim((select c from shop_code))->>'ok')::boolean;
  after := public.shop_state();
  assert after->>'balance' = before->>'balance', 'balance moved: ' || after::text;
  assert after->'unlocks'->>'team_slot_6' = '1', 'unlocks moved';
  assert (after->>'band')::int = 18, 'age band moved';
  assert jsonb_array_length(public.shop_history()) = 5, 'history moved';
end $$;

-- Deleting the account ends everything (Riftglass expires only then, terms "Käufe im Spiel").
do $$ begin
  assert (public.delete_account()->>'ok')::boolean;
end $$;
reset role;
do $$ begin
  assert not exists (select 1 from public.wallets where user_id = '20000000-0000-0000-0000-0000000000a2');
  assert not exists (select 1 from public.purchases where user_id = '20000000-0000-0000-0000-0000000000a2');
end $$;
delete from public.shop_offers where id like 'rg_test_%';
