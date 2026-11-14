-- KAMPF_PLAN_1000 item 876: the rival echo's AI tier per rank (data/league_ranks.json echo_ai).
-- The same cases as tests/unit/test_league_echo_ai.gd.
insert into auth.users (id) values ('51000000-0000-0000-0000-0000000000e1') on conflict do nothing;
begin;
delete from public.league_fair_entries;
delete from public.league_open_entries;
delete from public.league_matches;

do $$ begin
  assert public._league_echo_ai(-1) = 1, 'placement counts as the first rank';
  assert public._league_echo_ai(0) = 1 and public._league_echo_ai(1) = 2 and public._league_echo_ai(3) = 2;
  assert public._league_echo_ai(4) = 3 and public._league_echo_ai(6) = 3 and public._league_echo_ai(99) = 3;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '51000000-0000-0000-0000-0000000000e1', false);
select public.hello(1);
select public.team_set('[{"species":"Kindlop","level":12,"moves":["Bowl Over"]}]');
select public.league_join('fair', '["Kindlop"]');
do $$
declare f jsonb;
begin
  f := public.league_find('fair', 45);
  assert (f->>'found')::boolean and (f->>'ai')::int = 1, 'a new player meets the gentlest echo: ' || f::text;
end $$;
reset role;
do $$ begin
  assert (select public._league_expect(m)->>'ai' from public.league_matches m
    where user_id = '51000000-0000-0000-0000-0000000000e1' and state = 'open') = '1', 'the referee replays the same tier';
end $$;

update public.league_fair_entries set rating = 1720, games = 9 where user_id = '51000000-0000-0000-0000-0000000000e1';
update public.league_matches set state = 'expired', expired_at = created_at where user_id = '51000000-0000-0000-0000-0000000000e1';
set role authenticated;
select set_config('request.jwt.claim.sub', '51000000-0000-0000-0000-0000000000e1', false);
do $$
declare f jsonb;
begin
  f := public.league_find('fair', 45);
  assert (f->>'found')::boolean and (f->>'ai')::int = 3, 'a Captain meets the master tier: ' || f::text;
end $$;
reset role;
rollback;
