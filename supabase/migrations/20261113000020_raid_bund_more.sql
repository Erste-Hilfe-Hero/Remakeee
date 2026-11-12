-- Online 100, areas 3 and 4: a raid search with a random group (25), Echo teams for missing raid
-- places (26), role signs attack/guard/help (27), small perks by bund rank (34), the bund house
-- (35) and bund against bund, 5 against 5 on weekends (37). Values in server_config.raid_rules and
-- server_config.bund_rules (data/raid_rules.json, data/bund_rules.json); LocalRaidBund.gd does the same.

alter table public.raids add column if not exists echoes int not null default 0;
alter table public.raids add column if not exists echo_damage int not null default 0;
alter table public.raid_members add column if not exists role text not null default '';
alter table public.bunds add column if not exists house jsonb not null default '[]';
alter table public.bunds add column if not exists war_wins int not null default 0;

-- 25: players waiting for a random group, per tier. raid_id is set when someone else formed the group.
create table if not exists public.raid_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tier int not null,
  role text not null default '',
  created_at timestamptz not null default now(),
  raid_id bigint references public.raids (id) on delete cascade
);
-- 37: the five fighters of a bund this week with their fair-league team, the pairings and the fights.
create table if not exists public.bund_war_fighters (
  week text not null,
  bund_id bigint not null references public.bunds (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  slot int not null,
  team jsonb not null,
  primary key (week, user_id),
  unique (week, bund_id, slot)
);
create table if not exists public.bund_wars (
  id bigserial primary key,
  week text not null,
  bund_a bigint not null references public.bunds (id) on delete cascade,
  bund_b bigint not null references public.bunds (id) on delete cascade,
  settled boolean not null default false,
  winner bigint,
  created_at timestamptz not null default now()
);
create index if not exists bund_wars_a on public.bund_wars (bund_a, week);
create index if not exists bund_wars_b on public.bund_wars (bund_b, week);
create table if not exists public.bund_war_fights (
  id bigserial primary key,
  war_id bigint not null references public.bund_wars (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  side text not null check (side in ('a', 'b')),
  slot int not null,
  seed bigint not null,
  teams jsonb not null,
  battle_id bigint references public.battles (id) on delete set null,
  state text not null default 'open' check (state in ('open', 'submitted', 'done')),
  won boolean not null default false,
  created_at timestamptz not null default now(),
  unique (war_id, side, slot)
);
alter table public.raid_queue enable row level security;
alter table public.bund_war_fighters enable row level security;
alter table public.bund_wars enable row level security;
alter table public.bund_war_fights enable row level security;
revoke all on public.raid_queue, public.bund_war_fighters, public.bund_wars, public.bund_war_fights
  from public, anon, authenticated, chimora_referee;

alter table public.battles drop constraint if exists battles_kind_check;
alter table public.battles add constraint battles_kind_check
  check (kind in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel', 'rift', 'bund_war'));

-- --- Raids -----------------------------------------------------------------------------------

create or replace function public._raid_role_ok(p_role text) returns boolean
language sql stable as $$
  select p_role = '' or coalesce(public._raid_rules()->'roles', '["attack", "guard", "help"]'::jsonb) ? p_role
$$;

-- A new Rift for [who] at [p_tier]; [p_echoes] Echo teams take the missing places (26). Each Echo
-- deals echo_share percent of the strength at once. Guardian as in raid_open.
create or replace function public._raid_new(who uuid[], p_tier int, p_echoes int) returns bigint
language plpgsql volatile security definer set search_path = public as $$
declare
  rr jsonb := public._raid_rules();
  g text;
  leg boolean := false;
  wk int := floor(extract(epoch from now()) / 604800)::int;
  pool jsonb;
  n int := array_length(who, 1) + p_echoes;
  hp int;
  ed int;
  r bigint;
begin
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb) into pool from jsonb_array_elements(rr->'legendaries') with ordinality l(x, o)
  where exists (select 1 from public.game_species s where s.name = x #>> '{}');
  if jsonb_array_length(pool) > 0 and floor(random() * 100) < coalesce((rr->>'legendary_chance')::int, 0) then
    g := pool->>(wk % jsonb_array_length(pool));
    leg := true;
  else
    select coalesce(jsonb_agg(x order by o), '[]'::jsonb) into pool from jsonb_array_elements(public._config('raid_guardians', '[]'))
      with ordinality l(x, o) where exists (select 1 from public.game_species s where s.name = x #>> '{}');
    if jsonb_array_length(pool) = 0 then return null; end if;
    g := pool->>(wk % jsonb_array_length(pool));
  end if;
  hp := public._raid_hp(n) * (rr->'tiers'->p_tier->>'hp')::int / 100;
  if leg then hp := hp * coalesce((rr->>'legendary_hp')::int, 150) / 100; end if;
  ed := hp * coalesce((rr->>'echo_share')::int, 15) / 100;
  insert into public.raids (guardian, level, players, hp_total, hp_left, closes_at, tier, legendary, echoes, echo_damage)
  values (g, (rr->'tiers'->p_tier->>'level')::int, n, hp, hp - p_echoes * ed,
    now() + make_interval(hours => public._config_int('raid_hours', 48)), p_tier, leg, p_echoes, ed)
  returning id into r;
  insert into public.raid_members (raid_id, user_id) select r, x from unnest(who) x;
  return r;
end $$;

-- 25, 26: look for a random group. Call again every few seconds. A group forms with 4 players, or
-- with 2 or more after group_wait seconds; after echo_wait seconds Echo teams fill the free places.
-- Never with blocked players. Answer {found, raid, echoes} or {found: false, waiting, waited}.
create or replace function public.raid_find(p_tier int, p_role text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._raid_check(u);
  rr jsonb := public._raid_rules();
  q public.raid_queue;
  waited int;
  others uuid[];
  echoes int := 0;
  r bigint;
begin
  if e is not null then return public._fail(e); end if;
  if p_tier is null or p_tier < 0 or p_tier >= jsonb_array_length(rr->'tiers') then return public._fail('bad_tier'); end if;
  if p_role is null or not public._raid_role_ok(p_role) then return public._fail('bad_role'); end if;
  if not public._rate_ok(u, 'raid_find', 400) then return public._fail('slow_down'); end if;
  delete from public.raid_queue where created_at < now() - interval '1 day';
  select * into q from public.raid_queue where user_id = u for update;
  if q.raid_id is not null then
    delete from public.raid_queue where user_id = u;
    return jsonb_build_object('ok', true, 'found', true, 'raid', q.raid_id,
      'echoes', (select x.echoes from public.raids x where x.id = q.raid_id));
  end if;
  if q.user_id is null or q.tier <> p_tier
     or q.created_at < now() - make_interval(mins => coalesce((rr->>'queue_minutes')::int, 10)) then
    insert into public.raid_queue (user_id, tier, role) values (u, p_tier, p_role)
    on conflict (user_id) do update set tier = excluded.tier, role = excluded.role, created_at = now(), raid_id = null;
    waited := 0;
  else
    update public.raid_queue set role = p_role where user_id = u;
    waited := extract(epoch from now() - q.created_at)::int;
  end if;
  select coalesce(array_agg(x.user_id order by x.created_at), '{}') into others from (
    select w.user_id, w.created_at from public.raid_queue w
    where w.user_id <> u and w.tier = p_tier and w.raid_id is null
      and w.created_at >= now() - make_interval(mins => coalesce((rr->>'queue_minutes')::int, 10))
      and not public._blocked(u, w.user_id) and public._raid_check(w.user_id) is null
    order by w.created_at limit 3 for update skip locked) x;
  if not (cardinality(others) = 3 or (cardinality(others) >= 1 and waited >= coalesce((rr->>'group_wait')::int, 30))
          or waited >= coalesce((rr->>'echo_wait')::int, 60)) then
    return jsonb_build_object('ok', true, 'found', false, 'waiting', cardinality(others), 'waited', waited);
  end if;
  if waited >= coalesce((rr->>'echo_wait')::int, 60) then echoes := 3 - cardinality(others); end if;
  r := public._raid_new(array[u] || others, p_tier, echoes);
  if r is null then return public._fail('no_guardian'); end if;
  update public.raid_members m set role = w.role from public.raid_queue w
  where m.raid_id = r and w.user_id = m.user_id;
  update public.raid_queue set raid_id = r where user_id = any(others);
  delete from public.raid_queue where user_id = u;
  return jsonb_build_object('ok', true, 'found', true, 'raid', r, 'echoes', echoes);
end $$;

create or replace function public.raid_find_cancel() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  delete from public.raid_queue where user_id = public._uid() and raid_id is null;
  return jsonb_build_object('ok', true);
end $$;

-- 27: the own role sign in a Rift ('' = none).
create or replace function public.raid_role(p_raid bigint, p_role text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._raid_check(u);
begin
  if e is not null then return public._fail(e); end if;
  if p_role is null or not public._raid_role_ok(p_role) then return public._fail('bad_role'); end if;
  update public.raid_members set role = p_role where raid_id = p_raid and user_id = u;
  if not found then return public._fail('no_such_raid'); end if;
  return jsonb_build_object('ok', true, 'role', p_role);
end $$;

-- raid_list with role signs and Echo teams (20261110000011_raids.sql otherwise).
create or replace function public.raid_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._raid_check(u);
  tries int := public._config_int('raid_tries', 3);
begin
  if e is not null then return public._fail(e); end if;
  return jsonb_build_object('ok', true, 'rewards', public._config('raid_rewards', '[]'), 'tries', tries,
    'share_min', public._config_int('raid_share_min', 5), 'rounds', public._config_int('raid_rounds', 10),
    'roles', coalesce(public._raid_rules()->'roles', '["attack", "guard", "help"]'::jsonb),
    'raids', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'guardian', r.guardian, 'level', r.level,
        'players', r.players, 'hp_total', r.hp_total, 'hp_left', r.hp_left, 'tier', r.tier, 'echoes', r.echoes,
        'closes_at', extract(epoch from r.closes_at)::bigint, 'open', r.hp_left > 0 and r.closes_at > now(),
        'won', r.won_at is not null, 'role', me.role,
        'tries_left', greatest(0, tries - (select count(*) from public.raid_attempts a where a.raid_id = r.id
          and a.user_id = u and a.created_at >= date_trunc('day', now()))),
        'reward', case when r.won_at is not null and me.damage * 100 >= r.hp_total * public._config_int('raid_share_min', 5)
          then r.reward end,
        'claimed', me.claimed,
        'members', coalesce((select jsonb_agg(jsonb_build_object('name', p.name, 'damage', m.damage, 'me', m.user_id = u,
            'role', m.role) order by m.damage desc) from public.raid_members m join public.profiles p on p.id = m.user_id
            where m.raid_id = r.id), '[]'::jsonb)
          || coalesce((select jsonb_agg(jsonb_build_object('name', '', 'damage', r.echo_damage, 'me', false, 'role', '', 'echo', i > 0))
            from generate_series(1, r.echoes) i), '[]'::jsonb))
      order by r.created_at desc)
      from public.raids r join public.raid_members me on me.raid_id = r.id and me.user_id = u
      where r.created_at > now() - interval '7 days'), '[]'::jsonb));
end $$;

-- --- Bund perks (34) and the bund house (35) -----------------------------------------------------

-- Sum of the perk [p_key] for bund level [p_level]: every perk up to the level counts.
create or replace function public._bund_perk(p_level int, p_key text) returns int
language sql stable as $$
  select coalesce(sum((x->>'value')::int), 0)::int from jsonb_array_elements(coalesce(public._bund_rules()->'perks', '[]')) x
  where x->>'key' = p_key and (x->>'level')::int <= p_level
$$;

create or replace function public._bund_lvl(p_bund bigint) returns int
language sql stable as $$
  select public._bund_level(coalesce((select xp from public.bunds where id = p_bund), 0))
$$;

create or replace function public._bund_house_slots(p_level int) returns int
language sql stable as $$
  select coalesce((public._bund_rules()->>'house_slots')::int, 3) + public._bund_perk(p_level, 'house_slots')
$$;

-- bund_stats with the perks reached and the daily donation limit after perks.
create or replace function public.bund_stats() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  x public.bunds;
  br jsonb := public._bund_rules();
  lvl int;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  select * into x from public.bunds where id = b;
  lvl := public._bund_level(x.xp);
  return jsonb_build_object('ok', true, 'xp', x.xp, 'level', lvl, 'lang', x.lang, 'open', x.open,
    'goal', public._bund_goal(b), 'goal_target', (br->>'goal_target')::int,
    'goal_reward', jsonb_set(br->'goal_reward', '{count}', to_jsonb((br->'goal_reward'->>'count')::int + public._bund_perk(lvl, 'goal_more'))),
    'goal_claimed', exists (select 1 from public.bund_goal_claims where bund_id = b and week = public._week() and user_id = u),
    'donated_today', coalesce((select count from public.bund_donations where user_id = u and day = current_date), 0),
    'donate_daily', (br->>'donate_daily')::int + public._bund_perk(lvl, 'donate_more'),
    'perks', coalesce(br->'perks', '[]'::jsonb));
end $$;

-- bund_donate with the donate_more perk (20261111000060_bund_more.sql otherwise).
create or replace function public.bund_donate(p_slot int, p_rev int, p_item text, p_count int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  br jsonb := public._bund_rules();
  done int;
  r jsonb;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  if p_item is null or p_count is null or p_count < 1 or p_count > 99 then return public._fail('bad_count'); end if;
  done := coalesce((select count from public.bund_donations where user_id = u and day = current_date), 0);
  if done + p_count > (br->>'donate_daily')::int + public._bund_perk(public._bund_lvl(b), 'donate_more') then
    return public._fail('limit_today');
  end if;
  r := public._trade_bag(u, p_slot, p_rev, jsonb_build_object(p_item, -p_count));
  if not (r->>'ok')::boolean then return r; end if;
  insert into public.bund_donations (user_id, day, count) values (u, current_date, p_count)
  on conflict (user_id, day) do update set count = bund_donations.count + p_count;
  update public.bunds set xp = xp + p_count * (br->>'xp_per_item')::int,
    goal_progress = case when goal_week = public._week() then goal_progress else 0 end + p_count, goal_week = public._week()
  where id = b;
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'bag', jsonb_build_object(p_item, -p_count),
    'xp', (select xp from public.bunds where id = b), 'goal', public._bund_goal(b));
end $$;

-- bund_goal_claim with the goal_more perk.
create or replace function public.bund_goal_claim(p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  rw jsonb := public._bund_rules()->'goal_reward';
  n int;
  r jsonb;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  if public._bund_goal(b) < (public._bund_rules()->>'goal_target')::int then return public._fail('goal_open'); end if;
  if exists (select 1 from public.bund_goal_claims where bund_id = b and week = public._week() and user_id = u) then
    return public._fail('claimed');
  end if;
  n := (rw->>'count')::int + public._bund_perk(public._bund_lvl(b), 'goal_more');
  r := public._trade_bag(u, p_slot, p_rev, jsonb_build_object(rw->>'item', n));
  if not (r->>'ok')::boolean then return r; end if;
  insert into public.bund_goal_claims (bund_id, week, user_id) values (b, public._week(), u);
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'item', rw->>'item', 'count', n,
    'bag', jsonb_build_object(rw->>'item', n));
end $$;

-- 35: the bund house every member sees: rank, decorations, members with role and online dot, war wins.
create or replace function public.bund_house() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  x public.bunds;
  lvl int;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  select * into x from public.bunds where id = b;
  lvl := public._bund_level(x.xp);
  return jsonb_build_object('ok', true, 'name', jsonb_build_array(x.name_a, x.name_b), 'level', lvl, 'house', x.house,
    'slots', public._bund_house_slots(lvl), 'war_wins', x.war_wins,
    'can_edit', public._bund_role(u) in ('leader', 'helper'),
    'decor', coalesce((select jsonb_agg(d->>'id') from jsonb_array_elements(coalesce(public._bund_rules()->'decor', '[]')) d
      where coalesce((d->>'level')::int, 1) <= lvl), '[]'::jsonb),
    'members', coalesce((select jsonb_agg(jsonb_build_object('name', p.name, 'role', m.role, 'me', m.user_id = u,
      'online', p.last_seen > now() - interval '5 minutes') order by m.joined_at)
      from public.bund_members m join public.profiles p on p.id = m.user_id where m.bund_id = b), '[]'::jsonb));
end $$;

-- Leader and helpers place decorations unlocked by the bund rank, at most the house slots, no repeats.
create or replace function public.bund_house_set(p_house jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  lvl int;
begin
  if e is not null then return public._fail(e); end if;
  if b is null or public._bund_role(u) not in ('leader', 'helper') then return public._fail('not_allowed'); end if;
  lvl := public._bund_lvl(b);
  if jsonb_typeof(p_house) is distinct from 'array' or jsonb_array_length(p_house) > public._bund_house_slots(lvl)
     or (select count(distinct v) from jsonb_array_elements_text(p_house) v) <> jsonb_array_length(p_house)
     or exists (select 1 from jsonb_array_elements(p_house) v where jsonb_typeof(v) <> 'string' or not exists (
       select 1 from jsonb_array_elements(coalesce(public._bund_rules()->'decor', '[]')) d
       where d->>'id' = v #>> '{}' and coalesce((d->>'level')::int, 1) <= lvl)) then
    return public._fail('bad_decor');
  end if;
  update public.bunds set house = p_house where id = b;
  return jsonb_build_object('ok', true, 'house', p_house);
end $$;

-- --- Bund against bund (37) ---------------------------------------------------------------------

create or replace function public._bund_war_day() returns boolean
language sql stable as $$
  select coalesce(public._bund_rules()->'war_days', '[6, 7]'::jsonb) @> to_jsonb(extract(isodow from now() at time zone 'utc')::int)
$$;

create or replace function public._bund_war_size() returns int
language sql stable as $$
  select coalesce((public._bund_rules()->>'war_size')::int, 5)
$$;

create or replace function public._bund_war_of(p_bund bigint) returns public.bund_wars
language sql stable as $$
  select * from public.bund_wars where week = public._week() and (bund_a = p_bund or bund_b = p_bund) limit 1
$$;

-- Pairs a bund with five fighters with the waiting bund of nearest renown.
create or replace function public._bund_war_pair(p_bund bigint) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  w text := public._week();
  n int := public._bund_war_size();
  o bigint;
begin
  if (select count(*) from public.bund_war_fighters where week = w and bund_id = p_bund) < n
     or (public._bund_war_of(p_bund)).id is not null then
    return;
  end if;
  select x.id into o from public.bunds x
  where x.id <> p_bund and x.dissolve_at is null
    and (select count(*) from public.bund_war_fighters f where f.week = w and f.bund_id = x.id) >= n
    and (public._bund_war_of(x.id)).id is null
  order by abs(x.xp - (select xp from public.bunds where id = p_bund)), x.id limit 1 for update skip locked;
  if o is null then return; end if;
  insert into public.bund_wars (week, bund_a, bund_b) values (w, p_bund, o);
end $$;

-- Renown once all fights are done, or after the weekend: the winner gets war_win_xp, the other war_xp.
create or replace function public._bund_war_settle(p_war bigint) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  wr public.bund_wars;
  wa int;
  wb int;
  br jsonb := public._bund_rules();
begin
  select * into wr from public.bund_wars where id = p_war for update;
  if wr.id is null or wr.settled then return; end if;
  if wr.week = public._week() and public._bund_war_day()
     and (select count(*) from public.bund_war_fights where war_id = p_war and state = 'done') < 2 * public._bund_war_size() then
    return;
  end if;
  select count(*) filter (where side = 'a' and won), count(*) filter (where side = 'b' and won) into wa, wb
  from public.bund_war_fights where war_id = p_war;
  update public.bund_wars set settled = true,
    winner = case when wa > wb then wr.bund_a when wb > wa then wr.bund_b end where id = p_war;
  update public.bunds set xp = xp + case
      when (wa > wb and id = wr.bund_a) or (wb > wa and id = wr.bund_b) then coalesce((br->>'war_win_xp')::int, 300)
      else coalesce((br->>'war_xp')::int, 100) end,
    war_wins = war_wins + case when (wa > wb and id = wr.bund_a) or (wb > wa and id = wr.bund_b) then 1 else 0 end
  where id in (wr.bund_a, wr.bund_b);
end $$;

-- The war of this weekend: own fighters, the paired bund, the fights per place and the score.
create or replace function public.bund_war_info() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  w text := public._week();
  wr public.bund_wars;
  my text;
  foe bigint;
  x record;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  for x in select id from public.bund_wars where (bund_a = b or bund_b = b) and not settled loop
    perform public._bund_war_settle(x.id);
  end loop;
  wr := public._bund_war_of(b);
  if wr.id is not null then
    my := case when wr.bund_a = b then 'a' else 'b' end;
    foe := case when my = 'a' then wr.bund_b else wr.bund_a end;
  end if;
  return jsonb_build_object('ok', true, 'day', public._bund_war_day(), 'size', public._bund_war_size(),
    'days', coalesce(public._bund_rules()->'war_days', '[6, 7]'::jsonb),
    'joined', exists (select 1 from public.bund_war_fighters where week = w and user_id = u),
    'fighters', coalesce((select jsonb_agg(jsonb_build_object('slot', f.slot, 'name', p.name, 'me', f.user_id = u) order by f.slot)
      from public.bund_war_fighters f join public.profiles p on p.id = f.user_id where f.week = w and f.bund_id = b), '[]'::jsonb),
    'war', case when wr.id is null then null else jsonb_build_object('id', wr.id, 'settled', wr.settled,
      'result', case when not wr.settled then null when wr.winner = b then 'won' when wr.winner is null then 'draw' else 'lost' end,
      'foe', (select jsonb_build_object('name', jsonb_build_array(name_a, name_b), 'level', public._bund_level(xp))
        from public.bunds where id = foe),
      'wins', (select count(*) from public.bund_war_fights where war_id = wr.id and side = my and won),
      'foe_wins', (select count(*) from public.bund_war_fights where war_id = wr.id and side <> my and won),
      'places', (select jsonb_agg(jsonb_build_object('slot', s,
          'mine', (select p.name from public.bund_war_fighters f join public.profiles p on p.id = f.user_id
            where f.week = w and f.bund_id = b and f.slot = s),
          'foe', (select p.name from public.bund_war_fighters f join public.profiles p on p.id = f.user_id
            where f.week = w and f.bund_id = foe and f.slot = s),
          'mine_result', (select case when state <> 'done' then 'pending' when won then 'won' else 'lost' end
            from public.bund_war_fights where war_id = wr.id and side = my and slot = s),
          'foe_result', (select case when state <> 'done' then 'pending' when won then 'won' else 'lost' end
            from public.bund_war_fights where war_id = wr.id and side <> my and slot = s)) order by s)
        from generate_series(1, public._bund_war_size()) s)) end);
end $$;

-- Sign up as one of the five fighters of the weekend with the fair-league team (Ring 50, base stats).
create or replace function public.bund_war_join(p_pick jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  w text := public._week();
  team jsonb;
  n int;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  if not public._bund_war_day() then return public._fail('war_closed'); end if;
  perform 1 from public.bunds where id = b for update;
  if exists (select 1 from public.bund_war_fighters where week = w and user_id = u) then return public._fail('joined'); end if;
  if (public._bund_war_of(b)).id is not null then return public._fail('war_full'); end if;
  n := (select count(*) from public.bund_war_fighters where week = w and bund_id = b);
  if n >= public._bund_war_size() then return public._fail('war_full'); end if;
  team := public._league_team(u, 'fair', p_pick);
  if team ? 'error' then return public._fail(team->>'error'); end if;
  -- Wars and fighters go away after 5 weeks.
  delete from public.bund_wars where created_at < now() - interval '35 days';
  delete from public.bund_war_fighters where week < to_char(now() at time zone 'utc' - interval '35 days', 'IYYY-"W"IW');
  insert into public.bund_war_fighters (week, bund_id, user_id, slot, team) values (w, b, u, n + 1, team->'team');
  perform public._bund_war_pair(b);
  return public.bund_war_info();
end $$;

create or replace function public._bund_war_expect(f public.bund_war_fights) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', f.seed, 'teams', f.teams, 'ai', public._config_int('league_ai', 2),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false,
    'seals', '[0, 0, 0]'::jsonb, 'amulets', '[0, 0, 0]'::jsonb)
$$;

-- The own war battle against the team on the same place of the other bund. One per weekend; an
-- unsent battle can be started again with the same setup.
create or replace function public.bund_war_fight() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  w text := public._week();
  wr public.bund_wars;
  me_f public.bund_war_fighters;
  foe_f public.bund_war_fighters;
  my_side text;
  f public.bund_war_fights;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  if not public._bund_war_day() then return public._fail('war_closed'); end if;
  select * into me_f from public.bund_war_fighters where week = w and user_id = u and bund_id = b;
  wr := public._bund_war_of(b);
  if me_f.user_id is null or wr.id is null then return public._fail('no_war'); end if;
  my_side := case when wr.bund_a = b then 'a' else 'b' end;
  select * into foe_f from public.bund_war_fighters
  where week = w and slot = me_f.slot and bund_id = case when my_side = 'a' then wr.bund_b else wr.bund_a end;
  if foe_f.user_id is null then return public._fail('no_war'); end if;
  select * into f from public.bund_war_fights where war_id = wr.id and side = my_side and slot = me_f.slot;
  if f.id is not null and (f.state <> 'open' or f.user_id <> u) then return public._fail('fought'); end if;
  if f.id is null then
    insert into public.bund_war_fights (war_id, user_id, side, slot, seed, teams)
    values (wr.id, u, my_side, me_f.slot, floor(random() * 2147483647)::bigint, jsonb_build_array(me_f.team, foe_f.team))
    returning * into f;
  end if;
  return jsonb_build_object('ok', true, 'fight_id', f.id,
    'foe', (select name from public.profiles where id = foe_f.user_id)) || public._bund_war_expect(f);
end $$;

-- A checked war battle: a win counts for the own bund.
create or replace function public._bund_war_apply(p_battle_id bigint, p_ok boolean, p_detail jsonb) returns void
language plpgsql volatile security definer set search_path = public as $$
declare f public.bund_war_fights;
begin
  select * into f from public.bund_war_fights where battle_id = p_battle_id and state = 'submitted' for update;
  if not found then return; end if;
  update public.bund_war_fights set state = 'done', won = p_ok and p_detail->>'winner' = 'player' where id = f.id;
  perform public._bund_war_settle(f.war_id);
end $$;

-- battle_submit with bund war battles (built on 20261111000002_online_step1.sql).
create or replace function public.battle_submit(p_kind text, p_ref text, p_replay jsonb, p_claim jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  b bigint;
  m public.league_matches;
  a public.raid_attempts;
  wf public.bund_war_fights;
  claim jsonb;
  ref_id bigint := case when coalesce(p_ref, '') ~ '^[0-9]{1,18}$' then p_ref::bigint else -1 end;
  rounds int;
begin
  perform public._ensure_profile(u);
  if p_kind is null or p_kind not in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel', 'rift', 'bund_war') then
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
  if p_kind = 'rift' then
    insert into public.rift_runs (battle_id, user_id, week, rift, rounds) values (b, u, public._week(), p_ref, rounds);
  end if;
  perform public._referee_check(b, p_replay, claim);
  return jsonb_build_object('ok', true, 'battle_id', b, 'status', 'pending');
end $$;

-- The referee's verdict, now also for bund war battles (20261110000011_raids.sql otherwise).
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
  end if;
  return new;
end $$;

revoke all on function public._raid_role_ok(text), public._raid_new(uuid[], int, int), public._bund_perk(int, text),
  public._bund_lvl(bigint), public._bund_house_slots(int), public._bund_war_day(), public._bund_war_size(),
  public._bund_war_of(bigint), public._bund_war_pair(bigint), public._bund_war_settle(bigint),
  public._bund_war_expect(public.bund_war_fights), public._bund_war_apply(bigint, boolean, jsonb), public._battle_result_in()
  from public, anon, authenticated, chimora_referee;
revoke all on function public.raid_find(int, text), public.raid_find_cancel(), public.raid_role(bigint, text), public.raid_list(),
  public.bund_stats(), public.bund_donate(int, int, text, int), public.bund_goal_claim(int, int), public.bund_house(),
  public.bund_house_set(jsonb), public.bund_war_info(), public.bund_war_join(jsonb), public.bund_war_fight(),
  public.battle_submit(text, text, jsonb, jsonb) from public, anon, chimora_referee;
grant execute on function public.raid_find(int, text), public.raid_find_cancel(), public.raid_role(bigint, text), public.raid_list(),
  public.bund_stats(), public.bund_donate(int, int, text, int), public.bund_goal_claim(int, int), public.bund_house(),
  public.bund_house_set(jsonb), public.bund_war_info(), public.bund_war_join(jsonb), public.bund_war_fight(),
  public.battle_submit(text, text, jsonb, jsonb) to authenticated;
