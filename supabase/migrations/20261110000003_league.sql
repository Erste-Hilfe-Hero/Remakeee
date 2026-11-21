-- Chimora leagues (plan area 7, items 2730-2735, 2748, 2753-2755, 2769-2772, 2786, 2691, 2941).
-- Two leagues with fully separate ratings and opponent search:
-- * Gleichstand-Liga ("fair", default): the server rebuilds every team itself from the saved
--   echo team: Ring 50 (server_config.league_fair_ring), base stats only (no growth, no training,
--   nothing bought), only moves the species can learn up to that Ring (_league_team_fair).
-- * Offene Liga ("open"): the real team on its real Ring (up to level_max).
-- Seasons last 6 weeks (league_seasons). Ratings use Glicko-2 (start 1500, deviation 350),
-- players only see tiers. A league battle counts only after the battle referee said "ok": the
-- server picks seed and both teams (claim.expect), the game only sends its inputs.
-- Game data (species, learnsets) lives in game_species, filled at deploy from data/spirlings.json
-- by tools/online/game_data_sql.py. Re-runnable.

insert into public.server_config (key, value) values
  ('league_fair_ring', '50'),
  ('league_season_days', '42'),
  ('league_closing_minutes', '30'),
  ('league_search_start', '100'),
  ('league_search_step', '50'),
  ('league_search_max', '400'),
  ('league_match_minutes', '30'),
  ('league_ai', '2'),
  -- Area 10 fills this with the origin marks of shop items; they never count in the fair league.
  ('league_fair_blocked_sources', '[]')
on conflict (key) do nothing;

-- Both leagues are on for the test phase; Ali can switch them off one by one.
update public.feature_flags set enabled = true where key in ('league_fair', 'league_open');

-- ---------------------------------------------------------------------------------------
-- Game data (filled at deploy, see tools/online/game_data_sql.py).

create table if not exists public.game_species (
  name text primary key,
  -- [[level, move], ...] in the order data/spirlings.json lists them (levels ascending).
  learn jsonb not null default '[]'::jsonb,
  earlier text
);
alter table public.game_species enable row level security;
revoke all on public.game_species from public, anon, authenticated;

-- Moves [p_species] can know at [p_ring]: its own learnset and those of its earlier forms.
create or replace function public._league_learnable(p_species text, p_ring int) returns text[]
language sql stable as $$
  with recursive line(name, depth) as (
    select p_species, 0
    union all
    select g.earlier, l.depth + 1 from line l join public.game_species g on g.name = l.name
    where g.earlier is not null and l.depth < 5
  )
  select coalesce(array_agg(distinct x->>1), '{}')
  from line l join public.game_species g on g.name = l.name, jsonb_array_elements(g.learn) x
  where (x->>0)::int <= p_ring
$$;

-- Like SpirlingData.default_moves: the last four different moves of its own learnset up to the Ring.
create or replace function public._league_default_moves(p_species text, p_ring int) returns jsonb
language sql stable as $$
  with own as (
    select x->>1 as mv, min(n) as first_at
    from public.game_species g, jsonb_array_elements(g.learn) with ordinality t(x, n)
    where g.name = p_species and (x->>0)::int <= p_ring
    group by x->>1
  ), last4 as (
    select mv, first_at from own order by first_at desc limit 4
  )
  select coalesce(jsonb_agg(mv order by first_at), '[]'::jsonb) from last4
$$;

-- One fair league row (item 2731, 2733): Ring 50, base stats, only learnable moves.
create or replace function public._league_fair_row(p_species text, p_moves jsonb) returns jsonb
language plpgsql stable as $$
declare
  ring int := public._config_int('league_fair_ring', 50);
  ok text[] := public._league_learnable(p_species, ring);
  picked jsonb := '[]'::jsonb;
  mv text;
begin
  for mv in select x #>> '{}' from jsonb_array_elements(case when jsonb_typeof(p_moves) = 'array' then p_moves else '[]'::jsonb end) x loop
    if mv = any(ok) and not picked ? mv and jsonb_array_length(picked) < 4 then
      picked := picked || to_jsonb(mv);
    end if;
  end loop;
  if jsonb_array_length(picked) = 0 then
    picked := public._league_default_moves(p_species, ring);
  end if;
  return jsonb_build_object('species', p_species, 'level', ring, 'moves', picked);
end $$;

-- Builds a league team from the player's saved echo team (item 2734). The game only names
-- species and moves; everything else comes from the server. Returns {"team": [...]} or {"error"}.
create or replace function public._league_team(p_user uuid, p_league text, p_pick jsonb) returns jsonb
language plpgsql stable as $$
declare
  saved jsonb := coalesce((select team from public.profiles where id = p_user), '[]'::jsonb);
  used int[] := '{}';
  out_team jsonb := '[]'::jsonb;
  seen text[] := '{}';
  p jsonb;
  sp text;
  idx int;
  row_saved jsonb;
  level_max int := public._config_int('level_max', 60);
begin
  if jsonb_typeof(p_pick) is distinct from 'array' or jsonb_array_length(p_pick) = 0 then
    return jsonb_build_object('error', 'empty_team');
  end if;
  if jsonb_array_length(p_pick) > 5 then return jsonb_build_object('error', 'bad_team'); end if;
  for p in select * from jsonb_array_elements(p_pick) loop
    sp := case when jsonb_typeof(p) = 'object' then p->>'species' else p #>> '{}' end;
    if sp is null or not exists (select 1 from public.game_species where name = sp) then
      return jsonb_build_object('error', 'unknown_species');
    end if;
    if sp = any(seen) then return jsonb_build_object('error', 'duplicate_species'); end if;
    seen := seen || sp;
    idx := null;
    select n::int - 1, x into idx, row_saved from jsonb_array_elements(saved) with ordinality t(x, n)
    where x->>'species' = sp and not ((n::int - 1) = any(used)) order by n limit 1;
    if idx is null then return jsonb_build_object('error', 'not_in_team'); end if;
    used := used || idx;
    if p_league = 'fair' then
      out_team := out_team || public._league_fair_row(sp, case when jsonb_typeof(p) = 'object' then p->'moves' else '[]'::jsonb end);
    else
      out_team := out_team || jsonb_build_object('species', sp,
        'level', least(greatest(coalesce((row_saved->>'level')::int, 1), 1), level_max),
        'moves', coalesce(row_saved->'moves', '[]'::jsonb));
    end if;
  end loop;
  return jsonb_build_object('team', out_team);
end $$;

-- ---------------------------------------------------------------------------------------
-- Seasons (items 2769, 2786).

create table if not exists public.league_seasons (
  id serial primary key,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  rules_version int not null default 1,
  -- "running" or "paused"; "closing" is the last league_closing_minutes of a running season.
  state text not null default 'running' check (state in ('running', 'paused')),
  check (ends_at > starts_at)
);
alter table public.league_seasons enable row level security;
revoke all on public.league_seasons from public, anon, authenticated;
revoke all on sequence public.league_seasons_id_seq from public, anon, authenticated;

-- The season of now; starts the next one by itself when the last one is over.
create or replace function public._league_season() returns public.league_seasons
language plpgsql volatile as $$
declare s public.league_seasons;
begin
  select * into s from public.league_seasons where now() >= starts_at and now() < ends_at order by id desc limit 1;
  if not found then
    insert into public.league_seasons (starts_at, ends_at, rules_version)
    values (date_trunc('day', now()), date_trunc('day', now()) + make_interval(days => public._config_int('league_season_days', 42)),
      coalesce((select rules_version from public.league_seasons order by id desc limit 1), 1))
    returning * into s;
  end if;
  return s;
end $$;

create or replace function public._league_state(s public.league_seasons) returns text
language sql stable as $$
  select case when s.state = 'paused' then 'paused'
    when now() >= s.ends_at - make_interval(mins => public._config_int('league_closing_minutes', 30)) then 'closing'
    else 'running' end
$$;

-- ---------------------------------------------------------------------------------------
-- Entries: one table per league, so bought advantages never touch the fair league (item 2755).

create table if not exists public.league_fair_entries (
  season int not null references public.league_seasons (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  team jsonb not null,
  rating float8 not null default 1500,
  rd float8 not null default 350,
  vol float8 not null default 0.06,
  games int not null default 0,
  wins int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (season, user_id)
);
create table if not exists public.league_open_entries (like public.league_fair_entries including defaults including constraints);
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'league_open_entries_pkey') then
    alter table public.league_open_entries add primary key (season, user_id);
    alter table public.league_open_entries add foreign key (season) references public.league_seasons (id) on delete cascade;
    alter table public.league_open_entries add foreign key (user_id) references auth.users (id) on delete cascade;
  end if;
end $$;
create index if not exists league_fair_search on public.league_fair_entries (season, rating);
create index if not exists league_open_search on public.league_open_entries (season, rating);

create table if not exists public.league_matches (
  id bigserial primary key,
  league text not null check (league in ('fair', 'open')),
  season int not null references public.league_seasons (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  opponent uuid references auth.users (id) on delete set null,
  seed bigint not null,
  teams jsonb not null,
  created_at timestamptz not null default now(),
  battle_id bigint unique references public.battles (id) on delete set null,
  state text not null default 'open' check (state in ('open', 'submitted', 'done', 'expired')),
  rated boolean not null default true,
  score float8
);
create index if not exists league_matches_user on public.league_matches (user_id, created_at desc);

alter table public.league_fair_entries enable row level security;
alter table public.league_open_entries enable row level security;
alter table public.league_matches enable row level security;
revoke all on public.league_fair_entries, public.league_open_entries, public.league_matches from public, anon, authenticated;
revoke all on sequence public.league_matches_id_seq from public, anon, authenticated;

-- Reads or writes an entry of either league without repeating every function twice.
create or replace function public._league_entry(p_league text, p_season int, p_user uuid) returns jsonb
language plpgsql stable as $$
declare r jsonb;
begin
  if p_league = 'fair' then
    select to_jsonb(e) into r from public.league_fair_entries e where season = p_season and user_id = p_user;
  else
    select to_jsonb(e) into r from public.league_open_entries e where season = p_season and user_id = p_user;
  end if;
  return r;
end $$;

-- ---------------------------------------------------------------------------------------
-- Glicko-2 for one game (item 2770). Returns {rating, rd, vol}. Same as scripts/online/Glicko.gd.

create or replace function public._league_rate(r float8, rd float8, vol float8, r2 float8, rd2 float8, score float8) returns jsonb
language plpgsql immutable as $$
declare
  k constant float8 := 173.7178;
  tau constant float8 := 0.5;
  eps constant float8 := 0.000001;
  mu float8 := (r - 1500) / k;
  phi float8 := rd / k;
  mu2 float8 := (r2 - 1500) / k;
  phi2 float8 := rd2 / k;
  g float8 := 1 / sqrt(1 + 3 * phi2 * phi2 / (pi() * pi()));
  e float8 := 1 / (1 + exp(-g * (mu - mu2)));
  v float8 := 1 / (g * g * e * (1 - e));
  delta float8 := v * g * (score - e);
  a float8 := ln(vol * vol);
  big_a float8;
  big_b float8;
  big_c float8;
  fa float8;
  fb float8;
  fc float8;
  n int := 0;
  new_vol float8;
  phi_star float8;
  new_phi float8;
  new_mu float8;
begin
  big_a := a;
  if delta * delta > phi * phi + v then
    big_b := ln(delta * delta - phi * phi - v);
  else
    n := 1;
    while public._glicko_f(a - n * tau, delta, phi, v, a, tau) < 0 and n < 100 loop
      n := n + 1;
    end loop;
    big_b := a - n * tau;
  end if;
  fa := public._glicko_f(big_a, delta, phi, v, a, tau);
  fb := public._glicko_f(big_b, delta, phi, v, a, tau);
  n := 0;
  while abs(big_b - big_a) > eps and n < 100 loop
    big_c := big_a + (big_a - big_b) * fa / (fb - fa);
    fc := public._glicko_f(big_c, delta, phi, v, a, tau);
    if fc * fb <= 0 then
      big_a := big_b;
      fa := fb;
    else
      fa := fa / 2;
    end if;
    big_b := big_c;
    fb := fc;
    n := n + 1;
  end loop;
  new_vol := exp(big_a / 2);
  phi_star := sqrt(phi * phi + new_vol * new_vol);
  new_phi := 1 / sqrt(1 / (phi_star * phi_star) + 1 / v);
  new_mu := mu + new_phi * new_phi * g * (score - e);
  return jsonb_build_object('rating', k * new_mu + 1500,
    'rd', least(greatest(k * new_phi, 30), 350), 'vol', least(new_vol, 0.2));
end $$;

create or replace function public._glicko_f(x float8, delta float8, phi float8, v float8, a float8, tau float8) returns float8
language sql immutable as $$
  select exp(x) * (delta * delta - phi * phi - v - exp(x)) / (2 * power(phi * phi + v + exp(x), 2)) - (x - a) / (tau * tau)
$$;

-- Tier number 0-14 (item 2771): Spark, Ember, Flame, Glow, Beacon, each I-III. Same as LeagueRules.tier.
create or replace function public._league_tier(p_rating float8) returns int
language sql immutable as $$
  select least(greatest(floor((p_rating - 1200) / 70)::int, 0), 14)
$$;

-- ---------------------------------------------------------------------------------------
-- Player API.

create or replace function public._league_ok(p_league text) returns text
language plpgsql stable as $$
begin
  if p_league is null or p_league not in ('fair', 'open') then return 'bad_league'; end if;
  if not public._flag_on('league_' || p_league, 2147483647) then return 'feature_off'; end if;
  return null;
end $$;

-- Season, state and the player's standing in one league.
create or replace function public.league_info(p_league text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._league_ok(p_league);
  s public.league_seasons;
  e jsonb;
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
    'games', coalesce((e->>'games')::int, 0), 'wins', coalesce((e->>'wins')::int, 0));
end $$;

-- Enters (or changes) the league team, frozen as its own row (items 2734, 2941).
create or replace function public.league_join(p_league text, p_pick jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._league_ok(p_league);
  s public.league_seasons;
  built jsonb;
begin
  if err is not null then return public._fail(err); end if;
  perform public._ensure_profile(u);
  s := public._league_season();
  if public._league_state(s) = 'paused' then return public._fail('season_paused'); end if;
  if not public._rate_ok(u, 'league_join', 30) then return public._fail('slow_down'); end if;
  built := public._league_team(u, p_league, p_pick);
  if built ? 'error' then return public._fail(built->>'error'); end if;
  if p_league = 'fair' then
    insert into public.league_fair_entries (season, user_id, team) values (s.id, u, built->'team')
    on conflict (season, user_id) do update set team = excluded.team, updated_at = now();
  else
    insert into public.league_open_entries (season, user_id, team) values (s.id, u, built->'team')
    on conflict (season, user_id) do update set team = excluded.team, updated_at = now();
  end if;
  return jsonb_build_object('ok', true, 'team', built->'team');
end $$;

-- Opponent search (item 2772): +-100 rating, 50 wider every 10 seconds of waiting, at most 400.
-- The opponent is another player's frozen league team, steered by the AI. The server picks the
-- seed and both teams; the game fights exactly that and uploads its inputs with battle_submit.
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
begin
  if err is not null then return public._fail(err); end if;
  s := public._league_season();
  if public._league_state(s) = 'paused' then return public._fail('season_paused'); end if;
  me := public._league_entry(p_league, s.id, u);
  if me is null then return public._fail('not_joined'); end if;
  if not public._rate_ok(u, 'league_find', 240) then return public._fail('slow_down'); end if;
  span := least(public._config_int('league_search_start', 100)
    + public._config_int('league_search_step', 50) * floor(greatest(coalesce(p_waited, 0), 0) / 10.0),
    public._config_int('league_search_max', 400));
  if p_league = 'fair' then
    select user_id, team, rating into opp from public.league_fair_entries e
    where e.season = s.id and e.user_id <> u and not public._blocked(u, e.user_id)
      and abs(e.rating - (me->>'rating')::float8) <= span
    order by abs(e.rating - (me->>'rating')::float8), random() limit 1;
  else
    select user_id, team, rating into opp from public.league_open_entries e
    where e.season = s.id and e.user_id <> u and not public._blocked(u, e.user_id)
      and abs(e.rating - (me->>'rating')::float8) <= span
    order by abs(e.rating - (me->>'rating')::float8), random() limit 1;
  end if;
  if opp.user_id is null then
    return jsonb_build_object('ok', true, 'found', false, 'range', span);
  end if;
  update public.league_matches set state = 'expired' where user_id = u and state = 'open';
  insert into public.league_matches (league, season, user_id, opponent, seed, teams, rated)
  values (p_league, s.id, u, opp.user_id, sd, jsonb_build_array(me->'team', opp.team), public._league_state(s) = 'running')
  returning id into m;
  return jsonb_build_object('ok', true, 'found', true, 'match_id', m, 'seed', sd,
    'teams', jsonb_build_array(me->'team', opp.team), 'ai', public._config_int('league_ai', 2),
    'opponent_tier', public._league_tier(opp.rating), 'range', span,
    'rated', public._league_state(s) = 'running');
end $$;

-- What the referee must use for a league battle: the server's seed and teams, nothing from the game.
create or replace function public._league_expect(m public.league_matches) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', m.seed, 'teams', m.teams, 'ai', public._config_int('league_ai', 2),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false)
$$;

-- battle_submit again, now with league battles: the ref is the match id, and the claim gets the
-- server's expectation so a changed team or seed can never count.
create or replace function public.battle_submit(p_kind text, p_ref text, p_replay jsonb, p_claim jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  b bigint;
  m public.league_matches;
  claim jsonb;
begin
  perform public._ensure_profile(u);
  if p_kind is null or p_kind not in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel') then
    return public._fail('bad_kind');
  end if;
  if jsonb_typeof(p_replay) is distinct from 'object' or jsonb_typeof(p_claim) is distinct from 'object'
     or pg_column_size(p_replay) > 200000 or pg_column_size(p_claim) > 4000
     or jsonb_typeof(p_replay->'teams') is distinct from 'array'
     or jsonb_array_length(coalesce(p_replay->'inputs', '[]'::jsonb)) > 400 then
    return public._fail('bad_battle');
  end if;
  if not public._rate_ok(u, 'battle', public._config_int('battle_submit_limit', 60)) then
    return public._fail('slow_down');
  end if;
  claim := p_claim - 'expect';
  if p_kind in ('league_fair', 'league_open') then
    select * into m from public.league_matches
    where id = case when coalesce(p_ref, '') ~ '^[0-9]{1,18}$' then p_ref::bigint else -1 end
      and user_id = u and league = substr(p_kind, 8) for update;
    if not found then return public._fail('no_such_match'); end if;
    if m.state <> 'open' or m.created_at < now() - make_interval(mins => public._config_int('league_match_minutes', 30)) then
      return public._fail('match_closed');
    end if;
    claim := claim || jsonb_build_object('expect', public._league_expect(m));
  end if;
  insert into public.battles (user_id, kind, ref) values (u, p_kind, left(coalesce(p_ref, ''), 40))
  returning id into b;
  if m.id is not null then
    -- Closing time counts at upload: a battle sent in the last 30 minutes is not rated.
    update public.league_matches set state = 'submitted', battle_id = b,
      rated = rated and public._league_state((select s from public.league_seasons s where s.id = m.season)) = 'running'
    where id = m.id;
  end if;
  perform public._referee_check(b, p_replay, claim);
  return jsonb_build_object('ok', true, 'battle_id', b, 'status', 'pending');
end $$;

-- After the referee: a checked league battle changes the player's rating (items 2691, 2770).
-- Only the player who fought is rated; the opponent's team was an echo and nothing happens to it.
create or replace function public._league_apply(p_battle_id bigint, p_detail jsonb) returns void
language plpgsql volatile as $$
declare
  m public.league_matches;
  me jsonb;
  opp jsonb;
  sc float8;
  nr jsonb;
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
  if m.league = 'fair' then
    update public.league_fair_entries set rating = (nr->>'rating')::float8, rd = (nr->>'rd')::float8,
      vol = (nr->>'vol')::float8, games = games + 1, wins = wins + sc::int, updated_at = now()
    where season = m.season and user_id = m.user_id;
  else
    update public.league_open_entries set rating = (nr->>'rating')::float8, rd = (nr->>'rd')::float8,
      vol = (nr->>'vol')::float8, games = games + 1, wins = wins + sc::int, updated_at = now()
    where season = m.season and user_id = m.user_id;
  end if;
end $$;

create or replace function public._battle_result_in() returns trigger
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  update public.battles set status = new.verdict, decided_at = new.decided_at
  where id = new.battle_id and status = 'pending'
  returning kind into k;
  delete from public.battle_queue where battle_id = new.battle_id;
  if k in ('league_fair', 'league_open') then
    if new.verdict = 'ok' then
      perform public._league_apply(new.battle_id, new.detail);
    else
      update public.league_matches set state = 'done', rated = false where battle_id = new.battle_id;
    end if;
  end if;
  return new;
end $$;

revoke all on function public._league_learnable(text, int), public._league_default_moves(text, int),
  public._league_fair_row(text, jsonb), public._league_team(uuid, text, jsonb), public._league_season(),
  public._league_state(public.league_seasons), public._league_entry(text, int, uuid),
  public._league_rate(float8, float8, float8, float8, float8, float8), public._glicko_f(float8, float8, float8, float8, float8, float8),
  public._league_tier(float8), public._league_ok(text), public._league_expect(public.league_matches),
  public._league_apply(bigint, jsonb)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.league_info(text), public.league_join(text, jsonb), public.league_find(text, int)
  from public, anon, chimora_referee;
grant execute on function public.league_info(text), public.league_join(text, jsonb), public.league_find(text, int)
  to authenticated;
