-- Online 100, area 4: bund week goal (33), bund level from xp (34), donating items (36), bund board
-- (38), search by language and activity (39), open bunds anyone can join (40). Values in
-- server_config.bund_rules (data/bund_rules.json); LocalBackend and BundRules.gd do the same.

alter table public.bunds add column if not exists xp int not null default 0;
alter table public.bunds add column if not exists lang text not null default '';
alter table public.bunds add column if not exists open boolean not null default false;
alter table public.bunds add column if not exists goal_week text not null default '';
alter table public.bunds add column if not exists goal_progress int not null default 0;

create table if not exists public.bund_donations (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  count int not null default 0,
  primary key (user_id, day)
);
create table if not exists public.bund_goal_claims (
  bund_id bigint not null references public.bunds (id) on delete cascade,
  week text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (bund_id, week, user_id)
);
alter table public.bund_donations enable row level security;
alter table public.bund_goal_claims enable row level security;
revoke all on public.bund_donations, public.bund_goal_claims from public, anon, authenticated;

create or replace function public._bund_rules() returns jsonb
language sql stable as $$
  select public._config('bund_rules', '{"langs": ["de", "en"], "xp_per_item": 10, "xp_per_level": 500, "level_max": 20,
    "donate_daily": 20, "goal_target": 200, "goal_reward": {"item": "strong_tonic", "count": 3}, "active_days": 7,
    "board_rows": 20, "search_rows": 20}'::jsonb)
$$;

create or replace function public._bund_level(p_xp int) returns int
language sql stable as $$
  select least(coalesce((public._bund_rules()->>'level_max')::int, 20),
    1 + p_xp / greatest(1, coalesce((public._bund_rules()->>'xp_per_level')::int, 500)))
$$;

-- The bund's progress this week (a new week starts at 0).
create or replace function public._bund_goal(p_bund bigint) returns int
language sql stable as $$
  select case when goal_week = public._week() then goal_progress else 0 end from public.bunds where id = p_bund
$$;

-- Level, xp, language, open flag and week goal of the caller's bund.
create or replace function public.bund_stats() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  x public.bunds;
  br jsonb := public._bund_rules();
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  select * into x from public.bunds where id = b;
  return jsonb_build_object('ok', true, 'xp', x.xp, 'level', public._bund_level(x.xp), 'lang', x.lang, 'open', x.open,
    'goal', public._bund_goal(b), 'goal_target', (br->>'goal_target')::int, 'goal_reward', br->'goal_reward',
    'goal_claimed', exists (select 1 from public.bund_goal_claims where bund_id = b and week = public._week() and user_id = u),
    'donated_today', coalesce((select count from public.bund_donations where user_id = u and day = current_date), 0),
    'donate_daily', (br->>'donate_daily')::int);
end $$;

-- The leader sets language and whether anyone may join (points 39, 40).
create or replace function public.bund_settings(p_lang text, p_open boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
begin
  if e is not null then return public._fail(e); end if;
  if b is null or public._bund_role(u) <> 'leader' then return public._fail('not_allowed'); end if;
  if p_lang is null or (p_lang <> '' and not (public._bund_rules()->'langs') ? p_lang) then return public._fail('bad_lang'); end if;
  update public.bunds set lang = p_lang, open = coalesce(p_open, false) where id = b;
  return jsonb_build_object('ok', true);
end $$;

-- Bunds to join: same language (or any), not full, nobody blocked, most active first (point 39).
create or replace function public.bund_search(p_lang text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  br jsonb := public._bund_rules();
begin
  if e is not null then return public._fail(e); end if;
  if not public._rate_ok(u, 'bund_search', 60) then return public._fail('slow_down'); end if;
  return jsonb_build_object('ok', true, 'bunds', coalesce((
    with c as (
      select x.id, x.name_a, x.name_b, x.lang, x.open, x.xp,
        (select count(*) from public.bund_members m where m.bund_id = x.id) size,
        (select count(*) from public.bund_members m join public.profiles p on p.id = m.user_id
          where m.bund_id = x.id and p.last_seen > now() - make_interval(days => (br->>'active_days')::int)) active
      from public.bunds x
      where (coalesce(p_lang, '') = '' or x.lang = p_lang) and x.dissolve_at is null
        and not exists (select 1 from public.bund_members m where m.bund_id = x.id and public._blocked(u, m.user_id))
    ), t as (
      select * from c where size < public._config_int('bund_max', 30)
      order by active desc, size desc, id limit (br->>'search_rows')::int
    )
    select jsonb_agg(jsonb_build_object('bund', id, 'name', jsonb_build_array(name_a, name_b), 'lang', lang, 'open', open,
      'level', public._bund_level(xp), 'size', size, 'active', active) order by active desc, size desc, id) from t), '[]'::jsonb));
end $$;

-- Join an open bund at once, or ask to join a closed one (point 40).
create or replace function public.bund_join(p_bund bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  x public.bunds;
begin
  if e is not null then return public._fail(e); end if;
  select * into x from public.bunds where id = p_bund;
  if x.id is null or exists (select 1 from public.bund_members m where m.bund_id = x.id and public._blocked(u, m.user_id)) then
    return public._fail('no_such_bund');
  end if;
  if public._bund_id(u) is not null then return public._fail('in_bund'); end if;
  if not public._rate_ok(u, 'bund_request', 10) then return public._fail('slow_down'); end if;
  if x.open then
    e := public._bund_join(x.id, u, 'member');
    if e is not null then return public._fail(e); end if;
    return jsonb_build_object('ok', true, 'joined', true);
  end if;
  insert into public.bund_invites (bund_id, user_id, kind, by_user) values (x.id, u, 'request', u)
  on conflict (bund_id, user_id) do nothing;
  return jsonb_build_object('ok', true, 'joined', false);
end $$;

-- Donate items from the stored bag: xp for the bund and progress on the week goal (points 33, 36).
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
  if done + p_count > (br->>'donate_daily')::int then return public._fail('limit_today'); end if;
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

-- Once the week goal is reached every member takes the reward once (point 33).
create or replace function public.bund_goal_claim(p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  rw jsonb := public._bund_rules()->'goal_reward';
  r jsonb;
begin
  if e is not null then return public._fail(e); end if;
  if b is null then return public._fail('no_bund'); end if;
  if public._bund_goal(b) < (public._bund_rules()->>'goal_target')::int then return public._fail('goal_open'); end if;
  if exists (select 1 from public.bund_goal_claims where bund_id = b and week = public._week() and user_id = u) then
    return public._fail('claimed');
  end if;
  r := public._trade_bag(u, p_slot, p_rev, jsonb_build_object(rw->>'item', (rw->>'count')::int));
  if not (r->>'ok')::boolean then return r; end if;
  insert into public.bund_goal_claims (bund_id, week, user_id) values (b, public._week(), u);
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'item', rw->>'item', 'count', (rw->>'count')::int,
    'bag', jsonb_build_object(rw->>'item', (rw->>'count')::int));
end $$;

-- Bunds by xp (point 38): names as word numbers, no members.
create or replace function public.bund_board() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
begin
  if e is not null then return public._fail(e); end if;
  return jsonb_build_object('ok', true, 'rows', coalesce((select jsonb_agg(r order by xp desc, id) from (
    select x.id, x.xp, jsonb_build_object('name', jsonb_build_array(x.name_a, x.name_b), 'xp', x.xp,
      'level', public._bund_level(x.xp), 'mine', x.id = public._bund_id(u)) r
    from public.bunds x where x.dissolve_at is null order by x.xp desc, x.id
    limit (public._bund_rules()->>'board_rows')::int) s), '[]'::jsonb));
end $$;

revoke all on function public._bund_rules(), public._bund_level(int), public._bund_goal(bigint)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.bund_stats(), public.bund_settings(text, boolean), public.bund_search(text), public.bund_join(bigint),
  public.bund_donate(int, int, text, int), public.bund_goal_claim(int, int), public.bund_board() from public, anon, chimora_referee;
grant execute on function public.bund_stats(), public.bund_settings(text, boolean), public.bund_search(text), public.bund_join(bigint),
  public.bund_donate(int, int, text, int), public.bund_goal_claim(int, int), public.bund_board() to authenticated;
