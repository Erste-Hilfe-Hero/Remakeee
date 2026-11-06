-- Billing service user (area 10, server/billing): only the four _billing_* functions, no tables.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000b1') on conflict do nothing;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000b1', false);
select public.shop_set_age(1990, 3);
select set_config('request.jwt.claim.sub', '', false);

set role chimora_billing;
do $$
declare r jsonb; u uuid := '20000000-0000-0000-0000-0000000000b1';
begin
  r := public._billing_credit(u, 'google', 'tok-b1', 'de.chimora.game.glass.500');
  assert (r->>'ok')::boolean, r::text;
  assert (r->>'balance')::int = 500, r::text;
  r := public._billing_credit(u, 'google', 'tok-b1', 'de.chimora.game.glass.500');
  assert (r->>'duplicate')::boolean, 'the same receipt counts once';
  assert public._billing_credit(u, 'local', 'x', 'de.chimora.game.glass.500')->>'error' = 'bad_receipt', 'only real stores';
  assert public._billing_credit('20000000-0000-0000-0000-0000000000ff', 'apple', 'x', 'de.chimora.game.glass.500')->>'error'
    = 'unknown_account';
  assert public._billing_credit(u, 'apple', 'a-1', 'de.chimora.game.nothing')->>'error' = 'unknown_product';
  r := public._billing_sub_set(u, 'google', 'sub-tok', 'de.chimora.game.pass', now() + interval '30 days', 'active', true);
  assert (r->>'ok')::boolean, r::text;
  assert public._billing_sub_user('google', 'sub-tok') = u;
  r := public._billing_refund('google', 'tok-b1', 'test');
  assert (r->>'ok')::boolean, r::text;
  assert (r->>'balance')::int = 0, 'refund takes the Riftglass back';
  begin
    perform count(*) from public.purchases;
    raise exception 'billing user must not read tables';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public._shop_credit(u, 'apple', 'y', 'de.chimora.game.glass.500', 99, null);
    raise exception 'billing user must not call _shop_credit directly';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

do $$ begin
  assert (select eur_cents from public.purchases where store_transaction_id = 'tok-b1') = 499, 'Euro amount from the offer';
end $$;
