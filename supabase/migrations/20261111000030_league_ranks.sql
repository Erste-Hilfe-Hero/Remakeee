-- Online 100, points 12-13 and 16-20: seven league ranks, placement battles, a demotion shield
-- after a promotion, an echo opponent after 45 seconds of searching, a wait after leaving matches,
-- and a season reward with title and frame. Values in server_config.league_ranks, filled from
-- data/league_ranks.json by tools/online/game_data_sql.py. LocalBackend and LeagueRules.gd do the same.

alter table public.league_fair_entries add column if not exists shield int not null default 0;
alter table public.league_open_entries add column if not exists shield int not null default 0;
-- When a found match was given up for a new search; quick repeats within quit_grace do not count.
alter table public.league_matches add column if not exists expired_at timestamptz;

create table if not exists public.league_awards (
  season int not null,
  league text not null check (league in ('fair', 'open')),
  user_id uuid not null references auth.users (id) on delete cascade,
  rank int not null,
  title text not null,
  claimed_at timestamptz not null default now(),
  primary key (season, league, user_id)
);
alter table public.league_awards enable row level security;
revoke all on public.league_awards from public, anon, authenticated;

create or replace function public._league_ranks() returns jsonb
language sql stable as $$
  select public._config('league_ranks', '{"placement_games": 5, "shield_games": 3, "echo_after": 45,
    "quit_free": 2, "quit_grace": 30, "quit_wait": 60, "quit_wait_max": 900, "ranks": [{"id": "apprentice", "floor": 0,
    "reward": {"item": "tonic", "count": 3}}]}'::jsonb)
$$;

-- Rank 0-6, or -1 while placement battles are left (LeagueRules.rank).
create or replace function public._league_rank(p_rating float8, p_games int) returns int
language plpgsql stable as $$
declare
  c jsonb := public._league_ranks();
  out_rank int := 0;
  i int;
begin
  if p_games < coalesce((c->>'placement_games')::int, 5) then return -1; end if;
  for i in 0 .. jsonb_array_length(c->'ranks') - 1 loop
    if p_rating >= (c->'ranks'->i->>'floor')::float8 then out_rank := i; end if;
  end loop;
  return out_rank;
end $$;

-- Rating and shield after one rated battle (LeagueRules.after_battle).
create or replace function public._league_shield(p_old float8, p_new float8, p_games_after int, p_shield int) returns jsonb
language plpgsql stable as $$
declare
  c jsonb := public._league_ranks();
  old_rank int := public._league_rank(p_old, p_games_after - 1);
  r float8 := p_new;
  sh int := p_shield;
  fl float8;
begin
  if sh > 0 and old_rank >= 0 then
    fl := (c->'ranks'->old_rank->>'floor')::float8;
    if r < fl then r := fl; end if;
    sh := sh - 1;
  end if;
  if old_rank >= 0 and public._league_rank(r, p_games_after) > old_rank then
    sh := coalesce((c->>'shield_games')::int, 3);
  end if;
  return jsonb_build_object('rating', r, 'shield', sh);
end $$;

-- Seconds still to wait after leaving matches (LeagueRules.quit_wait).
create or replace function public._league_quit_wait(p_quits int, p_since int) returns int
language plpgsql stable as $$
declare
  c jsonb := public._league_ranks();
  fr int := coalesce((c->>'quit_free')::int, 2);
  w int;
begin
  if p_quits < fr then return 0; end if;
  w := least(coalesce((c->>'quit_wait')::int, 60) * power(2, least(p_quits - fr, 10))::int,
    coalesce((c->>'quit_wait_max')::int, 900));
  return greatest(0, w - p_since);
end $$;

-- The final rank of the last finished season, or -1 when there is none or it was claimed.
create or replace function public._league_reward_due(p_user uuid, p_league text) returns int
language plpgsql stable as $$
declare
  prev int;
  e jsonb;
begin
  select id into prev from public.league_seasons where ends_at <= now() order by id desc limit 1;
  if prev is null then return -1; end if;
  if exists (select 1 from public.league_awards where season = prev and league = p_league and user_id = p_user) then
    return -1;
  end if;
  e := public._league_entry(p_league, prev, p_user);
  if e is null then return -1; end if;
  return public._league_rank((e->>'rating')::float8, (e->>'games')::int);
end $$;

create or replace function public.league_info(p_league text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._league_ok(p_league);
  s public.league_seasons;
  e jsonb;
  pg int := coalesce((public._league_ranks()->>'placement_games')::int, 5);
begin
  if err is not null then return public._fail(err); end if;
  perform public._ensure_profile(u);
  s := public._league_season();
  e := public._league_entry(p_league, s.id, u);
  return jsonb_build_object('ok', true, 'season', s.id, 'ends_at', extract(epoch from s.ends_at)::bigint,
    'state', public._league_state(s), 'rules_version', s.rules_version,
    'ring', case when p_league = 'fair' then public._config_int('league_fair_ring', 50) else public._config_int('level_max', 60) end,
    'joined', e is not null,
    'team', coalesce(e->'team', '[]'::jsonb),
    'tier', case when e is null then null else public._league_tier((e->>'rating')::float8) end,
    'games', coalesce((e->>'games')::int, 0), 'wins', coalesce((e->>'wins')::int, 0),
    'rank', case when e is null then -1 else public._league_rank((e->>'rating')::float8, (e->>'games')::int) end,
    'placement_left', greatest(0, pg - coalesce((e->>'games')::int, 0)),
    'shield', coalesce((e->>'shield')::int, 0),
    'reward_ready', public._league_reward_due(u, p_league) >= 0,
    'titles', coalesce((select jsonb_agg(jsonb_build_object('season', a.season, 'league', a.league, 'rank', a.rank,
      'title', a.title) order by a.season) from public.league_awards a where a.user_id = u), '[]'::jsonb));
end $$;

-- Opponent search with the quit wait (point 20) and the echo fallback (point 18): after echo_after
-- seconds any rating is fine, and with nobody at all the player's own team is the echo (not rated).
create or replace function public.league_find(p_league text, p_waited int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._league_ok(p_league);
  s public.league_seasons;
  me jsonb;
  opp record;
  span float8;
  m bigint;
  sd bigint := floor(random() * 2147483647)::bigint;
  wide boolean := coalesce(p_waited, 0) >= coalesce((public._league_ranks()->>'echo_after')::int, 45);
  qn int;
  ql timestamptz;
  w int;
  oteam jsonb;
  orating float8;
  rated boolean;
begin
  if err is not null then return public._fail(err); end if;
  s := public._league_season();
  if public._league_state(s) = 'paused' then return public._fail('season_paused'); end if;
  me := public._league_entry(p_league, s.id, u);
  if me is null then return public._fail('not_joined'); end if;
  select count(*), max(expired_at) into qn, ql from public.league_matches
  where user_id = u and state = 'expired' and created_at > now() - interval '1 day'
    and expired_at >= created_at + make_interval(secs => coalesce((public._league_ranks()->>'quit_grace')::int, 30));
  w := public._league_quit_wait(qn, coalesce(extract(epoch from now() - ql)::int, 0));
  if w > 0 then return public._fail('quit_wait') || jsonb_build_object('wait', w); end if;
  if not public._rate_ok(u, 'league_find', 240) then return public._fail('slow_down'); end if;
  span := least(public._config_int('league_search_start', 100)
    + public._config_int('league_search_step', 50) * floor(greatest(coalesce(p_waited, 0), 0) / 10.0),
    public._config_int('league_search_max', 400));
  if p_league = 'fair' then
    select user_id, team, rating into opp from public.league_fair_entries e
    where e.season = s.id and e.user_id <> u and not public._blocked(u, e.user_id)
      and (wide or abs(e.rating - (me->>'rating')::float8) <= span)
    order by abs(e.rating - (me->>'rating')::float8), random() limit 1;
  else
    select user_id, team, rating into opp from public.league_open_entries e
    where e.season = s.id and e.user_id <> u and not public._blocked(u, e.user_id)
      and (wide or abs(e.rating - (me->>'rating')::float8) <= span)
    order by abs(e.rating - (me->>'rating')::float8), random() limit 1;
  end if;
  if opp.user_id is null and not wide then
    return jsonb_build_object('ok', true, 'found', false, 'range', span);
  end if;
  oteam := coalesce(opp.team, me->'team');
  orating := coalesce(opp.rating, (me->>'rating')::float8);
  rated := public._league_state(s) = 'running' and opp.user_id is not null;
  update public.league_matches set state = 'expired', expired_at = now() where user_id = u and state = 'open';
  insert into public.league_matches (league, season, user_id, opponent, seed, teams, rated)
  values (p_league, s.id, u, opp.user_id, sd, jsonb_build_array(me->'team', oteam), rated)
  returning id into m;
  return jsonb_build_object('ok', true, 'found', true, 'match_id', m, 'seed', sd,
    'teams', jsonb_build_array(me->'team', oteam), 'ai', public._config_int('league_ai', 2),
    'opponent_tier', public._league_tier(orating), 'range', span, 'rated', rated,
    'echo', opp.user_id is null or abs(orating - (me->>'rating')::float8) > span);
end $$;

-- Rating with placement and the demotion shield (points 16, 17).
create or replace function public._league_apply(p_battle_id bigint, p_detail jsonb) returns void
language plpgsql volatile as $$
declare
  m public.league_matches;
  me jsonb;
  opp jsonb;
  sc float8;
  nr jsonb;
  sh jsonb;
begin
  select * into m from public.league_matches where battle_id = p_battle_id and state = 'submitted' for update;
  if not found then return; end if;
  sc := case p_detail->>'winner' when 'player' then 1 else 0 end;
  update public.league_matches set state = 'done', score = sc where id = m.id;
  if not m.rated then return; end if;
  me := public._league_entry(m.league, m.season, m.user_id);
  opp := public._league_entry(m.league, m.season, m.opponent);
  if me is null then return; end if;
  nr := public._league_rate((me->>'rating')::float8, (me->>'rd')::float8, (me->>'vol')::float8,
    coalesce((opp->>'rating')::float8, 1500), coalesce((opp->>'rd')::float8, 350), sc);
  sh := public._league_shield((me->>'rating')::float8, (nr->>'rating')::float8, (me->>'games')::int + 1,
    coalesce((me->>'shield')::int, 0));
  if m.league = 'fair' then
    update public.league_fair_entries set rating = (sh->>'rating')::float8, shield = (sh->>'shield')::int, rd = (nr->>'rd')::float8,
      vol = (nr->>'vol')::float8, games = games + 1, wins = wins + sc::int, updated_at = now()
    where season = m.season and user_id = m.user_id;
  else
    update public.league_open_entries set rating = (sh->>'rating')::float8, shield = (sh->>'shield')::int, rd = (nr->>'rd')::float8,
      vol = (nr->>'vol')::float8, games = games + 1, wins = wins + sc::int, updated_at = now()
    where season = m.season and user_id = m.user_id;
  end if;
end $$;

-- Season reward and title (points 13, 19): items into the bag of the stored save, title kept here.
create or replace function public.league_reward(p_league text, p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._league_ok(p_league);
  rk int;
  prev int;
  rw jsonb;
  t text;
  r jsonb;
begin
  if err is not null then return public._fail(err); end if;
  perform public._ensure_profile(u);
  perform public._league_season();
  rk := public._league_reward_due(u, p_league);
  if rk < 0 then return public._fail('no_reward'); end if;
  select id into prev from public.league_seasons where ends_at <= now() order by id desc limit 1;
  rw := public._league_ranks()->'ranks'->rk;
  t := rw->>'id';
  r := public._trade_bag(u, p_slot, p_rev, jsonb_build_object(rw->'reward'->>'item', (rw->'reward'->>'count')::int));
  if not (r->>'ok')::boolean then return r; end if;
  insert into public.league_awards (season, league, user_id, rank, title) values (prev, p_league, u, rk, t);
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'item', rw->'reward'->>'item',
    'count', (rw->'reward'->>'count')::int, 'rank', rk, 'title', t, 'frame', format('season_%s_%s', prev, t),
    'bag', jsonb_build_object(rw->'reward'->>'item', (rw->'reward'->>'count')::int));
end $$;

revoke all on function public._league_ranks(), public._league_rank(float8, int), public._league_shield(float8, float8, int, int),
  public._league_quit_wait(int, int), public._league_reward_due(uuid, text), public._league_apply(bigint, jsonb)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.league_info(text), public.league_find(text, int), public.league_reward(text, int, int)
  from public, anon, chimora_referee;
grant execute on function public.league_info(text), public.league_find(text, int), public.league_reward(text, int, int)
  to authenticated;
