-- KAMPF_PLAN_1000: a title on the Wanderer card only from the game's list (known_ids kind 'title').
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000f1') on conflict do nothing;
do $$ begin perform set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000f1', false); end $$;
do $$ declare r jsonb; begin
  perform public.hello(1);
  assert exists (select 1 from public.known_ids where kind = 'title' and id = 'First Pick'), 'game data loads the titles';
  r := public.profile_set('Tia', 0, '', '{"title": "First Pick", "seen": 3}');
  assert r->'card'->>'title' = 'First Pick', 'a known title is kept';
  assert (r->'card'->>'seen')::int = 3, 'the numbers stay';
  r := public.profile_set('Tia', 0, '', '{"title": "Queen of Everything"}');
  assert not (r->'card' ? 'title'), 'free text is dropped';
  r := public.profile_set('Tia', 0, '', '{"title": 7}');
  assert not (r->'card' ? 'title'), 'only text';
  delete from public.known_ids where kind = 'title';
  r := public.profile_set('Tia', 0, '', '{"title": "First Pick"}');
  assert not (r->'card' ? 'title'), 'no title list loaded, no title';
end $$;
insert into public.known_ids (kind, id) values ('title', 'First Pick') on conflict do nothing;
do $$ begin perform set_config('request.jwt.claim.sub', '', false); end $$;
