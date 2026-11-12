-- Online 100: the weekend tournament with 8 players, knockout (62), watching a friend's live duel
-- one move behind (73), the battles of the week (74), the team of the best league player (77) and
-- the tournament final for everyone to watch (80). Also: in a live duel nobody sees the other
-- side's choice of the open round. Values in server_config.tourney (data/tourney.json);
-- LocalTourney.gd and LocalBackend do the same. The tournament waits behind the flag 'events'.

-- --- Live duels: hidden open round, watching (73) ----------------------------------------------

-- The duel as [u] may see it. A player never sees the other side's choice of the round that is
-- still open. A watcher (side -1) is one finished round behind while the duel runs.
create or replace function public._live_out(d public.live_duels, u uuid) returns jsonb
language plpgsql stable as $$
declare
  teams jsonb := '[]'::jsonb;
  side int := public._live_side(d, u);
  rows jsonb;
  i jsonb;
  mv jsonb := d.moves;
  open_row jsonb := d.moves->(d.round::text);
begin
  if d.state in ('running', 'done') and jsonb_typeof(d.pick->0) = 'array' and jsonb_typeof(d.pick->1) = 'array' then
    for s in 0 .. 1 loop
      rows := '[]'::jsonb;
      for i in select * from jsonb_array_elements(d.pick->s) loop
        rows := rows || jsonb_build_array(d.show->s->(i::int));
      end loop;
      teams := teams || jsonb_build_array(rows);
    end loop;
  end if;
  if d.state = 'running' then
    if side < 0 then
      mv := coalesce((select jsonb_object_agg(key, value) from jsonb_each(d.moves) where key::int < d.round - 1), '{}'::jsonb);
    elsif open_row is not null then
      mv := mv || jsonb_build_object(d.round::text, jsonb_set(open_row, array[(1 - side)::text], 'null'::jsonb));
    end if;
  end if;
  return jsonb_build_object('ok', true, 'id', d.id, 'side', side, 'state', d.state, 'show', d.show,
    'picked', jsonb_build_array(jsonb_typeof(d.pick->0) = 'array', jsonb_typeof(d.pick->1) = 'array'),
    'teams', teams, 'seed', d.seed, 'round', d.round, 'moves', mv,
    'deadline', extract(epoch from d.deadline)::bigint, 'turn_seconds', public._live_cfg('turn_seconds'),
    'winner', d.winner, 'reason', d.reason, 'emotes', d.emotes);
end $$;

-- May [u] watch duel [d]? Only friends of a player, nobody blocked, and never an own duel.
create or replace function public._live_can_watch(d public.live_duels, u uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select d.a <> u and d.b <> u and (public._friends(u, d.a) or public._friends(u, d.b))
    and not public._blocked(u, d.a) and not public._blocked(u, d.b)
$$;

-- Running live duels of friends.
create or replace function public.live_watch_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  if not public._flag_on('live_duel', 2147483647) then return public._fail('feature_off'); end if;
  if public._parent_off(u, 'live_duel') then return public._fail('parent_off'); end if;
  return jsonb_build_object('ok', true, 'duels', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'round', d.round,
      'names', jsonb_build_array((select name from public.profiles where id = d.a), (select name from public.profiles where id = d.b)))
      order by d.id desc)
    from public.live_duels d where d.state = 'running' and d.created_at > now() - interval '1 day'
      and public._live_can_watch(d, u)), '[]'::jsonb));
end $$;

create or replace function public.live_watch(p_id bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels;
begin
  if not public._flag_on('live_duel', 2147483647) then return public._fail('feature_off'); end if;
  if public._parent_off(u, 'live_duel') then return public._fail('parent_off'); end if;
  if not public._rate_ok(u, 'live_watch', 1200) then return public._fail('slow_down'); end if;
  d := public._live_tick(p_id);
  if d.id is null or d.state not in ('running', 'done') or not public._live_can_watch(d, u) then
    return public._fail('no_such_duel');
  end if;
  return public._live_out(d, u) || jsonb_build_object('names', jsonb_build_array(
    (select name from public.profiles where id = d.a), (select name from public.profiles where id = d.b)));
end $$;

-- --- 77: the team of the best player of a league this season, without a name ---------------------

create or replace function public.league_top_team(p_league text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._league_ok(p_league);
  sn int := (public._league_season()).id;
  t jsonb;
  g int;
  least_games int := coalesce((public._config('league_ranks', '{}'::jsonb)->>'placement_games')::int, 5);
begin
  if e is not null then return public._fail(e); end if;
  if p_league = 'fair' then
    select x.team, x.games into t, g from public.league_fair_entries x
    where x.season = sn and x.games >= least_games and not public._blocked(u, x.user_id)
    order by x.rating desc, x.user_id limit 1;
  else
    select x.team, x.games into t, g from public.league_open_entries x
    where x.season = sn and x.games >= least_games and not public._blocked(u, x.user_id)
    order by x.rating desc, x.user_id limit 1;
  end if;
  if t is null then return jsonb_build_object('ok', true, 'team', null); end if;
  return jsonb_build_object('ok', true, 'games', g, 'team', (select jsonb_agg(jsonb_build_object('species', m->>'species',
    'level', (m->>'level')::int, 'moves', coalesce(m->'moves', '[]'::jsonb)) order by o) from jsonb_array_elements(t) with ordinality x(m, o)));
end $$;

-- --- 62, 74, 80: the weekend tournament ------------------------------------------------------------

create table if not exists public.tourneys (
  id bigserial primary key,
  week text not null,
  state text not null default 'signup' check (state in ('signup', 'running', 'done')),
  round int not null default 0,
  round_ends timestamptz,
  winner uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists tourneys_week on public.tourneys (week, state);
create table if not exists public.tourney_players (
  tourney_id bigint not null references public.tourneys (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  place int not null,
  team jsonb not null,
  out_round int not null default 0,
  claimed boolean not null default false,
  primary key (tourney_id, user_id)
);
create index if not exists tourney_players_user on public.tourney_players (user_id);
create table if not exists public.tourney_fights (
  id bigserial primary key,
  tourney_id bigint not null references public.tourneys (id) on delete cascade,
  round int not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  seed bigint not null,
  teams jsonb not null,
  battle_id bigint references public.battles (id) on delete set null,
  state text not null default 'open' check (state in ('open', 'submitted', 'done')),
  won boolean not null default false,
  damage int not null default 0,
  rounds int not null default 999,
  replay jsonb,
  created_at timestamptz not null default now(),
  unique (tourney_id, round, user_id)
);
alter table public.tourneys enable row level security;
alter table public.tourney_players enable row level security;
alter table public.tourney_fights enable row level security;
revoke all on public.tourneys, public.tourney_players, public.tourney_fights from public, anon, authenticated, chimora_referee;

alter table public.battles drop constraint if exists battles_kind_check;
alter table public.battles add constraint battles_kind_check
  check (kind in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel', 'rift', 'bund_war', 'tourney'));

create or replace function public._tourney_cfg() returns jsonb
language sql stable as $$
  select '{"days": [6, 7], "size": 8, "round_hours": 6, "finals_rows": 10, "keep_days": 35,
    "rewards": [{"item": "spark_charm", "count": 1}, {"item": "max_tonic", "count": 2}, {"item": "revival_leaf", "count": 1},
      {"item": "strong_tonic", "count": 1}]}'::jsonb || public._config('tourney', '{}'::jsonb)
$$;

create or replace function public._tourney_day() returns boolean
language sql stable as $$
  select public._tourney_cfg()->'days' @> to_jsonb(extract(isodow from now() at time zone 'utc')::int)
$$;

-- Rounds of a knockout with [p_size] players (8 players: 3).
create or replace function public._tourney_rounds(p_size int) returns int
language sql immutable as $$
  select ceil(log(2, greatest(p_size, 2)))::int
$$;

create or replace function public._tourney_check(u uuid) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if not public._flag_on('events', 2147483647) then return 'feature_off'; end if;
  if not public._social(u) then return 'social_off'; end if;
  if public._cheat_held(u) then return 'under_review'; end if;
  return null;
end $$;

-- The rival of [u] in the running round: players still in, by place, in pairs (1-2, 3-4, ...).
create or replace function public._tourney_foe(p_tourney bigint, u uuid) returns uuid
language sql stable as $$
  with live as (
    select user_id, row_number() over (order by place) - 1 as n from public.tourney_players
    where tourney_id = p_tourney and out_round = 0)
  select o.user_id from live me join live o on o.n = (me.n / 2) * 2 + 1 - me.n % 2 where me.user_id = u
$$;

-- Closes the round once every battle of it is decided, or its time is over (an unplayed battle
-- loses). The better result of a pair goes on: a win, then more damage, then fewer rounds, then the
-- earlier place. After the last round the tournament is done.
create or replace function public._tourney_advance(p_tourney bigint) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  t public.tourneys;
  n int;
  r record;
begin
  loop
    select * into t from public.tourneys where id = p_tourney for update;
    if t.id is null or t.state <> 'running' then return; end if;
    if exists (select 1 from public.tourney_fights where tourney_id = t.id and round = t.round and state = 'submitted'
        and created_at > now() - interval '1 hour') then
      return;
    end if;
    n := (select count(*) from public.tourney_players where tourney_id = t.id and out_round = 0);
    if now() < t.round_ends and (select count(*) from public.tourney_fights
        where tourney_id = t.id and round = t.round and state = 'done') < n then
      return;
    end if;
    for r in
      with live as (
        select p.user_id, p.place, (row_number() over (order by p.place) - 1) / 2 as pair,
          coalesce(f.state = 'done' and f.won, false) as won, coalesce(case when f.state = 'done' then f.damage end, 0) as damage,
          coalesce(case when f.state = 'done' then f.rounds end, 999) as rounds
        from public.tourney_players p left join public.tourney_fights f
          on f.tourney_id = p.tourney_id and f.round = t.round and f.user_id = p.user_id
        where p.tourney_id = t.id and p.out_round = 0)
      select user_id from (select user_id, row_number() over (partition by pair
        order by won desc, damage desc, rounds, place) as rk from live) x where rk > 1
    loop
      update public.tourney_players set out_round = t.round where tourney_id = t.id and user_id = r.user_id;
    end loop;
    if (select count(*) from public.tourney_players where tourney_id = t.id and out_round = 0) <= 1 then
      update public.tourneys set state = 'done',
        winner = (select user_id from public.tourney_players where tourney_id = t.id and out_round = 0 limit 1)
      where id = t.id;
      return;
    end if;
    update public.tourneys set round = round + 1,
      round_ends = now() + make_interval(hours => (public._tourney_cfg()->>'round_hours')::int) where id = t.id;
  end loop;
end $$;

-- The latest tournament of [u] this week.
create or replace function public._tourney_of(u uuid) returns bigint
language sql stable as $$
  select t.id from public.tourneys t join public.tourney_players p on p.tourney_id = t.id
  where p.user_id = u and t.week = public._week() order by t.id desc limit 1
$$;

create or replace function public.tourney_info() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._tourney_check(u);
  c jsonb := public._tourney_cfg();
  tid bigint;
  t public.tourneys;
  me public.tourney_players;
  foe uuid;
  f public.tourney_fights;
  total int;
begin
  if e is not null then return public._fail(e); end if;
  tid := public._tourney_of(u);
  if tid is null then
    select p.tourney_id into tid from public.tourney_players p join public.tourneys x on x.id = p.tourney_id
    where p.user_id = u and x.state = 'done' and not p.claimed and x.created_at > now() - interval '14 days'
    order by p.tourney_id desc limit 1;
  end if;
  if tid is not null then perform public._tourney_advance(tid); end if;
  select * into t from public.tourneys where id = tid;
  select * into me from public.tourney_players where tourney_id = tid and user_id = u;
  if t.state = 'running' and me.out_round = 0 then
    foe := public._tourney_foe(tid, u);
    select * into f from public.tourney_fights where tourney_id = tid and round = t.round and user_id = u;
  end if;
  total := public._tourney_rounds((c->>'size')::int);
  return jsonb_build_object('ok', true, 'day', public._tourney_day(), 'size', (c->>'size')::int, 'rounds', total,
    'days', c->'days', 'rewards', c->'rewards',
    'tourney', case when t.id is null then null else jsonb_build_object('id', t.id, 'state', t.state, 'round', t.round,
      'round_ends', extract(epoch from t.round_ends)::bigint, 'out_round', me.out_round, 'claimed', me.claimed,
      'won', t.winner is not distinct from u and t.state = 'done',
      'fight', case when f.id is null then null when f.state <> 'done' then f.state when f.won then 'won' else 'lost' end,
      'foe', case when foe is null then null else jsonb_build_object('place', (select place from public.tourney_players
        where tourney_id = tid and user_id = foe), 'name', case when public._friends(u, foe) then (select name from public.profiles where id = foe) else '' end,
        'team', (select jsonb_agg(m->>'species') from public.tourney_players p, jsonb_array_elements(p.team) m
          where p.tourney_id = tid and p.user_id = foe)) end,
      'players', (select jsonb_agg(jsonb_build_object('place', p.place, 'me', p.user_id = u, 'out_round', p.out_round,
          'name', case when p.user_id = u or public._friends(u, p.user_id) then (select name from public.profiles where id = p.user_id) else '' end)
        order by p.place) from public.tourney_players p where p.tourney_id = tid)) end);
end $$;

-- Sign up with the fair-league team (Ring 50, base stats). The eighth player starts the knockout.
create or replace function public.tourney_join(p_pick jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._tourney_check(u);
  c jsonb := public._tourney_cfg();
  w text := public._week();
  team jsonb;
  tid bigint;
  n int;
begin
  if e is not null then return public._fail(e); end if;
  if not public._tourney_day() then return public._fail('tourney_closed'); end if;
  if public._tourney_of(u) is not null then return public._fail('joined'); end if;
  if not public._rate_ok(u, 'tourney_join', 6) then return public._fail('slow_down'); end if;
  team := public._league_team(u, 'fair', p_pick);
  if team ? 'error' then return public._fail(team->>'error'); end if;
  delete from public.tourneys where created_at < now() - make_interval(days => (c->>'keep_days')::int);
  select t.id into tid from public.tourneys t
  where t.week = w and t.state = 'signup'
    and not exists (select 1 from public.tourney_players p where p.tourney_id = t.id and public._blocked(u, p.user_id))
  order by t.id limit 1 for update skip locked;
  if tid is null then
    insert into public.tourneys (week) values (w) returning id into tid;
  end if;
  n := (select count(*) from public.tourney_players where tourney_id = tid);
  insert into public.tourney_players (tourney_id, user_id, place, team) values (tid, u, n + 1, team->'team');
  if n + 1 >= (c->>'size')::int then
    update public.tourneys set state = 'running', round = 1,
      round_ends = now() + make_interval(hours => (c->>'round_hours')::int) where id = tid;
  end if;
  return public.tourney_info();
end $$;

create or replace function public._tourney_expect(f public.tourney_fights) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', f.seed, 'teams', f.teams, 'ai', public._config_int('league_ai', 2),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false,
    'seals', '[0, 0, 0]'::jsonb, 'amulets', '[0, 0, 0]'::jsonb)
$$;

-- The own battle of the running round against the rival's team (played by the AI). One per round;
-- an unsent battle can be started again with the same setup.
create or replace function public.tourney_fight() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._tourney_check(u);
  tid bigint;
  t public.tourneys;
  me public.tourney_players;
  foe uuid;
  f public.tourney_fights;
begin
  if e is not null then return public._fail(e); end if;
  tid := public._tourney_of(u);
  if tid is not null then perform public._tourney_advance(tid); end if;
  select * into t from public.tourneys where id = tid;
  select * into me from public.tourney_players where tourney_id = tid and user_id = u;
  if t.id is null or t.state <> 'running' or me.out_round <> 0 then return public._fail('no_tourney'); end if;
  foe := public._tourney_foe(tid, u);
  if foe is null then return public._fail('no_tourney'); end if;
  select * into f from public.tourney_fights where tourney_id = tid and round = t.round and user_id = u;
  if f.id is not null and f.state <> 'open' then return public._fail('fought'); end if;
  if f.id is null then
    insert into public.tourney_fights (tourney_id, round, user_id, seed, teams)
    values (tid, t.round, u, floor(random() * 2147483647)::bigint, jsonb_build_array(me.team,
      (select team from public.tourney_players where tourney_id = tid and user_id = foe)))
    returning * into f;
  end if;
  return jsonb_build_object('ok', true, 'fight_id', f.id, 'round', t.round) || public._tourney_expect(f);
end $$;

-- A checked tournament battle.
create or replace function public._tourney_apply(p_battle_id bigint, p_ok boolean, p_detail jsonb) returns void
language plpgsql volatile security definer set search_path = public as $$
declare f public.tourney_fights;
begin
  select * into f from public.tourney_fights where battle_id = p_battle_id and state = 'submitted' for update;
  if not found then return; end if;
  update public.tourney_fights set state = 'done', won = p_ok and p_detail->>'winner' = 'player',
    damage = case when p_ok then greatest(coalesce((p_detail->>'foe_damage')::int, 0), 0) else 0 end,
    rounds = case when p_ok then greatest(coalesce((p_detail->>'rounds')::int, 999), 1) else 999 end,
    replay = case when p_ok then replay end
  where id = f.id;
  perform public._tourney_advance(f.tourney_id);
end $$;

-- The reward by how far the player came: winner, final, semi-final, took part. Once.
create or replace function public.tourney_reward(p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._tourney_check(u);
  c jsonb := public._tourney_cfg();
  p public.tourney_players;
  t public.tourneys;
  total int := public._tourney_rounds((c->>'size')::int);
  tier int;
  rw jsonb;
  r jsonb;
begin
  if e is not null then return public._fail(e); end if;
  select x.* into p from public.tourney_players x join public.tourneys y on y.id = x.tourney_id
  where x.user_id = u and y.state = 'done' and not x.claimed order by x.tourney_id desc limit 1 for update of x;
  if p.user_id is null then return public._fail('no_reward'); end if;
  select * into t from public.tourneys where id = p.tourney_id;
  tier := case when p.out_round = 0 then 0 else least(total - p.out_round + 1, jsonb_array_length(c->'rewards') - 1) end;
  rw := c->'rewards'->tier;
  r := public._trade_bag(u, p_slot, p_rev, jsonb_build_object(rw->>'item', (rw->>'count')::int));
  if not (r->>'ok')::boolean then return r; end if;
  update public.tourney_players set claimed = true where tourney_id = p.tourney_id and user_id = u;
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'item', rw->>'item', 'count', (rw->>'count')::int,
    'tier', tier, 'bag', jsonb_build_object(rw->>'item', (rw->>'count')::int));
end $$;

-- 74, 80: the finals of the last two weeks for everyone, newest first. Names only of friends.
create or replace function public.tourney_finals() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._tourney_check(u);
begin
  if e is not null then return public._fail(e); end if;
  return jsonb_build_object('ok', true, 'rows', coalesce((select jsonb_agg(x.r order by x.id desc) from (
    select f.id, jsonb_build_object('fight', f.id, 'week', t.week, 'won', f.won, 'rounds', f.rounds,
      'champion', t.winner is not distinct from f.user_id,
      'name', case when f.user_id = u or public._friends(u, f.user_id) then (select name from public.profiles where id = f.user_id) else '' end,
      'teams', jsonb_build_array((select jsonb_agg(m->>'species') from jsonb_array_elements(f.teams->0) m),
        (select jsonb_agg(m->>'species') from jsonb_array_elements(f.teams->1) m))) r
    from public.tourney_fights f join public.tourneys t on t.id = f.tourney_id
    where t.state = 'done' and f.round = t.round and f.state = 'done' and f.replay is not null
      and t.created_at > now() - interval '14 days' and not public._blocked(u, f.user_id)
    order by f.id desc limit (public._tourney_cfg()->>'finals_rows')::int) x), '[]'::jsonb));
end $$;

-- One final as a replay: the server's setup and the inputs the referee checked.
create or replace function public.tourney_replay(p_fight bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._tourney_check(u);
  f public.tourney_fights;
begin
  if e is not null then return public._fail(e); end if;
  if not public._rate_ok(u, 'tourney_replay', 60) then return public._fail('slow_down'); end if;
  select x.* into f from public.tourney_fights x join public.tourneys t on t.id = x.tourney_id
  where x.id = p_fight and t.state = 'done' and x.round = t.round and x.state = 'done' and x.replay is not null
    and not public._blocked(u, x.user_id);
  if f.id is null then return public._fail('no_such_fight'); end if;
  return jsonb_build_object('ok', true, 'replay', f.replay);
end $$;

-- battle_submit with tournament battles (built on 20261113000020_raid_bund_more.sql).
create or replace function public.battle_submit(p_kind text, p_ref text, p_replay jsonb, p_claim jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  b bigint;
  m public.league_matches;
  a public.raid_attempts;
  wf public.bund_war_fights;
  tf public.tourney_fights;
  claim jsonb;
  ref_id bigint := case when coalesce(p_ref, '') ~ '^[0-9]{1,18}$' then p_ref::bigint else -1 end;
  rounds int;
begin
  perform public._ensure_profile(u);
  if p_kind is null or p_kind not in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel', 'rift', 'bund_war', 'tourney') then
    return public._fail('bad_kind');
  end if;
  if jsonb_typeof(p_replay) is distinct from 'object' or jsonb_typeof(p_claim) is distinct from 'object'
     or pg_column_size(p_replay) > 200000 or pg_column_size(p_claim) > 4000
     or jsonb_typeof(p_replay->'teams') is distinct from 'array'
     or jsonb_array_length(coalesce(p_replay->'inputs', '[]'::jsonb)) > 400 then
    return public._fail('bad_battle');
  end if;
  if p_kind = 'rift' then
    if not public._flag_on('rift_board', 2147483647) then return public._fail('feature_off'); end if;
    if coalesce(p_ref, '') !~ '^[a-z_]{1,24}$' or not public._ids_known('rift', array[p_ref]) then
      return public._fail('no_such_rift');
    end if;
    if p_claim->>'winner' is distinct from 'player' or jsonb_typeof(p_claim->'rounds') is distinct from 'number'
       or (p_claim->>'rounds')::numeric not between 1 and 400 then
      return public._fail('bad_battle');
    end if;
    rounds := (p_claim->>'rounds')::numeric::int;
  end if;
  if not public._rate_ok(u, 'battle', public._config_int('battle_submit_limit', 60)) then
    return public._fail('slow_down');
  end if;
  claim := p_claim - 'expect';
  if p_kind in ('league_fair', 'league_open') then
    select * into m from public.league_matches
    where id = ref_id and user_id = u and league = substr(p_kind, 8) for update;
    if not found then return public._fail('no_such_match'); end if;
    if m.state <> 'open' or m.created_at < now() - make_interval(mins => public._config_int('league_match_minutes', 30)) then
      return public._fail('match_closed');
    end if;
    claim := claim || jsonb_build_object('expect', public._league_expect(m));
  elsif p_kind = 'raid' then
    select * into a from public.raid_attempts where id = ref_id and user_id = u for update;
    if not found then return public._fail('no_such_attempt'); end if;
    if a.state <> 'open' or a.created_at < now() - interval '30 minutes' then return public._fail('attempt_closed'); end if;
    claim := claim || jsonb_build_object('expect', public._raid_expect(a));
  elsif p_kind = 'bund_war' then
    select * into wf from public.bund_war_fights where id = ref_id and user_id = u for update;
    if not found then return public._fail('no_such_fight'); end if;
    if wf.state <> 'open' then return public._fail('fought'); end if;
    claim := claim || jsonb_build_object('expect', public._bund_war_expect(wf));
  elsif p_kind = 'tourney' then
    select * into tf from public.tourney_fights where id = ref_id and user_id = u for update;
    if not found then return public._fail('no_such_fight'); end if;
    if tf.state <> 'open' then return public._fail('fought'); end if;
    claim := claim || jsonb_build_object('expect', public._tourney_expect(tf));
  end if;
  insert into public.battles (user_id, kind, ref) values (u, p_kind, left(coalesce(p_ref, ''), 40))
  returning id into b;
  if m.id is not null then
    update public.league_matches set state = 'submitted', battle_id = b,
      rated = rated and public._league_state((select s from public.league_seasons s where s.id = m.season)) = 'running'
    where id = m.id;
  end if;
  if a.id is not null then
    update public.raid_attempts set state = 'submitted', battle_id = b where id = a.id;
  end if;
  if wf.id is not null then
    update public.bund_war_fights set state = 'submitted', battle_id = b where id = wf.id;
  end if;
  if tf.id is not null then
    update public.tourney_fights set state = 'submitted', battle_id = b, created_at = now(),
      replay = public._tourney_expect(tf) || jsonb_build_object('inputs', coalesce(p_replay->'inputs', '[]'::jsonb))
    where id = tf.id;
  end if;
  if p_kind = 'rift' then
    insert into public.rift_runs (battle_id, user_id, week, rift, rounds) values (b, u, public._week(), p_ref, rounds);
  end if;
  perform public._referee_check(b, p_replay, claim);
  return jsonb_build_object('ok', true, 'battle_id', b, 'status', 'pending');
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
  elsif k = 'raid' then
    perform public._raid_apply(new.battle_id, new.verdict = 'ok', new.detail);
  elsif k = 'bund_war' then
    perform public._bund_war_apply(new.battle_id, new.verdict = 'ok', new.detail);
  elsif k = 'tourney' then
    perform public._tourney_apply(new.battle_id, new.verdict = 'ok', new.detail);
  end if;
  return new;
end $$;

revoke all on function public._live_can_watch(public.live_duels, uuid), public._tourney_cfg(), public._tourney_day(),
  public._tourney_rounds(int), public._tourney_check(uuid), public._tourney_foe(bigint, uuid), public._tourney_advance(bigint),
  public._tourney_of(uuid), public._tourney_expect(public.tourney_fights), public._tourney_apply(bigint, boolean, jsonb),
  public._battle_result_in() from public, anon, authenticated, chimora_referee;
revoke all on function public.live_watch_list(), public.live_watch(bigint), public.league_top_team(text), public.tourney_info(),
  public.tourney_join(jsonb), public.tourney_fight(), public.tourney_reward(int, int), public.tourney_finals(),
  public.tourney_replay(bigint), public.battle_submit(text, text, jsonb, jsonb) from public, anon, chimora_referee;
grant execute on function public.live_watch_list(), public.live_watch(bigint), public.league_top_team(text), public.tourney_info(),
  public.tourney_join(jsonb), public.tourney_fight(), public.tourney_reward(int, int), public.tourney_finals(),
  public.tourney_replay(bigint), public.battle_submit(text, text, jsonb, jsonb) to authenticated;
