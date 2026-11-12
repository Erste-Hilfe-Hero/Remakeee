-- Shop (area 10, item 4285): a gift carries the sender's greeting card motif, only with its unlock.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000e1'), ('20000000-0000-0000-0000-0000000000e2')
on conflict do nothing;
create temp table gc_codes (who text primary key, code text);
do $$ begin perform set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000e1', false); end $$;
insert into gc_codes values ('e1', public.hello(1)->'profile'->>'code');
do $$ begin perform set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000e2', false); end $$;
insert into gc_codes values ('e2', public.hello(1)->'profile'->>'code');
do $$ begin perform public.friend_request((select code from gc_codes where who = 'e1')); end $$;
do $$ begin perform set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000e1', false); end $$;
do $$ begin perform public.friend_respond((select code from gc_codes where who = 'e2'), true); end $$;
do $$ declare r jsonb; begin
  r := public.profile_set('Esk', 0, '', '{"motif": "moth"}');
  assert not (r->'card' ? 'motif'), 'no motif without the unlock';
end $$;
insert into public.entitlements (user_id, key) values ('20000000-0000-0000-0000-0000000000e1', 'gift_card_moth');
do $$ declare r jsonb; begin
  r := public.profile_set('Esk', 0, '', '{"motif": "moth", "frame": "star"}');
  assert r->'card'->>'motif' = 'moth', 'owned motif kept';
  assert not (r->'card' ? 'frame'), 'frame still needs its own unlock';
  assert (public.gift_send((select code from gc_codes where who = 'e2'))->>'ok')::boolean;
end $$;
do $$ begin perform set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000e2', false); end $$;
do $$ declare m jsonb; begin
  select x into m from jsonb_array_elements(public.mail_list()) x where x->>'kind' = 'gift' limit 1;
  assert m->>'motif' = 'moth', 'gift shows the motif';
end $$;
do $$ begin perform set_config('request.jwt.claim.sub', '', false); end $$;
