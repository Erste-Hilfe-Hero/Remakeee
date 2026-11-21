-- Shop (area 10, item 4284): a profile frame stays on the card only with its unlock.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000f4') on conflict do nothing;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000f4', false);
do $$ declare r jsonb; begin
  r := public.profile_set('Ilka', 0, '', '{"seals": 1, "frame": "star"}');
  assert not (r->'card' ? 'frame'), 'no frame without the unlock';
  assert (r->'card'->>'seals')::int = 1;
end $$;
insert into public.entitlements (user_id, key) values ('20000000-0000-0000-0000-0000000000f4', 'card_frame_star');
do $$ declare r jsonb; begin
  r := public.profile_set('Ilka', 0, '', '{"frame": "star"}');
  assert r->'card'->>'frame' = 'star', 'owned frame kept';
  r := public.profile_set('Ilka', 0, '', '{"frame": "ember"}');
  assert not (r->'card' ? 'frame'), 'other frame dropped';
  r := public.profile_set('Ilka', 0, '', '{"frame": 3}');
  assert not (r->'card' ? 'frame'), 'only text';
end $$;
select set_config('request.jwt.claim.sub', '', false);
