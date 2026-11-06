-- Billing service access (plan area 10, items 4101-4140). The billing service (server/billing)
-- checks Apple and Google receipts and then calls these functions as its own database user
-- chimora_billing. That user may run only these four functions; it cannot read any table.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'chimora_billing') then
    create role chimora_billing nologin;
  end if;
end $$;

-- Credits a checked store purchase. The Euro amount for the monthly limit is the offer's store
-- tier (data/shop.json eur_cents), so the service never has to know prices.
create or replace function public._billing_credit(p_uid uuid, p_store text, p_txn text, p_product text,
    p_choice text default null) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  cents int;
begin
  if p_store not in ('apple', 'google') or coalesce(p_txn, '') = '' then
    return jsonb_build_object('ok', false, 'error', 'bad_receipt');
  end if;
  if not exists (select 1 from auth.users where id = p_uid) then
    return jsonb_build_object('ok', false, 'error', 'unknown_account');
  end if;
  select (data->>'eur_cents')::int into cents from public.shop_offers where product_id = p_product;
  return public._shop_credit(p_uid, p_store, p_txn, p_product, coalesce(cents, 0), p_choice);
end $$;

create or replace function public._billing_refund(p_store text, p_txn text, p_note text default '') returns jsonb
language sql volatile security definer set search_path = public as $$
  select public._shop_refund(p_store, p_txn, p_note)
$$;

create or replace function public._billing_sub_set(p_uid uuid, p_store text, p_original_txn text, p_product text,
    p_expires timestamptz, p_status text, p_auto_renew boolean) returns jsonb
language sql volatile security definer set search_path = public as $$
  select public._shop_sub_set(p_uid, p_store, p_original_txn, p_product, p_expires, p_status, p_auto_renew)
$$;

-- The account a pass belongs to, for store messages that carry no account (Google renewals).
create or replace function public._billing_sub_user(p_store text, p_original_txn text) returns uuid
language sql stable security definer set search_path = public as $$
  select user_id from public.subscriptions where store = p_store and original_transaction_id = p_original_txn
$$;

revoke all on function public._billing_credit(uuid, text, text, text, text), public._billing_refund(text, text, text),
  public._billing_sub_set(uuid, text, text, text, timestamptz, text, boolean), public._billing_sub_user(text, text)
  from public, anon, authenticated;
grant usage on schema public to chimora_billing;
grant execute on function public._billing_credit(uuid, text, text, text, text), public._billing_refund(text, text, text),
  public._billing_sub_set(uuid, text, text, text, timestamptz, text, boolean), public._billing_sub_user(text, text)
  to chimora_billing;
