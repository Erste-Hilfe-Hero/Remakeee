-- KAMPF_PLAN_1000 493, 512, 543, 553: climb boards, challenge rules on the card, Wayfarers in the
-- world goal. The same cases as tests/unit/test_climb_boards.gd.
insert into auth.users (id) values
  ('57000000-0000-0000-0000-00000000000a'), ('57000000-0000-0000-0000-00000000000b'),
  ('57000000-0000-0000-0000-00000000000c')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '57000000-0000-0000-0000-00000000000' || u, false)
$$;
create or replace function pg_temp.uid(u text) returns uuid language sql as $$
  select ('57000000-0000-0000-0000-00000000000' || u)::uuid
$$;
begin;
do $$ begin
  assert (select value @> '[{"kind":"wayfarers"}]'::jsonb and value @> '[{"kind":"battles"}]'::jsonb
    from public.server_config where key = 'goal_rotation'), 'Wayfarers join the goal rotation';
  assert (select count(*) from public.feature_flags where key = 'climb_board' and not enabled) = 1, 'climb board starts off';
end $$;
set role authenticated;
do $$
declare w text;
begin
  foreach w in array array['a', 'b', 'c'] loop
    perform pg_temp.as_user(w);
    perform public.hello(1);
  end loop;
  assert public.climb_submit('stair', 5)->>'error' = 'feature_off', 'off until switched on';
end $$;
reset role;
update public.feature_flags set enabled = true where key = 'climb_board';
insert into public.friendships (a, b, status, requested_by)
  values (pg_temp.uid('a'), pg_temp.uid('b'), 'accepted', pg_temp.uid('a')) on conflict do nothing;
set role authenticated;
do $$
declare r jsonb;
begin
  perform pg_temp.as_user('a');
  assert (public.climb_submit('stair', 12)->>'ok')::boolean;
  assert (public.climb_submit('stair', 9)->>'ok')::boolean, 'a lower floor is fine but does not count';
  assert public.climb_submit('stair', 31)->>'error' = 'implausible', 'the stair has 30 floors';
  assert public.climb_submit('stair', 0)->>'error' = 'implausible';
  assert public.climb_submit('roof', 3)->>'error' = 'bad_kind';
  assert (public.climb_submit('tower', 140)->>'ok')::boolean;
  assert public.climb_submit('tower', 1001)->>'error' = 'implausible';
  perform pg_temp.as_user('b');
  perform public.climb_submit('stair', 20);
  perform pg_temp.as_user('c');
  perform public.climb_submit('stair', 30);
  perform pg_temp.as_user('a');
  r := public.climb_board('stair', true);
  assert (r->>'ok')::boolean and jsonb_array_length(r->'rows') = 2, r::text;
  assert r->'rows'->0->>'name' <> '' and (r->'rows'->0->>'score')::int = 20, 'friend first with name';
  assert (r->'rows'->1->>'score')::int = 12 and (r->'rows'->1->>'me')::boolean, 'best floor counts';
  r := public.climb_board('stair', false);
  assert jsonb_array_length(r->'rows') = 3 and (r->'rows'->0->>'score')::int = 30, r::text;
  assert r->'rows'->0->>'name' = '', 'strangers stay nameless';
  r := public.climb_board('tower', false);
  assert jsonb_array_length(r->'rows') = 1 and (r->'rows'->0->>'score')::int = 140, r::text;
  assert public.climb_board('roof', true)->>'error' = 'bad_kind';
  -- 493: the count of challenge rules on the card, 1..20, never text.
  r := public.profile_set('Tia', 0, '', '{"rules": 3, "seen": 4}');
  assert (r->'card'->>'rules')::int = 3 and (r->'card'->>'seen')::int = 4, r::text;
  r := public.profile_set('Tia', 0, '', '{"rules": 99}');
  assert (r->'card'->>'rules')::int = 20, 'capped';
  r := public.profile_set('Tia', 0, '', '{"rules": 0}');
  assert not (r->'card' ? 'rules'), 'no rules, no badge';
  r := public.profile_set('Tia', 0, '', '{"rules": "many"}');
  assert not (r->'card' ? 'rules'), 'only a number';
end $$;
reset role;
-- 543: Wayfarer wins count when the week's goal is "wayfarers".
delete from public.community_contrib where week = public._week();
delete from public.community_goals where week = public._week();
update public.server_config set value = '[{"kind":"wayfarers","target":30}]' where key = 'goal_rotation';
set role authenticated;
do $$
declare g jsonb;
begin
  perform pg_temp.as_user('a');
  g := public.community_add('wayfarers', 1);
  assert g->>'kind' = 'wayfarers' and (g->>'total')::int = 1, g::text;
  g := public.community_add('battles', 1);
  assert (g->>'total')::int = 1, 'other kinds do not count this week';
end $$;
reset role;
rollback;
