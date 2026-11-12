-- Plan area 7: leagues (items 2730-2735, 2753-2755, 2769-2772, 2786, 2691, 2941).
insert into auth.users (id) values
  ('50000000-0000-0000-0000-00000000000a'), ('50000000-0000-0000-0000-00000000000b'),
  ('50000000-0000-0000-0000-00000000000c')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;
create temp table lg (k text primary key, v text);
grant all on lg to authenticated, chimora_referee;

-- Glicko-2 and tiers (2770, 2771), checked against a reference implementation.
do $$
declare r jsonb;
begin
  r := public._league_rate(1500, 350, 0.06, 1500, 350, 1);
  assert abs((r->>'rating')::float8 - 1662.311) < 0.01 and abs((r->>'rd')::float8 - 290.319) < 0.01, r::text;
  r := public._league_rate(1500, 350, 0.06, 1500, 350, 0);
  assert abs((r->>'rating')::float8 - 1337.689) < 0.01, r::text;
  r := public._league_rate(1500, 200, 0.06, 1400, 30, 1);
  assert abs((r->>'rating')::float8 - 1563.564) < 0.01 and abs((r->>'rd')::float8 - 175.403) < 0.01, r::text;
  r := public._league_rate(1700, 80, 0.06, 1300, 100, 0);
  assert abs((r->>'rating')::float8 - 1668.426) < 0.01 and abs((r->>'vol')::float8 - 0.0600085) < 0.00001, r::text;
  assert public._league_tier(1500) = 4 and public._league_tier(900) = 0 and public._league_tier(3000) = 14;
  assert public._league_tier(1269.9) = 0 and public._league_tier(1270) = 1;
end $$;

-- Learnable moves up to Ring 50, with earlier forms (2733), and the default moves.
do $$ begin
  assert 'Kiln Strike' = any(public._league_learnable('Kindlop', 50));
  assert not ('Kiln Strike' = any(public._league_learnable('Kindlop', 19)));
  assert 'Dusk Rake' = any(public._league_learnable('Smoldrake', 9)), 'earlier form moves count';
  assert public._league_default_moves('Kindlop', 50) = '["Glow Knuckle", "Cinder Breath", "Kiln Strike", "Smoulder"]'::jsonb,
    public._league_default_moves('Kindlop', 50)::text;
  assert public._league_fair_row('Kindlop', '["Kiln Strike", "Fly Away", "Bowl Over", "Kiln Strike"]')
    = '{"species": "Kindlop", "level": 50, "moves": ["Kiln Strike", "Bowl Over"]}'::jsonb, 'only learnable moves, no doubles';
  assert public._league_fair_row('Kindlop', '[]')->'moves' = public._league_default_moves('Kindlop', 50);
end $$;

set role authenticated;
select pg_temp.as_user('50000000-0000-0000-0000-00000000000a');
insert into lg values ('a', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species":"Kindlop","level":12,"moves":["Bowl Over"]},{"species":"Puddlet","level":9,"moves":[]}]');
select pg_temp.as_user('50000000-0000-0000-0000-00000000000b');
insert into lg values ('b', public.hello(1)->'profile'->>'code');
select public.team_set('[{"species":"Kindlop","level":60,"moves":["Kiln Strike","Cinder Breath"]},{"species":"Smoldrake","level":40,"moves":[]}]');

-- Joining: errors, then a fair team that is the same for everyone (2731, 2734, 2735).
select pg_temp.as_user('50000000-0000-0000-0000-00000000000a');
do $$
declare ta jsonb;
begin
  assert public.league_join('gold', '[]')->>'error' = 'bad_league';
  assert public.league_join('fair', '[]')->>'error' = 'empty_team';
  assert public.league_join('fair', '["Nobody"]')->>'error' = 'unknown_species';
  assert public.league_join('fair', '["Smoldrake"]')->>'error' = 'not_in_team';
  assert public.league_join('fair', '["Kindlop", "Kindlop"]')->>'error' = 'duplicate_species';
  assert public.league_find('fair', 0)->>'error' = 'not_joined';
  ta := public.league_join('fair', '[{"species": "Kindlop", "moves": ["Kiln Strike", "Cinder Breath"]}, "Puddlet"]')->'team';
  assert ta->0 = '{"species": "Kindlop", "level": 50, "moves": ["Kiln Strike", "Cinder Breath"]}'::jsonb, ta::text;
  assert (ta->1->>'level')::int = 50;
  insert into lg values ('team_a', (ta->0)::text);
  assert (public.league_info('fair')->>'joined')::boolean;
  assert (public.league_info('fair')->>'tier')::int = 4;
  assert public.league_info('fair')->>'state' = 'running';
  -- The open league uses the real Ring (2754).
  ta := public.league_join('open', '["Kindlop"]')->'team';
  assert (ta->0->>'level')::int = 12 and ta->0->'moves' = '["Bowl Over"]'::jsonb, ta::text;
end $$;
select pg_temp.as_user('50000000-0000-0000-0000-00000000000b');
do $$
declare tb jsonb;
begin
  tb := public.league_join('fair', '[{"species": "Kindlop", "moves": ["Kiln Strike", "Cinder Breath"]}, {"species": "Smoldrake", "moves": ["Dusk Rake"]}]')->'team';
  assert (tb->0)::text = (select v from lg where k = 'team_a'), 'same Spirling, other account, other Ring: same fair values (2735)';
  assert tb->1->'moves' = '["Dusk Rake"]'::jsonb, 'move of the earlier form';
  assert (public.league_join('open', '["Kindlop"]')->'team'->0->>'level')::int = 60;
end $$;

-- Players cannot read the league tables.
do $$ begin
  begin
    perform * from public.league_fair_entries;
    raise exception 'entries must not be readable';
  exception when insufficient_privilege then null;
  end;
  begin
    perform * from public.league_matches;
    raise exception 'matches must not be readable';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Opponent search and a league battle (2772, 2691).
select pg_temp.as_user('50000000-0000-0000-0000-00000000000a');
do $$
declare f jsonb; r jsonb;
begin
  f := public.league_find('fair', 0);
  assert (f->>'found')::boolean and (f->>'range')::int = 100, f::text;
  assert f->'teams'->1->0->>'species' = 'Kindlop';
  assert (public.league_find('fair', 25)->>'range')::int = 200, '50 more every 10 seconds';
  assert (public.league_find('fair', 999)->>'range')::int = 400, 'at most 400';
  f := public.league_find('fair', 0);
  insert into lg values ('match', f->>'match_id');
  insert into lg values ('seed', f->>'seed');
  assert public.battle_submit('league_fair', '999999', '{"teams": []}', '{}')->>'error' = 'no_such_match';
  assert public.battle_submit('league_open', f->>'match_id', '{"teams": []}', '{}')->>'error' = 'no_such_match', 'other league';
  r := public.battle_submit('league_fair', f->>'match_id', '{"seed": 1, "teams": [[{"species": "Kindlop", "level": 60}], []], "inputs": []}',
    '{"winner": "player", "hp": [[1], [0]], "rounds": 2, "expect": {"seed": 1}}');
  assert (r->>'ok')::boolean, r::text;
  insert into lg values ('battle', r->>'battle_id');
  assert public.battle_submit('league_fair', f->>'match_id', '{"teams": []}', '{}')->>'error' = 'match_closed', 'one battle per match';
  -- Echo duels may not bring their own expectation.
  r := public.battle_submit('echo_duel', '', '{"teams": []}', '{"winner": "player", "expect": {"seed": 5}}');
  insert into lg values ('duel', r->>'battle_id');
end $$;
reset role;
do $$ begin
  assert (select claim->'expect'->>'seed' from public.battle_queue where battle_id = (select v::bigint from lg where k = 'battle'))
    = (select v from lg where k = 'seed'), 'the server seed, not the uploaded one';
  assert (select claim->'expect'->'teams'->0->0->>'level' from public.battle_queue where battle_id = (select v::bigint from lg where k = 'battle')) = '50';
  assert not (select claim ? 'expect' from public.battle_queue where battle_id = (select v::bigint from lg where k = 'duel'));
  assert (select count(*) from public.league_matches where user_id = '50000000-0000-0000-0000-00000000000a' and state = 'open') = 0,
    'older open matches expire';
end $$;
-- Nothing counts before the referee; after "ok" the rating moves.
do $$ begin
  assert (select games from public.league_fair_entries where user_id = '50000000-0000-0000-0000-00000000000a') = 0;
end $$;
set role chimora_referee;
insert into public.battle_results (battle_id, verdict, detail)
select v::bigint, 'ok', '{"winner": "player", "rounds": 2}' from lg where k = 'battle';
reset role;
do $$
declare e record;
begin
  select * into e from public.league_fair_entries where user_id = '50000000-0000-0000-0000-00000000000a';
  assert e.games = 1 and e.wins = 1 and abs(e.rating - 1662.311) < 0.01, 'rated once: ' || e.rating;
  assert (select rating from public.league_fair_entries where user_id = '50000000-0000-0000-0000-00000000000b') = 1500, 'the echo owner is not rated';
  assert (select rating from public.league_open_entries where user_id = '50000000-0000-0000-0000-00000000000a') = 1500, 'leagues are separate';
  assert (select state from public.league_matches where battle_id = (select v::bigint from lg where k = 'battle')) = 'done';
end $$;

-- A mismatch counts nothing.
set role authenticated;
select pg_temp.as_user('50000000-0000-0000-0000-00000000000a');
do $$
declare f jsonb := public.league_find('fair', 99);
begin
  insert into lg values ('battle2', public.battle_submit('league_fair', f->>'match_id', '{"teams": []}', '{"winner": "player"}')->>'battle_id');
end $$;
reset role;
set role chimora_referee;
insert into public.battle_results (battle_id, verdict, detail) select v::bigint, 'mismatch', '{}' from lg where k = 'battle2';
reset role;
do $$ begin
  assert (select games from public.league_fair_entries where user_id = '50000000-0000-0000-0000-00000000000a') = 1, 'mismatch not rated';
end $$;

-- Closing time: the last 30 minutes are not rated (2786); a paused season takes no entries.
update public.league_seasons set ends_at = now() + interval '10 minutes';
set role authenticated;
select pg_temp.as_user('50000000-0000-0000-0000-00000000000a');
do $$
declare f jsonb;
begin
  assert public.league_info('fair')->>'state' = 'closing';
  f := public.league_find('fair', 99);
  assert not (f->>'rated')::boolean, f::text;
  insert into lg values ('battle3', public.battle_submit('league_fair', f->>'match_id', '{"teams": []}', '{"winner": "player"}')->>'battle_id');
end $$;
reset role;
set role chimora_referee;
insert into public.battle_results (battle_id, verdict, detail) select v::bigint, 'ok', '{"winner": "player"}' from lg where k = 'battle3';
reset role;
do $$ begin
  assert (select games from public.league_fair_entries where user_id = '50000000-0000-0000-0000-00000000000a') = 1, 'closing: not rated';
end $$;
update public.league_seasons set state = 'paused';
set role authenticated;
do $$ begin
  assert public.league_join('fair', '["Kindlop"]')->>'error' = 'season_paused';
  assert public.league_info('fair')->>'state' = 'paused';
end $$;
reset role;
-- A finished season: the next one starts by itself.
update public.league_seasons set state = 'running', starts_at = now() - interval '50 days', ends_at = now() - interval '1 day';
set role authenticated;
do $$ begin
  assert not (public.league_info('fair')->>'joined')::boolean, 'new season, new entry';
  assert public.league_info('fair')->>'state' = 'running';
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.league_seasons) >= 2;
end $$;

-- Blocked players never meet (item 2900 for the search), and a switched-off league answers feature_off.
set role authenticated;
select pg_temp.as_user('50000000-0000-0000-0000-00000000000a');
select public.league_join('fair', '["Kindlop"]');
select public.block((select v from lg where k = 'b'));
select pg_temp.as_user('50000000-0000-0000-0000-00000000000b');
select public.league_join('fair', '["Kindlop"]');
do $$ begin
  assert not (public.league_find('fair', 30)->>'found')::boolean, 'blocked: no match';
end $$;
reset role;
update public.feature_flags set enabled = false where key = 'league_open';
set role authenticated;
do $$ begin
  assert public.league_info('open')->>'error' = 'feature_off';
  assert public.league_join('open', '["Kindlop"]')->>'error' = 'feature_off';
end $$;
reset role;
update public.feature_flags set enabled = true where key = 'league_open';

-- Deleting an account removes its league rows.
do $$ begin
  delete from auth.users where id = '50000000-0000-0000-0000-00000000000a';
  assert not exists (select 1 from public.league_fair_entries where user_id = '50000000-0000-0000-0000-00000000000a');
  assert not exists (select 1 from public.league_matches where user_id = '50000000-0000-0000-0000-00000000000a');
end $$;
