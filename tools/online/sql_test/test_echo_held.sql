-- KAMPF_PLAN_1000: an echo keeps a known held item; unknown text is dropped.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000f2') on conflict do nothing;
do $$ begin perform set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000f2', false); end $$;
do $$ declare t jsonb; begin
  perform public.hello(1);
  assert exists (select 1 from public.known_ids where kind = 'item' and id = 'iron_burr'), 'game data loads the items';
  perform public.team_set('[{"species":"Kindlop","level":12,"moves":[],"held":"iron_burr"},{"species":"Puddlet","level":9,"held":"my phone number"},{"species":"Zephlet","level":9,"held":5}]');
  select team into t from public.profiles where id = '20000000-0000-0000-0000-0000000000f2';
  assert t->0->>'held' = 'iron_burr', 'a known item stays';
  assert not (t->1 ? 'held'), 'free text is dropped';
  assert not (t->2 ? 'held'), 'only text';
  assert jsonb_array_length(t) = 3;
end $$;
do $$ begin perform set_config('request.jwt.claim.sub', '', false); end $$;
