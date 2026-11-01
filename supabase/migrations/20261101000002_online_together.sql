-- Chimora online together: friends, blocking and reports, mail (set phrases, waves, daily gifts),
-- echo teams for echo partners and echo duels, the world goal of the week and the weekly board.
-- Same security model as the core migration: locked tables, security-definer functions only.
-- Spirlings are never traded or gifted. There is no free text anywhere: greetings are phrase numbers.

alter table public.profiles add column if not exists team jsonb not null default '[]'::jsonb;

insert into public.server_config (key, value) values
  ('friend_limit', '100'),
  ('gift_open_limit', '10'),
  -- What a gift can hold (weights out of 100). Shown in the game (item 182).
  ('gift_table', '[{"item":"tonic","w":25},{"item":"remedy","w":20},{"item":"strong_tonic","w":15},{"item":"spark_drop","w":12},{"item":"cooling_gel","w":5},{"item":"dry_towel","w":5},{"item":"wake_bell","w":5},{"item":"power_brew","w":3},{"item":"guard_brew","w":3},{"item":"focus_brew","w":3},{"item":"dash_brew","w":3},{"item":"revival_leaf","w":1}]'),
  -- World goal of the week, taken in turn by ISO week number.
  ('goal_rotation', '[{"kind":"battles","target":5000},{"kind":"bonds","target":800},{"kind":"rests","target":2000}]'),
  ('goal_rewards', '["strong_tonic","spark_drop","max_tonic","spark_charm"]'),
  ('goal_user_cap', '500')
on conflict (key) do nothing;

create table if not exists public.friendships (
  a uuid not null references auth.users (id) on delete cascade,
  b uuid not null references auth.users (id) on delete cascade,
  status text not null check (status in ('pending', 'accepted')),
  requested_by uuid not null,
  points int not null default 0,
  created_at timestamptz not null default now(),
  primary key (a, b),
  check (a < b)
);

create table if not exists public.blocks (
  blocker uuid not null references auth.users (id) on delete cascade,
  blocked uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked)
);

-- Reports (DSA notice). Ali reviews them in the dashboard (docs/ONLINE.md).
create table if not exists public.reports (
  id bigserial primary key,
  reporter uuid references auth.users (id) on delete set null,
  target uuid not null,
  target_name text not null,
  reason int not null,
  created_at timestamptz not null default now(),
  handled boolean not null default false
);

create table if not exists public.mail (
  id bigserial primary key,
  sender uuid not null references auth.users (id) on delete cascade,
  recipient uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('phrase', 'wave', 'thanks', 'gift', 'echo', 'duel')),
  phrase int not null default 0,
  item text not null default '',
  place text not null default '',
  opened boolean not null default false,
  opened_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists mail_recipient on public.mail (recipient, created_at desc);

create table if not exists public.rate_events (
  user_id uuid not null,
  kind text not null,
  at timestamptz not null default now()
);
create index if not exists rate_events_user on public.rate_events (user_id, kind, at);

create table if not exists public.community_goals (
  week text primary key,
  kind text not null,
  target int not null,
  total bigint not null default 0
);

create table if not exists public.community_contrib (
  week text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount int not null default 0,
  claimed int not null default 0,
  primary key (week, user_id)
);

create table if not exists public.weekly_scores (
  week text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  score int not null,
  at timestamptz not null default now(),
  primary key (week, user_id)
);

alter table public.friendships enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.mail enable row level security;
alter table public.rate_events enable row level security;
alter table public.community_goals enable row level security;
alter table public.community_contrib enable row level security;
alter table public.weekly_scores enable row level security;
revoke all on public.friendships, public.blocks, public.reports, public.mail, public.rate_events,
  public.community_goals, public.community_contrib, public.weekly_scores from anon, authenticated;

-- ---------------------------------------------------------------------------------------
-- Helpers

create or replace function public._by_code(p_code text) returns uuid
language sql stable as $$
  select id from public.profiles where code = upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'))
$$;

create or replace function public._friends(x uuid, y uuid) returns boolean
language sql stable as $$
  select exists (select 1 from public.friendships
    where a = least(x, y) and b = greatest(x, y) and status = 'accepted')
$$;

create or replace function public._blocked(x uuid, y uuid) returns boolean
language sql stable as $$
  select exists (select 1 from public.blocks where (blocker = x and blocked = y) or (blocker = y and blocked = x))
$$;

create or replace function public._social(x uuid) returns boolean
language sql stable as $$
  select coalesce((select social from public.profiles where id = x), false)
$$;

-- True (and counted) if the user is still under [p_max] events of this kind in the last hour.
create or replace function public._rate_ok(u uuid, p_kind text, p_max int) returns boolean
language plpgsql volatile as $$
begin
  if (select count(*) from public.rate_events where user_id = u and kind = p_kind and at > now() - interval '1 hour') >= p_max then
    return false;
  end if;
  insert into public.rate_events (user_id, kind) values (u, p_kind);
  delete from public.rate_events where user_id = u and at < now() - interval '1 day';
  return true;
end $$;

create or replace function public._add_points(x uuid, y uuid, n int) returns void
language sql volatile as $$
  update public.friendships set points = least(points + n, 100000)
  where a = least(x, y) and b = greatest(x, y) and status = 'accepted'
$$;

-- Friendship level 1-5 from points (item 27).
create or replace function public._level(p int) returns int
language sql immutable as $$
  select case when p >= 100 then 5 when p >= 60 then 4 when p >= 30 then 3 when p >= 10 then 2 else 1 end
$$;

create or replace function public._week() returns text
language sql stable as $$
  select to_char(now() at time zone 'utc', 'IYYY-"W"IW')
$$;

create or replace function public._today() returns date
language sql stable as $$
  select (now() at time zone 'utc')::date
$$;

create or replace function public._fail(p_error text) returns jsonb
language sql immutable as $$
  select jsonb_build_object('ok', false, 'error', p_error)
$$;

-- The current week's world goal, created from the rotation when the week starts.
create or replace function public._goal() returns public.community_goals
language plpgsql volatile as $$
declare
  g public.community_goals;
  rot jsonb := public._config('goal_rotation', '[{"kind":"battles","target":5000}]');
  w text := public._week();
  pick jsonb;
begin
  select * into g from public.community_goals where week = w;
  if not found then
    pick := rot->(extract(week from now() at time zone 'utc')::int % jsonb_array_length(rot));
    insert into public.community_goals (week, kind, target) values (w, pick->>'kind', (pick->>'target')::int)
    on conflict (week) do nothing;
    -- A new week: weekly values older than last week are deleted (privacy policy 3.2).
    delete from public.community_contrib where week < to_char((now() - interval '7 days') at time zone 'utc', 'IYYY-"W"IW');
    delete from public.weekly_scores where week < to_char((now() - interval '7 days') at time zone 'utc', 'IYYY-"W"IW');
    delete from public.reports where created_at < now() - interval '6 months';
    select * into g from public.community_goals where week = w;
  end if;
  return g;
end $$;

-- Moving to a new phone also moves friends, mail and the rest (replaces the core version).
create or replace function public._move_account(p_old uuid, p_new uuid) returns void
language plpgsql volatile as $$
begin
  update public.profiles set id = p_new where id = p_old;
  update public.saves set user_id = p_new where user_id = p_old;
  delete from public.friendships where a = p_new or b = p_new;
  update public.friendships set a = least(p_new, b), b = greatest(p_new, b), requested_by = case when requested_by = p_old then p_new else requested_by end
    where a = p_old;
  update public.friendships set a = least(a, p_new), b = greatest(a, p_new), requested_by = case when requested_by = p_old then p_new else requested_by end
    where b = p_old;
  delete from public.blocks where blocker = p_new or blocked = p_new;
  update public.blocks set blocker = p_new where blocker = p_old;
  update public.blocks set blocked = p_new where blocked = p_old;
  delete from public.mail where sender = p_new or recipient = p_new;
  update public.mail set sender = p_new where sender = p_old;
  update public.mail set recipient = p_new where recipient = p_old;
  delete from public.community_contrib where user_id = p_new;
  update public.community_contrib set user_id = p_new where user_id = p_old;
  delete from public.weekly_scores where user_id = p_new;
  update public.weekly_scores set user_id = p_new where user_id = p_old;
  update public.reports set reporter = p_new where reporter = p_old;
end $$;

-- ---------------------------------------------------------------------------------------
-- Friends (items 21-33)

create or replace function public.friend_request(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  f public.friendships;
  lim int := coalesce((public._config('friend_limit', '100'))::text::int, 100);
begin
  perform public._ensure_profile(u);
  if not public._social(u) then return public._fail('social_off'); end if;
  -- Counted before the code is checked, so codes cannot be guessed quickly.
  if not public._rate_ok(u, 'friend', 20) then return public._fail('slow_down'); end if;
  if t is null or t = u then return public._fail('no_such_code'); end if;
  -- A block looks like an unknown code, so it cannot be probed.
  if public._blocked(u, t) or not public._social(t) then return public._fail('no_such_code'); end if;
  select * into f from public.friendships where a = least(u, t) and b = greatest(u, t);
  if found and f.status = 'accepted' then
    return jsonb_build_object('ok', true, 'status', 'accepted');
  end if;
  if (select count(*) from public.friendships where (a = u or b = u) and status = 'accepted') >= lim
     or (select count(*) from public.friendships where (a = t or b = t) and status = 'accepted') >= lim then
    return public._fail('full');
  end if;
  if found and f.requested_by = t then
    update public.friendships set status = 'accepted' where a = f.a and b = f.b;
    return jsonb_build_object('ok', true, 'status', 'accepted');
  end if;
  insert into public.friendships (a, b, status, requested_by) values (least(u, t), greatest(u, t), 'pending', u)
  on conflict (a, b) do nothing;
  return jsonb_build_object('ok', true, 'status', 'pending');
end $$;

create or replace function public.friend_respond(p_code text, p_accept boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null then return public._fail('no_such_code'); end if;
  if p_accept then
    update public.friendships set status = 'accepted'
      where a = least(u, t) and b = greatest(u, t) and status = 'pending' and requested_by = t;
  else
    delete from public.friendships where a = least(u, t) and b = greatest(u, t) and status = 'pending';
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.friend_remove(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  delete from public.friendships where a = least(u, t) and b = greatest(u, t);
  return jsonb_build_object('ok', true);
end $$;

-- Blocking ends the friendship and removes their mail at once (item 31).
create or replace function public.block(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or t = u then return public._fail('no_such_code'); end if;
  insert into public.blocks (blocker, blocked) values (u, t) on conflict do nothing;
  delete from public.friendships where a = least(u, t) and b = greatest(u, t);
  delete from public.mail where sender = t and recipient = u;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.unblock(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  delete from public.blocks where blocker = public._uid() and blocked = public._by_code(p_code);
  return jsonb_build_object('ok', true);
end $$;

-- Reasons: 0 name not okay, 1 unkind greetings, 2 cheating, 3 something else.
create or replace function public.report(p_code text, p_reason int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or t = u then return public._fail('no_such_code'); end if;
  if not public._rate_ok(u, 'report', 10) then return public._fail('slow_down'); end if;
  insert into public.reports (reporter, target, target_name, reason)
  values (u, t, (select name from public.profiles where id = t), least(greatest(coalesce(p_reason, 3), 0), 3));
  return jsonb_build_object('ok', true);
end $$;

-- Parents can switch friends, mail and greetings off (item 147). Saves stay online.
create or replace function public.set_social(p_on boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._ensure_profile(u);
  update public.profiles set social = coalesce(p_on, true) where id = u;
  return jsonb_build_object('ok', true, 'social', coalesce(p_on, true));
end $$;

create or replace function public.friends_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  today date := public._today();
begin
  perform public._ensure_profile(u);
  return jsonb_build_object(
    'friends', coalesce((select jsonb_agg(jsonb_build_object(
        'code', p.code, 'name', p.name, 'color', p.color, 'favorite', p.favorite, 'card', p.card,
        'place', p.place, 'online', p.last_seen > now() - interval '5 minutes',
        'last_seen', extract(epoch from p.last_seen)::bigint,
        'points', f.points, 'level', public._level(f.points),
        'has_team', jsonb_array_length(p.team) > 0,
        'gift_sent', exists (select 1 from public.mail m where m.sender = u and m.recipient = p.id
            and m.kind = 'gift' and (m.created_at at time zone 'utc')::date = today))
      order by p.last_seen desc)
      from public.friendships f join public.profiles p on p.id = case when f.a = u then f.b else f.a end
      where (f.a = u or f.b = u) and f.status = 'accepted'), '[]'::jsonb),
    'incoming', coalesce((select jsonb_agg(jsonb_build_object('code', p.code, 'name', p.name))
      from public.friendships f join public.profiles p on p.id = f.requested_by
      where (f.a = u or f.b = u) and f.status = 'pending' and f.requested_by <> u), '[]'::jsonb),
    'outgoing', coalesce((select jsonb_agg(jsonb_build_object('code', p.code, 'name', p.name))
      from public.friendships f join public.profiles p on p.id = case when f.a = u then f.b else f.a end
      where (f.a = u or f.b = u) and f.status = 'pending' and f.requested_by = u), '[]'::jsonb),
    'blocked', coalesce((select jsonb_agg(jsonb_build_object('code', p.code, 'name', p.name))
      from public.blocks bl join public.profiles p on p.id = bl.blocked where bl.blocker = u), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------------------
-- Mail: set phrases, waves, thanks, daily gifts (items 41-45, 57, 141-160)

create or replace function public.mail_send(p_code text, p_kind text, p_phrase int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if p_kind not in ('phrase', 'wave', 'thanks') then return public._fail('bad_kind'); end if;
  if t is null or not public._friends(u, t) or public._blocked(u, t) or not public._social(u) or not public._social(t) then
    return public._fail('not_friends');
  end if;
  if coalesce(p_phrase, -1) not between 0 and 31 then return public._fail('bad_phrase'); end if;
  if not public._rate_ok(u, 'mail', 30) then return public._fail('slow_down'); end if;
  insert into public.mail (sender, recipient, kind, phrase, place)
  values (u, t, p_kind, p_phrase, (select place from public.profiles where id = u));
  return jsonb_build_object('ok', true);
end $$;

-- One gift per friend per day. The item is rolled when it is opened.
create or replace function public.gift_send(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or not public._friends(u, t) or public._blocked(u, t) or not public._social(u) or not public._social(t) then
    return public._fail('not_friends');
  end if;
  if exists (select 1 from public.mail where sender = u and recipient = t and kind = 'gift'
      and (created_at at time zone 'utc')::date = public._today()) then
    return public._fail('already_today');
  end if;
  insert into public.mail (sender, recipient, kind, place) values (u, t, 'gift', (select place from public.profiles where id = u));
  perform public._add_points(u, t, 1);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.mail_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  -- Mail is kept for 30 days only (item 160).
  delete from public.mail where recipient = u and created_at < now() - interval '30 days';
  return coalesce((select jsonb_agg(r order by created_at desc) from (
      select jsonb_build_object('id', m.id, 'kind', m.kind, 'phrase', m.phrase, 'item', m.item,
          'place', m.place, 'opened', m.opened, 'at', extract(epoch from m.created_at)::bigint,
          'code', p.code, 'name', p.name) as r, m.created_at
      from public.mail m join public.profiles p on p.id = m.sender
      where m.recipient = u
      order by m.created_at desc limit 50) x), '[]'::jsonb);
end $$;

create or replace function public.gift_open(p_id bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  m public.mail;
  tbl jsonb := public._config('gift_table', '[{"item":"tonic","w":1}]');
  lim int := coalesce((public._config('gift_open_limit', '10'))::text::int, 10);
  total int;
  roll int;
  acc int := 0;
  e jsonb;
  pick text := 'tonic';
begin
  select * into m from public.mail where id = p_id and recipient = u and kind = 'gift' for update;
  if not found then return public._fail('no_such_gift'); end if;
  if m.opened then return jsonb_build_object('ok', true, 'item', m.item, 'again', true); end if;
  if (select count(*) from public.mail where recipient = u and kind = 'gift' and opened
      and (opened_at at time zone 'utc')::date = public._today()) >= lim then
    return public._fail('limit_today');
  end if;
  select sum((x->>'w')::int) into total from jsonb_array_elements(tbl) x;
  roll := floor(random() * total)::int;
  for e in select * from jsonb_array_elements(tbl) loop
    acc := acc + (e->>'w')::int;
    if roll < acc then pick := e->>'item'; exit; end if;
  end loop;
  update public.mail set opened = true, opened_at = now(), item = pick where id = m.id;
  return jsonb_build_object('ok', true, 'item', pick);
end $$;

create or replace function public.mail_open(p_id bigint) returns jsonb
language sql volatile security definer set search_path = public as $$
  with x as (update public.mail set opened = true, opened_at = coalesce(opened_at, now())
    where id = p_id and recipient = public._uid() and kind <> 'gift' returning 1)
  select jsonb_build_object('ok', exists (select 1 from x))
$$;

-- ---------------------------------------------------------------------------------------
-- Echo teams: a friend's team fights beside you (echo partner) or against you (echo duel).
-- The AI steers it; the friend does not need to be online (items 46-48, 61, 76-77, 121-124).

-- Stores this player's team as an echo. Only species, level and move names, never nicknames.
create or replace function public.team_set(p_team jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  clean jsonb := '[]'::jsonb;
  s jsonb;
  moves jsonb;
  mv jsonb;
begin
  perform public._ensure_profile(u);
  if jsonb_typeof(p_team) <> 'array' then return public._fail('bad_team'); end if;
  for s in select * from jsonb_array_elements(p_team) limit 6 loop
    moves := '[]'::jsonb;
    for mv in select * from jsonb_array_elements(case when jsonb_typeof(s->'moves') = 'array' then s->'moves' else '[]'::jsonb end) limit 4 loop
      moves := moves || to_jsonb(left(regexp_replace(mv #>> '{}', '[^[:alnum:] ''-]', '', 'g'), 24));
    end loop;
    clean := clean || jsonb_build_object(
      'species', left(regexp_replace(coalesce(s->>'species', ''), '[^[:alnum:]]', '', 'g'), 20),
      'level', least(greatest(coalesce((s->>'level')::numeric, 1), 1), 100)::int,
      'moves', moves);
  end loop;
  update public.profiles set team = clean where id = u;
  return jsonb_build_object('ok', true, 'size', jsonb_array_length(clean));
end $$;

create or replace function public.friend_team(p_code text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or not public._friends(u, t) then return public._fail('not_friends'); end if;
  return (select jsonb_build_object('ok', true, 'name', name, 'color', color, 'team', team) from public.profiles where id = t);
end $$;

-- After an echo partner battle or an echo duel: the friend gets a note and both get
-- friendship points, once per day and kind.
create or replace function public.echo_report(p_code text, p_kind text, p_won boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  pts int := case p_kind when 'echo' then 3 when 'duel' then 2 else 0 end;
begin
  if pts = 0 then return public._fail('bad_kind'); end if;
  if t is null or not public._friends(u, t) then return public._fail('not_friends'); end if;
  if exists (select 1 from public.mail where sender = u and recipient = t and kind = p_kind
      and (created_at at time zone 'utc')::date = public._today()) then
    return jsonb_build_object('ok', true, 'points', 0);
  end if;
  if public._social(t) and not public._blocked(u, t) then
    insert into public.mail (sender, recipient, kind, phrase, place)
    values (u, t, p_kind, case when p_won then 1 else 0 end, (select place from public.profiles where id = u));
  end if;
  perform public._add_points(u, t, pts);
  return jsonb_build_object('ok', true, 'points', pts);
end $$;

-- ---------------------------------------------------------------------------------------
-- World goal of the week (items 81-85, 99)

create or replace function public._goal_json(g public.community_goals, u uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object('week', g.week, 'kind', g.kind, 'target', g.target, 'total', g.total,
    'mine', coalesce((select amount from public.community_contrib where week = g.week and user_id = u), 0),
    'claimed', coalesce((select claimed from public.community_contrib where week = g.week and user_id = u), 0),
    'rewards', public._config('goal_rewards', '[]'),
    'online_now', (select count(*) from public.profiles where last_seen > now() - interval '5 minutes'))
$$;

create or replace function public.community_get() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  return public._goal_json(public._goal(), public._uid());
end $$;

-- Counts up to 5 per call and [goal_user_cap] per player and week, only for this week's kind.
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
  return public._goal_json(g, u);
end $$;

-- Tiers 1-4 open at 25/50/75/100 %. Anyone who helped this week can claim each tier once.
create or replace function public.community_claim(p_tier int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  g public.community_goals := public._goal();
  c public.community_contrib;
  bit int;
begin
  if p_tier not between 1 and 4 then return public._fail('bad_tier'); end if;
  bit := 1 << (p_tier - 1);
  select * into c from public.community_contrib where week = g.week and user_id = u for update;
  if not found or c.amount <= 0 then return public._fail('not_helped'); end if;
  if g.total * 4 < g.target::bigint * p_tier then return public._fail('not_reached'); end if;
  if c.claimed & bit <> 0 then return public._fail('claimed'); end if;
  update public.community_contrib set claimed = claimed | bit where week = g.week and user_id = u;
  return jsonb_build_object('ok', true, 'item', public._config('goal_rewards', '[]')->>(p_tier - 1));
end $$;

-- ---------------------------------------------------------------------------------------
-- Weekly challenge board (items 125-126, 137, 186)

-- Score = rounds won * 100 + team health left in percent (0..400). Only this week, best counts.
create or replace function public.weekly_submit(p_week text, p_score int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  if p_week <> public._week() then return public._fail('wrong_week'); end if;
  if coalesce(p_score, -1) not between 0 and 400 then return public._fail('implausible'); end if;
  perform public._ensure_profile(u);
  insert into public.weekly_scores (week, user_id, score) values (p_week, u, p_score)
  on conflict (week, user_id) do update set score = greatest(public.weekly_scores.score, excluded.score),
    at = case when excluded.score > public.weekly_scores.score then now() else public.weekly_scores.at end;
  return jsonb_build_object('ok', true);
end $$;

-- Top 20 of the week. Friends only shows you and your friends with names; the world board
-- shows names only for your friends (strangers stay "Tamer").
create or replace function public.weekly_board(p_friends boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  w text := public._week();
begin
  return jsonb_build_object('week', w,
    'rows', coalesce((select jsonb_agg(jsonb_build_object('rank', r.rank, 'score', r.score, 'me', r.user_id = u,
        'name', case when r.user_id = u or public._friends(u, r.user_id) then p.name else '' end) order by r.rank)
      from (select user_id, score, rank() over (order by score desc, at asc) as rank
            from public.weekly_scores s
            where s.week = w and (not p_friends or s.user_id = u or public._friends(u, s.user_id))) r
      join public.profiles p on p.id = r.user_id
      where r.rank <= 20 or r.user_id = u), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------------------

revoke all on function public._by_code(text), public._friends(uuid, uuid), public._blocked(uuid, uuid),
  public._social(uuid), public._rate_ok(uuid, text, int), public._add_points(uuid, uuid, int), public._level(int),
  public._week(), public._today(), public._fail(text), public._goal(), public._goal_json(public.community_goals, uuid)
  from public, anon, authenticated;
revoke all on function public.friend_request(text), public.friend_respond(text, boolean), public.friend_remove(text),
  public.block(text), public.unblock(text), public.report(text, int), public.set_social(boolean), public.friends_list(),
  public.mail_send(text, text, int), public.gift_send(text), public.mail_list(), public.gift_open(bigint),
  public.mail_open(bigint), public.team_set(jsonb), public.friend_team(text), public.echo_report(text, text, boolean),
  public.community_get(), public.community_add(text, int), public.community_claim(int),
  public.weekly_submit(text, int), public.weekly_board(boolean)
  from public, anon;
grant execute on function public.friend_request(text), public.friend_respond(text, boolean), public.friend_remove(text),
  public.block(text), public.unblock(text), public.report(text, int), public.set_social(boolean), public.friends_list(),
  public.mail_send(text, text, int), public.gift_send(text), public.mail_list(), public.gift_open(bigint),
  public.mail_open(bigint), public.team_set(jsonb), public.friend_team(text), public.echo_report(text, text, boolean),
  public.community_get(), public.community_add(text, int), public.community_claim(int),
  public.weekly_submit(text, int), public.weekly_board(boolean)
  to authenticated;
