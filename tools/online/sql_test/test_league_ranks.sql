-- Online 100, points 12-13 and 16-20: ranks, placement, shield, echo fallback, quit wait, season reward.
-- The same cases as tests/unit/test_league_ranks.gd.
insert into auth.users (id) values
  ('51000000-0000-0000-0000-00000000000a'), ('51000000-0000-0000-0000-00000000000b')
on conflict do nothing;
-- One transaction, rolled back at the end, so the other league tests keep their season and entries.
begin;
delete from public.league_fair_entries;
delete from public.league_open_entries;
delete from public.league_matches;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '51000000-0000-0000-0000-00000000000' || u, false)
$$;

-- Pure rules, against data/league_ranks.json.
do $$
declare r jsonb;
begin
  assert public._league_rank(1500, 4) = -1, 'placement first';
  assert public._league_rank(1500, 5) = 2 and public._league_rank(1399, 5) = 0 and public._league_rank(1400, 5) = 1;
  assert public._league_rank(2400, 9) = 6 and public._league_rank(800, 9) = 0;
  r := public._league_shield(1590, 1610, 10, 0);
  assert (r->>'rating')::float8 = 1610 and (r->>'shield')::int = 3, 'promotion gives the shield: ' || r::text;
  r := public._league_shield(1610, 1580, 11, 3);
  assert (r->>'rating')::float8 = 1600 and (r->>'shield')::int = 2, 'the shield holds the floor: ' || r::text;
  r := public._league_shield(1610, 1580, 11, 0);
  assert (r->>'rating')::float8 = 1580 and (r->>'shield')::int = 0, 'no shield, down it goes';
  r := public._league_shield(1500, 1700, 5, 0);
  assert (r->>'shield')::int = 0, 'leaving placement is no promotion';
  assert public._league_quit_wait(1, 0) = 0 and public._league_quit_wait(2, 0) = 60 and public._league_quit_wait(3, 10) = 110;
  assert public._league_quit_wait(30, 0) = 900;
end $$;

set role authenticated;
select pg_temp.as_user('a');
select public.hello(1);
select public.team_set('[{"species":"Kindlop","level":12,"moves":["Bowl Over"]}]');
select public.league_join('fair', '["Kindlop"]');
reset role;

-- Echo fallback: alone in the league, nothing before 45 seconds, then an unrated echo of the own team.
set role authenticated;
select pg_temp.as_user('a');
do $$
declare f jsonb;
begin
  f := public.league_find('fair', 40);
  assert not (f->>'found')::boolean, f::text;
  f := public.league_find('fair', 45);
  assert (f->>'found')::boolean and (f->>'echo')::boolean and not (f->>'rated')::boolean, f::text;
  assert (public.league_info('fair')->>'rank')::int = -1 and (public.league_info('fair')->>'placement_left')::int = 5;
end $$;
reset role;

-- Quit wait: matches given up after the grace time count; from the second one a wait follows.
update public.league_matches set created_at = now() - interval '2 minutes'
where user_id = '51000000-0000-0000-0000-00000000000a';
set role authenticated;
select pg_temp.as_user('a');
select public.league_find('fair', 45);
reset role;
update public.league_matches set created_at = now() - interval '2 minutes'
where user_id = '51000000-0000-0000-0000-00000000000a' and state = 'open';
set role authenticated;
select pg_temp.as_user('a');
select public.league_find('fair', 45);
do $$
declare f jsonb := public.league_find('fair', 45);
begin
  assert f->>'error' = 'quit_wait' and (f->>'wait')::int = 60, f::text;
end $$;
reset role;

-- Season reward: final rank of the finished season, once, into the bag, with title and frame.
insert into public.saves (user_id, slot, rev, data) values
  ('51000000-0000-0000-0000-00000000000a', 1, 1, '{"inventory": {}, "party": [], "storage": []}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;
update public.league_fair_entries set rating = 1720, games = 9
where user_id = '51000000-0000-0000-0000-00000000000a';
update public.league_seasons set starts_at = now() - interval '50 days', ends_at = now() - interval '1 minute'
where id = (select max(id) from public.league_seasons);
set role authenticated;
select pg_temp.as_user('a');
do $$
declare r jsonb; i jsonb;
begin
  i := public.league_info('fair');
  assert (i->>'reward_ready')::boolean and not (i->>'joined')::boolean, i::text;
  r := public.league_reward('fair', 1, 1);
  assert (r->>'ok')::boolean and r->>'title' = 'captain' and r->>'item' = 'revival_leaf' and (r->>'count')::int = 3, r::text;
  assert r->>'frame' like 'season_%_captain';
  assert public.league_reward('fair', 1, (r->>'rev')::int)->>'error' = 'no_reward', 'only once';
  assert public.league_info('fair')->'titles'->0->>'title' = 'captain';
  assert public.league_reward('open', 1, (r->>'rev')::int)->>'error' = 'no_reward', 'not in that league';
end $$;
reset role;
do $$ begin
  assert (select data->'inventory'->>'revival_leaf' from public.saves
    where user_id = '51000000-0000-0000-0000-00000000000a' and slot = 1) = '3';
end $$;
rollback;
