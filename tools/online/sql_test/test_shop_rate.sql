-- Shop (area 10, item 4148): at most 30 Riftglass purchases per hour and account.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000e7') on conflict do nothing;
insert into public.purchases (user_id, store, offer_id, rg_spent)
  select '20000000-0000-0000-0000-0000000000e7', 'riftglass', 'rg_ring_tonic', 100 from generate_series(1, 30);
do $$ begin perform set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000e7', false); end $$;
do $$ begin
  assert public.shop_buy('rg_ring_tonic', 100)->>'error' = 'slow_down', '31st purchase in an hour is refused';
end $$;
update public.purchases set at = now() - interval '2 hours' where user_id = '20000000-0000-0000-0000-0000000000e7';
do $$ begin
  assert coalesce(public.shop_buy('rg_ring_tonic', 100)->>'error', '') <> 'slow_down', 'an hour later it works again';
end $$;
do $$ begin perform set_config('request.jwt.claim.sub', '', false); end $$;
