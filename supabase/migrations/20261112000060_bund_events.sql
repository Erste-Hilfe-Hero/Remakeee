-- Online 100, area 4 (bunds) and area 7 (events).
-- Bund life: a weekly bund goal fed by the world-goal steps of the members (33), bund level 1-20 from
-- bund xp with a bigger goal reward on higher levels (34), donations of coins and tradeable items (36),
-- a weekly bund board (38), search by language and activity (39) and open bunds anyone may join (40).
-- Online events: server-driven rows in online_events (69) plus one event per week from a rotation;
-- festivals with a shared goal, 4 tiers and an extra tier (61, 64), rule weeks with a team that must
-- fit (63), sighting days (65), a calendar (66), an event board (68), titles and an item by final rank,
-- and a recap (70).
-- Values in server_config.bund_life (data/bund_life.json) and server_config.online_events
-- (data/online_events.json), written by tools/online/game_data_sql.py. Bund life waits behind the
-- flag 'bund', events behind 'events'. LocalBackend does the same (scripts/online/LocalBundEvents.gd).

insert into public.feature_flags (key, enabled, min_version, note) values
  ('events', false, 1, 'Online-Ereignisse (Kalender, Feste, Regel-Wochen, Sichtungstage)')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------------------
-- Bund life

alter table public.bunds add column if not exists lang text not null default 'any';
alter table public.bunds add column if not exists open boolean not null default false;
alter table public.bunds add column if not exists xp bigint not null default 0;

create table if not exists public.bund_goals (
  bund_id bigint not null references public.bunds (id) on delete cascade,
  week text not null,
  kind text not null,
  target int not null,
  total int not null default 0,
  primary key (bund_id, week)
);
create table if not exists public.bund_goal_contrib (
  bund_id bigint not null references public.bunds (id) on delete cascade,
  week text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount int not null default 0,
  claimed boolean not null default false,
  primary key (bund_id, week, user_id)
);
create index if not exists bund_goal_contrib_user on public.bund_goal_contrib (user_id, week);
create table if not exists public.bund_weeks (
  bund_id bigint not null references public.bunds (id) on delete cascade,
  week text not null,
  xp int not null default 0,
  primary key (bund_id, week)
);
create index if not exists bund_weeks_board on public.bund_weeks (week, xp desc);
create table if not exists public.bund_donations (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  coins int not null default 0,
  items int not null default 0,
  primary key (user_id, day)
);
alter table public.bund_goals enable row level security;
alter table public.bund_goal_contrib enable row level security;
alter table public.bund_weeks enable row level security;
alter table public.bund_donations enable row level security;
revoke all on public.bund_goals, public.bund_goal_contrib, public.bund_weeks, public.bund_donations
  from public, anon, authenticated, chimora_referee;

-- One value of server_config.bund_life, with the defaults of data/bund_life.json.
create or replace function public._bl(p_key text) returns jsonb
language sql stable as $$
  select coalesce(public._config('bund_life', '{}'::jsonb)->p_key, ('{
    "levels": [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200, 4000, 5000, 6200, 7600, 9200, 11000, 13000, 15500, 18500, 22000],
    "goal_rotation": [{"kind": "battles", "per_member": 20}, {"kind": "bonds", "per_member": 4}, {"kind": "rests", "per_member": 10}],
    "goal_min_target": 40, "goal_add_max": 5, "goal_member_cap": 100, "goal_xp": 200,
    "goal_rewards": [{"from": 1, "item": "strong_tonic", "count": 2}],
    "donate_coin_step": 100, "donate_coin_xp": 1, "donate_coins_day": 5000, "donate_item_xp": 5, "donate_items_day": 20,
    "langs": ["any", "en", "de"], "active_days": 7, "search_rows": 20, "board_rows": 20, "join_per_hour": 10}'::jsonb)->p_key)
$$;

create or replace function public._bl_int(p_key text) returns int
language sql stable as $$
  select (public._bl(p_key) #>> '{}')::numeric::int
$$;

-- Level 1-20: how many level floors the xp has reached.
create or replace function public._bund_level(p_xp bigint) returns int
language sql stable as $$
  select greatest(1, (select count(*) from jsonb_array_elements(public._bl('levels')) t
    where (t #>> '{}')::bigint <= coalesce(p_xp, 0)))::int
$$;

-- The goal reward for a bund of level [p_level]: the last band whose "from" it reached.
create or replace function public._bund_reward(p_level int) returns jsonb
language sql stable as $$
  select coalesce((select x from jsonb_array_elements(public._bl('goal_rewards')) x
    where (x->>'from')::int <= p_level order by (x->>'from')::int desc limit 1),
    '{"item": "strong_tonic", "count": 1}'::jsonb)
$$;

create or replace function public._bund_xp(p_bund bigint, p_n int) returns void
language sql volatile as $$
  update public.bunds set xp = xp + greatest(p_n, 0) where id = p_bund;
  insert into public.bund_weeks (bund_id, week, xp) values (p_bund, public._week(), greatest(p_n, 0))
  on conflict (bund_id, week) do update set xp = public.bund_weeks.xp + excluded.xp;
$$;

-- This week's bund goal, made from the rotation (by week number, like the world goal) when the
-- week starts. The target grows with the members the bund has at that moment.
create or replace function public._bund_goal(p_bund bigint) returns public.bund_goals
language plpgsql volatile as $$
declare
  g public.bund_goals;
  w text := public._week();
  rot jsonb := public._bl('goal_rotation');
  pick jsonb;
  n int;
begin
  select * into g from public.bund_goals where bund_id = p_bund and week = w;
  if not found then
    pick := rot->(extract(week from now() at time zone 'utc')::int % jsonb_array_length(rot));
    select count(*) into n from public.bund_members where bund_id = p_bund;
    insert into public.bund_goals (bund_id, week, kind, target)
    values (p_bund, w, pick->>'kind', greatest(public._bl_int('goal_min_target'), (pick->>'per_member')::int * n))
    on conflict do nothing;
    delete from public.bund_goals where week < to_char((now() - interval '14 days') at time zone 'utc', 'IYYY-"W"IW');
    delete from public.bund_goal_contrib where week < to_char((now() - interval '14 days') at time zone 'utc', 'IYYY-"W"IW');
    delete from public.bund_weeks where week < to_char((now() - interval '35 days') at time zone 'utc', 'IYYY-"W"IW');
    delete from public.bund_donations where day < public._today() - 7;
    select * into g from public.bund_goals where bund_id = p_bund and week = w;
  end if;
  return g;
end $$;

-- A world-goal step of [u] also counts for the bund goal when the kind matches: at most
-- goal_add_max per step and goal_member_cap per member and week. Reaching the target gives xp once.
create or replace function public._bund_goal_add(u uuid, p_kind text, p_amount int) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  b bigint := public._bund_id(u);
  g public.bund_goals;
  have int;
  n int;
begin
  if b is null or coalesce(p_amount, 0) <= 0 or not public._flag_on('bund', 2147483647) then return; end if;
  g := public._bund_goal(b);
  if g.kind is distinct from p_kind then return; end if;
  have := coalesce((select amount from public.bund_goal_contrib where bund_id = b and week = g.week and user_id = u), 0);
  n := least(p_amount, public._bl_int('goal_add_max'), greatest(public._bl_int('goal_member_cap') - have, 0));
  if n <= 0 then return; end if;
  insert into public.bund_goal_contrib (bund_id, week, user_id, amount) values (b, g.week, u, n)
  on conflict (bund_id, week, user_id) do update set amount = public.bund_goal_contrib.amount + n;
  update public.bund_goals set total = total + n where bund_id = b and week = g.week returning * into g;
  if g.total >= g.target and g.total - n < g.target then
    perform public._bund_xp(b, public._bl_int('goal_xp'));
  end if;
end $$;

-- Level, xp, language, open, this week's goal with the caller's share, the reward and today's
-- donation room.
create or replace function public.bund_life() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  x public.bunds;
  g public.bund_goals;
  lv int;
  c public.bund_goal_contrib;
  d public.bund_donations;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  select * into x from public.bunds where id = b;
  g := public._bund_goal(b);
  lv := public._bund_level(x.xp);
  select * into c from public.bund_goal_contrib where bund_id = b and week = g.week and user_id = u;
  select * into d from public.bund_donations where user_id = u and day = public._today();
  return jsonb_build_object('ok', true, 'level', lv, 'xp', x.xp,
    'next', public._bl('levels')->lv, 'lang', x.lang, 'open', x.open, 'langs', public._bl('langs'),
    'week_xp', coalesce((select xp from public.bund_weeks where bund_id = b and week = g.week), 0),
    'goal', jsonb_build_object('week', g.week, 'kind', g.kind, 'target', g.target, 'total', g.total,
      'mine', coalesce(c.amount, 0), 'claimed', coalesce(c.claimed, false), 'done', g.total >= g.target),
    'reward', public._bund_reward(lv), 'rewards', public._bl('goal_rewards'),
    'donate', jsonb_build_object('coin_step', public._bl_int('donate_coin_step'),
      'coins_left', greatest(public._bl_int('donate_coins_day') - coalesce(d.coins, 0), 0),
      'items_left', greatest(public._bl_int('donate_items_day') - coalesce(d.items, 0), 0),
      'coin_xp', public._bl_int('donate_coin_xp'), 'item_xp', public._bl_int('donate_item_xp')));
end $$;

-- Takes the goal reward once a week (one bund per week, even after changing bunds) into the bag of
-- the stored save in [p_slot]; the device sends the revision it knows, like a trade.
create or replace function public.bund_goal_claim(p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  g public.bund_goals;
  c public.bund_goal_contrib;
  rw jsonb;
  r jsonb;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  g := public._bund_goal(b);
  select * into c from public.bund_goal_contrib where bund_id = b and week = g.week and user_id = u for update;
  if not found or c.amount <= 0 then return public._fail('not_helped'); end if;
  if g.total < g.target then return public._fail('not_reached'); end if;
  if exists (select 1 from public.bund_goal_contrib where user_id = u and week = g.week and claimed) then
    return public._fail('claimed');
  end if;
  rw := public._bund_reward(public._bund_level((select xp from public.bunds where id = b)));
  r := public._trade_bag(u, p_slot, p_rev, jsonb_build_object(rw->>'item', (rw->>'count')::int));
  if not (r->>'ok')::boolean then return r; end if;
  update public.bund_goal_contrib set claimed = true where bund_id = b and week = g.week and user_id = u;
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'item', rw->>'item', 'count', (rw->>'count')::int,
    'bag', jsonb_build_object(rw->>'item', (rw->>'count')::int));
end $$;

-- Gives coins (in steps of donate_coin_step) and tradeable items from the stored save to the bund.
-- They turn into bund xp; nothing comes back to anyone, so it is no way to pass things on.
create or replace function public.bund_donate(p_slot int, p_rev int, p_coins int, p_items jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  step int := greatest(public._bl_int('donate_coin_step'), 1);
  coins int := coalesce(p_coins, 0);
  items jsonb := coalesce(p_items, '{}'::jsonb);
  ok_items jsonb := public._config('trade_items', '[]'::jsonb);
  cnt int := 0;
  k text;
  v jsonb;
  d public.bund_donations;
  s public.saves;
  inv jsonb;
  money int;
  n int;
  gain int;
  back jsonb := '{}'::jsonb;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  if coins < 0 or coins % step <> 0 or jsonb_typeof(items) <> 'object' then return public._fail('bad_amount'); end if;
  for k, v in select * from jsonb_each(items) loop
    if jsonb_typeof(v) <> 'number' or (v #>> '{}')::numeric <> trunc((v #>> '{}')::numeric)
       or (v #>> '{}')::numeric not between 1 and 99 then
      return public._fail('bad_amount');
    end if;
    if not ok_items ? k then return public._fail('not_donatable'); end if;
    cnt := cnt + (v #>> '{}')::int;
    back := back || jsonb_build_object(k, -(v #>> '{}')::int);
  end loop;
  if coins = 0 and cnt = 0 then return public._fail('bad_amount'); end if;
  select * into d from public.bund_donations where user_id = u and day = public._today();
  if coalesce(d.coins, 0) + coins > public._bl_int('donate_coins_day')
     or coalesce(d.items, 0) + cnt > public._bl_int('donate_items_day') then
    return public._fail('limit_today');
  end if;
  select * into s from public.saves where user_id = u and slot = p_slot for update;
  if not found then return public._fail('no_save'); end if;
  if s.rev <> coalesce(p_rev, -1) then return public._fail('sync_first'); end if;
  money := coalesce((s.data->>'money')::numeric::int, 0);
  if money < coins then return public._fail('not_enough'); end if;
  inv := case when jsonb_typeof(s.data->'inventory') = 'object' then s.data->'inventory' else '{}'::jsonb end;
  for k, v in select * from jsonb_each(items) loop
    n := coalesce((inv->>k)::numeric::int, 0) - (v #>> '{}')::int;
    if n < 0 then return public._fail('not_enough'); end if;
    inv := case when n = 0 then inv - k else inv || jsonb_build_object(k, n) end;
  end loop;
  update public.saves set data = jsonb_set(jsonb_set(data, '{inventory}', inv), '{money}', to_jsonb(money - coins)),
    rev = s.rev + 1, saved_at = now(), request_id = null
  where user_id = u and slot = p_slot;
  insert into public.bund_donations (user_id, day, coins, items) values (u, public._today(), coins, cnt)
  on conflict (user_id, day) do update set coins = public.bund_donations.coins + excluded.coins,
    items = public.bund_donations.items + excluded.items;
  gain := coins / step * public._bl_int('donate_coin_xp') + cnt * public._bl_int('donate_item_xp');
  perform public._bund_xp(b, gain);
  return jsonb_build_object('ok', true, 'rev', s.rev + 1, 'money', -coins, 'bag', back, 'xp', gain,
    'level', public._bund_level((select xp from public.bunds where id = b)));
end $$;

-- The leader sets the bund's language and whether anyone may join without asking.
create or replace function public.bund_settings(p_lang text, p_open boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
begin
  if e is not null then return public._fail(e); end if;
  if public._bund_role(u) is distinct from 'leader' then return public._fail('not_allowed'); end if;
  if p_lang is null or not public._bl('langs') ? p_lang then return public._fail('bad_lang'); end if;
  update public.bunds set lang = p_lang, open = coalesce(p_open, false) where id = public._bund_id(u);
  return jsonb_build_object('ok', true, 'lang', p_lang, 'open', coalesce(p_open, false));
end $$;

-- Bunds with room, in the language [p_lang] (or any), most active members first. Never a bund
-- with a blocked player in it. Names are word numbers, so no member is named.
create or replace function public.bund_search(p_lang text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  mine bigint := public._bund_id(u);
  l text := coalesce(nullif(p_lang, ''), 'any');
begin
  if e is not null then return public._fail(e); end if;
  if not public._rate_ok(u, 'bund_search', 60) then return public._fail('slow_down'); end if;
  return jsonb_build_object('ok', true, 'bunds', coalesce((select jsonb_agg(jsonb_build_object('id', s.id,
      'name', jsonb_build_array(s.name_a, s.name_b), 'lang', s.lang, 'open', s.open, 'size', s.size,
      'active', s.active, 'level', public._bund_level(s.xp)) order by s.active desc, s.xp desc, s.id)
    from (select x.id, x.name_a, x.name_b, x.lang, x.open, x.xp,
            (select count(*) from public.bund_members m where m.bund_id = x.id)::int as size,
            (select count(*) from public.bund_members m join public.profiles p on p.id = m.user_id
              where m.bund_id = x.id and p.last_seen > now() - make_interval(days => public._bl_int('active_days')))::int as active
          from public.bunds x
          where x.id is distinct from mine and x.dissolve_at is null
            and (l = 'any' or x.lang in (l, 'any'))
            and not exists (select 1 from public.bund_members m where m.bund_id = x.id and public._blocked(u, m.user_id))
          ) s
    where s.size < public._config_int('bund_max', 30)
    limit public._bl_int('search_rows')), '[]'::jsonb));
end $$;

-- Join a bund from the search: an open bund at once, otherwise as a request for leader or helpers.
create or replace function public.bund_join(p_bund bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  x public.bunds;
begin
  if e is not null then return public._fail(e); end if;
  if public._bund_id(u) is not null then return public._fail('in_bund'); end if;
  select * into x from public.bunds where id = p_bund and dissolve_at is null;
  if not found or exists (select 1 from public.bund_members m where m.bund_id = x.id and public._blocked(u, m.user_id)) then
    return public._fail('no_such_bund');
  end if;
  if not public._rate_ok(u, 'bund_join', public._bl_int('join_per_hour')) then return public._fail('slow_down'); end if;
  if x.open or exists (select 1 from public.bund_invites where bund_id = x.id and user_id = u and kind = 'invite') then
    e := public._bund_join(x.id, u, 'member');
    if e is not null then return public._fail(e); end if;
    return jsonb_build_object('ok', true, 'joined', true);
  end if;
  insert into public.bund_invites (bund_id, user_id, kind, by_user) values (x.id, u, 'request', u)
  on conflict (bund_id, user_id) do nothing;
  return jsonb_build_object('ok', true, 'joined', false);
end $$;

-- This week's bund xp, best first: top board_rows and the caller's own bund.
create or replace function public.bund_board() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  mine bigint := public._bund_id(u);
  w text := public._week();
begin
  if e is not null then return public._fail(e); end if;
  return jsonb_build_object('ok', true, 'week', w, 'rows', coalesce((select jsonb_agg(jsonb_build_object('rank', r.rank,
      'name', jsonb_build_array(r.name_a, r.name_b), 'xp', r.xp, 'level', public._bund_level(r.total), 'me', coalesce(r.id = mine, false))
      order by r.rank, r.id)
    from (select x.id, x.name_a, x.name_b, x.xp as total, k.xp, rank() over (order by k.xp desc) as rank
          from public.bund_weeks k join public.bunds x on x.id = k.bund_id where k.week = w and k.xp > 0) r
    where r.rank <= public._bl_int('board_rows') or r.id = mine), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------------------
-- Online events

create table if not exists public.online_events (
  id text primary key check (id ~ '^[a-z0-9_-]{1,40}$'),
  kind text not null check (kind in ('festival', 'board', 'sighting')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  data jsonb not null default '{}'::jsonb,
  total bigint not null default 0,
  check (ends_at > starts_at)
);
create index if not exists online_events_time on public.online_events (ends_at, starts_at);
create table if not exists public.event_scores (
  event_id text not null references public.online_events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  score int not null default 0,
  claimed int not null default 0,
  team jsonb,
  at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create table if not exists public.event_awards (
  event_id text not null references public.online_events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  rank int not null,
  players int not null,
  title text not null,
  item text,
  at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create index if not exists event_awards_user on public.event_awards (user_id, at desc);
alter table public.online_events enable row level security;
alter table public.event_scores enable row level security;
alter table public.event_awards enable row level security;
revoke all on public.online_events, public.event_scores, public.event_awards from public, anon, authenticated, chimora_referee;

-- One value of server_config.online_events, with the defaults of data/online_events.json.
create or replace function public._ev(p_key text) returns jsonb
language sql stable as $$
  select coalesce(public._config('online_events', '{}'::jsonb)->p_key, ('{
    "tiers": [25, 50, 75, 100, 150], "add_max": 5, "user_cap": 500, "board_rows": 20, "calendar_days": 35, "recap_days": 14,
    "titles": [{"id": "first", "rank": 1}, {"id": "top10", "rank": 10}, {"id": "top_tenth", "pct": 10}, {"id": "took_part", "pct": 100}],
    "title_items": {"first": "spark_charm", "top10": "max_tonic", "top_tenth": "revival_leaf", "took_part": "strong_tonic"},
    "weekly": []}'::jsonb)->p_key)
$$;

create or replace function public._ev_int(p_key text) returns int
language sql stable as $$
  select (public._ev(p_key) #>> '{}')::numeric::int
$$;

-- The weekly events of this week and the next, made from the rotation in online_events.weekly
-- (by ISO week number, like the world goal). Old events go after 90 days with their scores.
create or replace function public._event_weekly() returns void
language plpgsql volatile as $$
declare
  rot jsonb := public._ev('weekly');
  i int;
  start timestamptz;
  t jsonb;
begin
  if jsonb_typeof(rot) is distinct from 'array' or jsonb_array_length(rot) = 0 then return; end if;
  for i in 0 .. 1 loop
    start := (date_trunc('week', now() at time zone 'utc') at time zone 'utc') + make_interval(days => 7 * i);
    t := rot->(extract(week from start at time zone 'utc')::int % jsonb_array_length(rot));
    insert into public.online_events (id, kind, starts_at, ends_at, data)
    values ('week-' || lower(to_char(start at time zone 'utc', 'IYYY-"w"IW')), t->>'kind', start, start + interval '7 days',
      t - 'kind')
    on conflict (id) do nothing;
  end loop;
  delete from public.online_events where ends_at < now() - interval '90 days';
end $$;

-- What a player may see of an event's data (the expanded species list stays on the server).
create or replace function public._event_public(e public.online_events) returns jsonb
language sql stable as $$
  select (e.data - 'allowed') || jsonb_build_object('id', e.id, 'kind', e.kind,
    'starts', extract(epoch from e.starts_at)::bigint, 'ends', extract(epoch from e.ends_at)::bigint,
    'state', case when now() < e.starts_at then 'upcoming' when now() < e.ends_at then 'running' else 'ended' end,
    'total', e.total)
$$;

-- (user, score, time) of everyone who counts on the board of [e]: festival steps, or confirmed
-- Rift wins after entering a fitting team for a board event.
create or replace function public._event_rows(e public.online_events) returns table (user_id uuid, score int, at timestamptz)
language sql stable security definer set search_path = public as $$
  select s.user_id, s.score, s.at from public.event_scores s
  where e.kind = 'festival' and s.event_id = e.id and s.score > 0
  union all
  select s.user_id, count(*)::int, max(r.at) from public.event_scores s
  join public.rift_runs r on r.user_id = s.user_id and r.at >= greatest(s.at, e.starts_at) and r.at < e.ends_at
    and (e.data->>'rift' is null or r.rift = e.data->>'rift')
  join public.battles b on b.id = r.battle_id and b.status = 'ok'
  where e.kind = 'board' and s.event_id = e.id and s.team is not null
  group by s.user_id
$$;

create or replace function public._event_check(u uuid) returns text
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public._flag_on('events', 2147483647) then return 'feature_off'; end if;
  perform public._ensure_profile(u);
  perform public._event_weekly();
  return null;
end $$;

-- A world-goal step also counts for every running festival with that goal kind: at most add_max
-- per step and user_cap per player.
create or replace function public._event_goal_add(u uuid, p_kind text, p_amount int) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  e public.online_events;
  have int;
  n int;
  cap int := public._ev_int('user_cap');
begin
  if coalesce(p_amount, 0) <= 0 or not public._flag_on('events', 2147483647) then return; end if;
  perform public._event_weekly();
  for e in select * from public.online_events where kind = 'festival' and data->>'goal_kind' = p_kind
      and now() >= starts_at and now() < ends_at loop
    have := coalesce((select score from public.event_scores where event_id = e.id and user_id = u), 0);
    n := least(p_amount, public._ev_int('add_max'), greatest(coalesce((e.data->>'user_cap')::int, cap) - have, 0));
    continue when n <= 0;
    insert into public.event_scores (event_id, user_id, score) values (e.id, u, n)
    on conflict (event_id, user_id) do update set score = public.event_scores.score + n, at = now();
    update public.online_events set total = total + n where id = e.id;
  end loop;
end $$;

-- The world goal (20261101000002_online_together.sql, unchanged rules) now also feeds the bund goal
-- and running festivals.
create or replace function public.community_add(p_kind text, p_amount int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  g public.community_goals := public._goal();
  cap int := coalesce((public._config('goal_user_cap', '500'))::text::int, 500);
  have int;
  n int;
begin
  if p_kind = g.kind and coalesce(p_amount, 0) > 0 then
    have := coalesce((select amount from public.community_contrib where week = g.week and user_id = u), 0);
    n := least(p_amount, 5, greatest(cap - have, 0));
    if n > 0 then
      insert into public.community_contrib (week, user_id, amount) values (g.week, u, n)
      on conflict (week, user_id) do update set amount = public.community_contrib.amount + n;
      update public.community_goals set total = total + n where week = g.week returning * into g;
    end if;
  end if;
  perform public._bund_goal_add(u, p_kind, p_amount);
  perform public._event_goal_add(u, p_kind, p_amount);
  return public._goal_json(g, u);
end $$;

-- The calendar: running events, those starting within calendar_days and those that ended within
-- recap_days, with the caller's own score, claimed tiers, entry and award; and the caller's titles.
create or replace function public.event_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._event_check(u);
begin
  if err is not null then return public._fail(err); end if;
  return jsonb_build_object('ok', true, 'now', extract(epoch from now())::bigint, 'tiers', public._ev('tiers'),
    'events', coalesce((select jsonb_agg(public._event_public(e) || jsonb_build_object(
        'mine', coalesce((select score from public._event_rows(e) r where r.user_id = u), 0),
        'claimed', coalesce((select claimed from public.event_scores s where s.event_id = e.id and s.user_id = u), 0),
        'entered', exists (select 1 from public.event_scores s where s.event_id = e.id and s.user_id = u and s.team is not null),
        'award', (select jsonb_build_object('rank', a.rank, 'players', a.players, 'title', a.title, 'item', a.item)
          from public.event_awards a where a.event_id = e.id and a.user_id = u))
      order by e.starts_at, e.id)
      from public.online_events e
      where e.ends_at > now() - make_interval(days => public._ev_int('recap_days'))
        and e.starts_at < now() + make_interval(days => public._ev_int('calendar_days'))), '[]'::jsonb),
    'titles', coalesce((select jsonb_agg(jsonb_build_object('event', a.event_id, 'title', a.title,
        'name', (select data->'name' from public.online_events where id = a.event_id)) order by a.at desc)
      from public.event_awards a where a.user_id = u), '[]'::jsonb));
end $$;

-- Takes festival tier [p_tier] (1-based into tiers: percent of the target) once, for anyone who
-- helped, while it runs or up to recap_days after; the item goes into the stored save's bag.
create or replace function public.event_claim(p_event text, p_tier int, p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._event_check(u);
  e public.online_events;
  s public.event_scores;
  pct int;
  item text;
  r jsonb;
begin
  if err is not null then return public._fail(err); end if;
  select * into e from public.online_events where id = p_event;
  if not found or e.kind <> 'festival' or now() < e.starts_at then return public._fail('no_such_event'); end if;
  if now() > e.ends_at + make_interval(days => public._ev_int('recap_days')) then return public._fail('event_over'); end if;
  if p_tier is null or p_tier < 1 or p_tier > jsonb_array_length(public._ev('tiers')) then return public._fail('bad_tier'); end if;
  select * into s from public.event_scores where event_id = e.id and user_id = u for update;
  if not found or s.score <= 0 then return public._fail('not_helped'); end if;
  pct := (public._ev('tiers')->>(p_tier - 1))::int;
  if e.total * 100 < (e.data->>'target')::bigint * pct then return public._fail('not_reached'); end if;
  if s.claimed & (1 << (p_tier - 1)) <> 0 then return public._fail('claimed'); end if;
  item := coalesce(e.data->'rewards'->>(p_tier - 1), 'tonic');
  r := public._trade_bag(u, p_slot, p_rev, jsonb_build_object(item, 1));
  if not (r->>'ok')::boolean then return r; end if;
  update public.event_scores set claimed = claimed | (1 << (p_tier - 1)) where event_id = e.id and user_id = u;
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'item', item, 'bag', jsonb_build_object(item, 1));
end $$;

-- Enter a running board event with a team (species names, 1 to 6, all different) that fits its
-- rules. Only Rift wins after the first entry count; entering again changes the team.
create or replace function public.event_enter(p_event text, p_team text[]) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._event_check(u);
  e public.online_events;
  n int := coalesce(array_length(p_team, 1), 0);
begin
  if err is not null then return public._fail(err); end if;
  select * into e from public.online_events where id = p_event;
  if not found or e.kind <> 'board' or now() < e.starts_at or now() >= e.ends_at then return public._fail('no_such_event'); end if;
  if n < 1 or n > 6 or (select count(distinct x) from unnest(p_team) x) <> n
     or not public._ids_known('species', p_team) then
    return public._fail('bad_team');
  end if;
  if jsonb_typeof(e.data->'allowed') = 'array'
     and exists (select 1 from unnest(p_team) x where not e.data->'allowed' ? x) then
    return public._fail('rules');
  end if;
  insert into public.event_scores (event_id, user_id, team) values (e.id, u, to_jsonb(p_team))
  on conflict (event_id, user_id) do update set team = excluded.team;
  return jsonb_build_object('ok', true);
end $$;

-- The board of [p_event]: friends only or everyone (strangers without names), top board_rows
-- and the caller's own row, never blocked players.
create or replace function public.event_board(p_event text, p_friends boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._event_check(u);
  e public.online_events;
begin
  if err is not null then return public._fail(err); end if;
  select * into e from public.online_events where id = p_event;
  if not found or e.kind = 'sighting' then return public._fail('no_such_event'); end if;
  return jsonb_build_object('ok', true, 'event', e.id, 'rows', public._board_json(u, coalesce((
    select jsonb_agg(jsonb_build_object('u', r.user_id, 'v', r.score, 'at', extract(epoch from r.at)))
    from public._event_rows(e) r
    where (not coalesce(p_friends, true) or r.user_id = u or public._friends(u, r.user_id))
      and not public._blocked(u, r.user_id)), '[]'::jsonb), false));
end $$;

-- Rank of [u] among everyone on the board of [e] (1 = best), and how many are on it.
create or replace function public._event_rank(e public.online_events, u uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('rank', (select x.rank from (select r.user_id, rank() over (order by r.score desc, r.at) as rank
      from public._event_rows(e) r) x where x.user_id = u),
    'players', (select count(*) from public._event_rows(e)),
    'score', coalesce((select r.score from public._event_rows(e) r where r.user_id = u), 0),
    'best', coalesce((select max(r.score) from public._event_rows(e) r), 0))
$$;

-- After the end: the title of the first bracket in online_events.titles the final rank reaches
-- (a place or a top percentage) and its item, once.
create or replace function public.event_reward(p_event text, p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._event_check(u);
  e public.online_events;
  rk jsonb;
  rank int;
  players int;
  t jsonb;
  title text := null;
  item text;
  r jsonb;
begin
  if err is not null then return public._fail(err); end if;
  select * into e from public.online_events where id = p_event;
  if not found or e.kind = 'sighting' then return public._fail('no_such_event'); end if;
  if now() < e.ends_at then return public._fail('still_running'); end if;
  if exists (select 1 from public.event_awards where event_id = e.id and user_id = u) then return public._fail('claimed'); end if;
  rk := public._event_rank(e, u);
  if rk->'rank' is null or jsonb_typeof(rk->'rank') = 'null' then return public._fail('not_helped'); end if;
  rank := (rk->>'rank')::int;
  players := (rk->>'players')::int;
  for t in select * from jsonb_array_elements(public._ev('titles')) loop
    if (t ? 'rank' and rank <= (t->>'rank')::int) or (t ? 'pct' and rank * 100 <= (t->>'pct')::int * players) then
      title := t->>'id';
      exit;
    end if;
  end loop;
  if title is null then return public._fail('not_helped'); end if;
  item := public._ev('title_items')->>title;
  if item is not null then
    r := public._trade_bag(u, p_slot, p_rev, jsonb_build_object(item, 1));
    if not (r->>'ok')::boolean then return r; end if;
  end if;
  insert into public.event_awards (event_id, user_id, rank, players, title, item) values (e.id, u, rank, players, title, item);
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'rank', rank, 'players', players, 'title', title,
    'item', item, 'bag', case when item is null then '{}'::jsonb else jsonb_build_object(item, 1) end);
end $$;

-- What the player did in [p_event]: score, rank of how many, the best score, the shared total and
-- the tiers it reached, and the award if taken.
create or replace function public.event_recap(p_event text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._event_check(u);
  e public.online_events;
  reached int := 0;
  pct jsonb;
begin
  if err is not null then return public._fail(err); end if;
  select * into e from public.online_events where id = p_event;
  if not found or e.kind = 'sighting' or now() < e.starts_at then return public._fail('no_such_event'); end if;
  if e.kind = 'festival' then
    for pct in select * from jsonb_array_elements(public._ev('tiers')) loop
      if e.total * 100 >= (e.data->>'target')::bigint * (pct #>> '{}')::int then reached := reached + 1; end if;
    end loop;
  end if;
  return public._event_public(e) || public._event_rank(e, u) || jsonb_build_object('ok', true, 'reached', reached,
    'award', (select jsonb_build_object('rank', a.rank, 'players', a.players, 'title', a.title, 'item', a.item)
      from public.event_awards a where a.event_id = e.id and a.user_id = u));
end $$;

-- ---------------------------------------------------------------------------------------

revoke all on function public._bl(text), public._bl_int(text), public._bund_level(bigint), public._bund_reward(int),
  public._bund_xp(bigint, int), public._bund_goal(bigint), public._bund_goal_add(uuid, text, int),
  public._ev(text), public._ev_int(text), public._event_weekly(), public._event_public(public.online_events),
  public._event_rows(public.online_events), public._event_check(uuid), public._event_goal_add(uuid, text, int),
  public._event_rank(public.online_events, uuid)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.bund_life(), public.bund_goal_claim(int, int), public.bund_donate(int, int, int, jsonb),
  public.bund_settings(text, boolean), public.bund_search(text), public.bund_join(bigint), public.bund_board(),
  public.community_add(text, int), public.event_list(), public.event_claim(text, int, int, int),
  public.event_enter(text, text[]), public.event_board(text, boolean), public.event_reward(text, int, int),
  public.event_recap(text)
  from public, anon, chimora_referee;
grant execute on function public.bund_life(), public.bund_goal_claim(int, int), public.bund_donate(int, int, int, jsonb),
  public.bund_settings(text, boolean), public.bund_search(text), public.bund_join(bigint), public.bund_board(),
  public.community_add(text, int), public.event_list(), public.event_claim(text, int, int, int),
  public.event_enter(text, text[]), public.event_board(text, boolean), public.event_reward(text, int, int),
  public.event_recap(text)
  to authenticated;
