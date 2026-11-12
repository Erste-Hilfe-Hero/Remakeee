-- Online 100, area 6 (points 53, 55, 56, 57, 59, 60): friends and the shared world.
--   53  the Wanderer card shows the friend's league rank (beside favourite Spirling and sealed Rifts)
--   55  invite link: a new account redeems a friend code within invite_days, which sends a friend
--       request; once it is accepted both take invite_reward (flag "invite", off at first; the
--       inviter at most invite_max times)
--   56  friendship levels 6-10 (floors in levels), each with a reward taken once per friend
--   57  a joint task of the day with each friend: both send each other today's mail kind
--   59  favourite friends at the top of the list (at most favorites_max)
--   60  recent league opponents as friend suggestions, shown without names
-- Values in server_config.friends_more (data/friends_more.json). LocalBackend does the same
-- (scripts/online/LocalFriendsMore.gd, scripts/online/FriendRules.gd). Re-runnable.

insert into public.feature_flags (key, enabled, min_version, note) values
  ('invite', false, 1, 'Einladungs-Link mit Belohnung')
on conflict (key) do nothing;

create or replace function public._fm() returns jsonb
language sql stable as $$
  select '{"levels": [0, 10, 30, 60, 100, 150, 220, 300, 400, 520],
    "level_rewards": {"6": {"item": "strong_tonic", "count": 3}, "7": {"item": "max_tonic", "count": 2},
      "8": {"item": "revival_leaf", "count": 2}, "9": {"item": "spark_charm", "count": 1},
      "10": {"item": "keen_lens", "count": 1}},
    "favorites_max": 10, "pair_tasks": ["wave", "phrase", "gift"], "pair_reward": {"item": "tonic", "count": 2},
    "pair_points": 3, "suggest_days": 14, "suggest_max": 5, "invite_days": 7, "invite_max": 10,
    "invite_reward": {"item": "strong_tonic", "count": 2}}'::jsonb
    || case when jsonb_typeof(public._config('friends_more', '{}'::jsonb)) = 'object'
      then public._config('friends_more', '{}'::jsonb) else '{}'::jsonb end
$$;

-- 56: friendship level 1-10 from points (levels 1-5 keep their floors 0, 10, 30, 60, 100).
create or replace function public._level(p int) returns int
language sql stable as $$
  select greatest(1, (select count(*)::int from jsonb_array_elements(public._fm()->'levels') x
    where coalesce(p, 0) >= (x #>> '{}')::int))
$$;

create table if not exists public.friend_favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  friend uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend)
);
create table if not exists public.friend_level_claims (
  user_id uuid not null references auth.users (id) on delete cascade,
  friend uuid not null references auth.users (id) on delete cascade,
  level int not null,
  at timestamptz not null default now(),
  primary key (user_id, friend, level)
);
create table if not exists public.pair_task_claims (
  user_id uuid not null references auth.users (id) on delete cascade,
  friend uuid not null references auth.users (id) on delete cascade,
  day date not null,
  primary key (user_id, friend, day)
);
create table if not exists public.invites (
  invitee uuid primary key references auth.users (id) on delete cascade,
  inviter uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  invitee_paid boolean not null default false,
  inviter_paid boolean not null default false
);
create index if not exists invites_inviter on public.invites (inviter);
alter table public.friend_favorites enable row level security;
alter table public.friend_level_claims enable row level security;
alter table public.pair_task_claims enable row level security;
alter table public.invites enable row level security;
revoke all on public.friend_favorites, public.friend_level_claims, public.pair_task_claims, public.invites
  from public, anon, authenticated, chimora_referee;

-- [p_reward] ({"item", "count"}) [p_times] times into the bag of [u]'s stored save.
create or replace function public._fm_pay(u uuid, p_slot int, p_rev int, p_reward jsonb, p_times int) returns jsonb
language plpgsql volatile as $$
declare r jsonb;
begin
  r := public._trade_save(u, p_slot, p_rev,
    jsonb_build_object(p_reward->>'item', coalesce((p_reward->>'count')::int, 1) * p_times), '{}'::text[], '[]'::jsonb);
  if not (r->>'ok')::boolean then return r; end if;
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'item', p_reward->>'item',
    'count', coalesce((p_reward->>'count')::int, 1) * p_times,
    'bag', jsonb_build_object(p_reward->>'item', coalesce((p_reward->>'count')::int, 1) * p_times));
end $$;

-- 57: today's joint task kind (the same for everyone, taken in turn by day).
create or replace function public._pair_kind() returns text
language sql stable as $$
  select public._fm()->'pair_tasks'->>((public._today() - date '1970-01-01') % greatest(1, jsonb_array_length(public._fm()->'pair_tasks')))
$$;

create or replace function public._pair_task(u uuid, t uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object('kind', k,
    'mine', exists (select 1 from public.mail where sender = u and recipient = t and kind = k
      and (created_at at time zone 'utc')::date = public._today()),
    'theirs', exists (select 1 from public.mail where sender = t and recipient = u and kind = k
      and (created_at at time zone 'utc')::date = public._today()),
    'claimed', exists (select 1 from public.pair_task_claims where user_id = u and friend = t and day = public._today()))
  from (select public._pair_kind() as k) x
$$;

-- 56: levels 6 and up that [u] reached with [t] and did not take the reward for yet.
create or replace function public._level_ready(u uuid, p_points int, t uuid) returns jsonb
language sql stable as $$
  select coalesce(jsonb_agg(l order by l), '[]'::jsonb) from generate_series(6, public._level(p_points)) l
  where public._fm()->'level_rewards' ? l::text
    and not exists (select 1 from public.friend_level_claims c where c.user_id = u and c.friend = t and c.level = l)
$$;

-- 53: league rank of [t] in the fair league of their latest season (-1 = none or placement).
create or replace function public._card_rank(t uuid) returns int
language sql stable as $$
  select coalesce((select public._league_rank(e.rating, e.games) from public.league_fair_entries e
    where e.user_id = t order by e.season desc limit 1), -1)
$$;

-- friends_list as in 20261112000050_trade_gifts.sql, plus favourite mark, card rank, levels with a
-- reward ready and today's joint task; favourites first.
create or replace function public.friends_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._ensure_profile(u);
  return jsonb_build_object(
    'friends', coalesce((select jsonb_agg(jsonb_build_object(
        'code', p.code, 'name', p.name, 'color', p.color, 'favorite', p.favorite, 'card', p.card,
        'place', p.place, 'online', p.last_seen > now() - interval '5 minutes',
        'last_seen', extract(epoch from p.last_seen)::bigint,
        'points', f.points, 'level', public._level(f.points),
        'has_team', jsonb_array_length(p.team) > 0,
        'wishes', p.wishes,
        'gifts_left', public._gifts_left(u, p.id),
        'gift_sent', public._gifts_left(u, p.id) = 0,
        'fav', fv.friend is not null,
        'rank', public._card_rank(p.id),
        'level_ready', public._level_ready(u, f.points, p.id),
        'task', public._pair_task(u, p.id))
      order by (fv.friend is not null) desc, p.last_seen desc)
      from public.friendships f join public.profiles p on p.id = case when f.a = u then f.b else f.a end
      left join public.friend_favorites fv on fv.user_id = u and fv.friend = p.id
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
-- 59: favourite friends

create or replace function public.friend_favorite(p_code text, p_on boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or not public._friends(u, t) or public._blocked(u, t) then return public._fail('not_friends'); end if;
  if not coalesce(p_on, false) then
    delete from public.friend_favorites where user_id = u and friend = t;
    return jsonb_build_object('ok', true, 'fav', false);
  end if;
  if not exists (select 1 from public.friend_favorites where user_id = u and friend = t)
     and (select count(*) from public.friend_favorites fv where fv.user_id = u and public._friends(u, fv.friend))
       >= (public._fm()->>'favorites_max')::int then
    return public._fail('favorites_full');
  end if;
  insert into public.friend_favorites (user_id, friend) values (u, t) on conflict do nothing;
  return jsonb_build_object('ok', true, 'fav', true);
end $$;

-- ---------------------------------------------------------------------------------------
-- 56: rewards of friendship levels 6-10

create or replace function public.friend_level_claim(p_code text, p_level int, p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  pts int;
  rw jsonb := public._fm()->'level_rewards'->(p_level::text);
  r jsonb;
begin
  if t is null or not public._friends(u, t) or public._blocked(u, t) then return public._fail('not_friends'); end if;
  if rw is null then return public._fail('bad_level'); end if;
  select points into pts from public.friendships where a = least(u, t) and b = greatest(u, t);
  if public._level(pts) < p_level then return public._fail('friend_level'); end if;
  if exists (select 1 from public.friend_level_claims where user_id = u and friend = t and level = p_level) then
    return public._fail('already');
  end if;
  r := public._fm_pay(u, p_slot, p_rev, rw, 1);
  if not (r->>'ok')::boolean then return r; end if;
  insert into public.friend_level_claims (user_id, friend, level) values (u, t, p_level);
  return r;
end $$;

-- ---------------------------------------------------------------------------------------
-- 57: the joint task of the day

create or replace function public.pair_task_claim(p_code text, p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  task jsonb;
  r jsonb;
begin
  if t is null or not public._friends(u, t) or public._blocked(u, t) or not public._social(u) or not public._social(t) then
    return public._fail('not_friends');
  end if;
  delete from public.pair_task_claims where day < public._today() - 7;
  task := public._pair_task(u, t);
  if (task->>'claimed')::boolean then return public._fail('already_today'); end if;
  if not ((task->>'mine')::boolean and (task->>'theirs')::boolean) then return public._fail('not_done'); end if;
  r := public._fm_pay(u, p_slot, p_rev, public._fm()->'pair_reward', 1);
  if not (r->>'ok')::boolean then return r; end if;
  -- The pair gets the friendship points once, with the first of the two claims.
  if not exists (select 1 from public.pair_task_claims where user_id = t and friend = u and day = public._today()) then
    perform public._add_points(u, t, (public._fm()->>'pair_points')::int);
  end if;
  insert into public.pair_task_claims (user_id, friend, day) values (u, t, public._today());
  return r || jsonb_build_object('points', (public._fm()->>'pair_points')::int);
end $$;

-- ---------------------------------------------------------------------------------------
-- 60: recent league opponents as friend suggestions

-- The opponent of [u]'s league match [p_match] when it can be suggested, else null.
create or replace function public._suggest_target(u uuid, p_match bigint) returns uuid
language sql stable as $$
  select m.opponent from public.league_matches m
  where m.id = p_match and m.user_id = u and m.opponent is not null and m.opponent <> u
    and m.created_at > now() - make_interval(days => (public._fm()->>'suggest_days')::int)
    and not exists (select 1 from public.friendships f where f.a = least(u, m.opponent) and f.b = greatest(u, m.opponent))
    and not public._blocked(u, m.opponent) and public._social(m.opponent)
$$;

create or replace function public.friend_suggestions() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._ensure_profile(u);
  if not public._social(u) then return jsonb_build_object('ok', true, 'rows', '[]'::jsonb); end if;
  return jsonb_build_object('ok', true, 'rows', coalesce((select jsonb_agg(jsonb_build_object('ref', x.id,
      'at', extract(epoch from x.created_at)::bigint, 'league', x.league, 'rank', public._card_rank(x.opponent))
      order by x.created_at desc)
    from (select * from (select distinct on (m.opponent) m.id, m.opponent, m.created_at, m.league
        from public.league_matches m where m.user_id = u and public._suggest_target(u, m.id) is not null
        order by m.opponent, m.created_at desc) z
      order by z.created_at desc limit (public._fm()->>'suggest_max')::int) x), '[]'::jsonb));
end $$;

-- A friend request to the opponent of league match [p_match]; their code stays hidden.
create or replace function public.friend_suggest_request(p_match bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._suggest_target(u, p_match);
begin
  if t is null then return public._fail('no_such_code'); end if;
  return public.friend_request((select code from public.profiles where id = t));
end $$;

-- ---------------------------------------------------------------------------------------
-- 55: invite link with a reward for both

create or replace function public.invite_redeem(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  r jsonb;
begin
  if not public._flag_on('invite', 2147483647) then return public._fail('feature_off'); end if;
  perform public._ensure_profile(u);
  if exists (select 1 from public.invites where invitee = u) then return public._fail('already'); end if;
  if (select created_at from public.profiles where id = u)
      < now() - make_interval(days => (public._fm()->>'invite_days')::int) then
    return public._fail('too_late');
  end if;
  if t is null or t = u then return public._fail('no_such_code'); end if;
  r := public.friend_request(p_code);
  if not (r->>'ok')::boolean then return r; end if;
  insert into public.invites (invitee, inviter) values (u, t);
  return r;
end $$;

-- Rewards [u] can take now: their own invite (once accepted) and accepted friends they invited,
-- up to invite_max paid ones.
create or replace function public._invite_due(u uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'self', exists (select 1 from public.invites i where i.invitee = u and not i.invitee_paid and public._friends(u, i.inviter)),
    'others', least(
      (select count(*)::int from public.invites i where i.inviter = u and not i.inviter_paid and public._friends(u, i.invitee)),
      greatest(0, (public._fm()->>'invite_max')::int
        - (select count(*)::int from public.invites i where i.inviter = u and i.inviter_paid))))
$$;

create or replace function public.invite_state() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d jsonb;
begin
  if not public._flag_on('invite', 2147483647) then return public._fail('feature_off'); end if;
  perform public._ensure_profile(u);
  d := public._invite_due(u);
  return jsonb_build_object('ok', true, 'code', (select code from public.profiles where id = u),
    'can_redeem', not exists (select 1 from public.invites where invitee = u)
      and (select created_at from public.profiles where id = u) >= now() - make_interval(days => (public._fm()->>'invite_days')::int),
    'invited', (select count(*)::int from public.invites where inviter = u),
    'paid', (select count(*)::int from public.invites where inviter = u and inviter_paid),
    'max', (public._fm()->>'invite_max')::int,
    'ready', (case when (d->>'self')::boolean then 1 else 0 end) + (d->>'others')::int,
    'reward', public._fm()->'invite_reward');
end $$;

create or replace function public.invite_claim(p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d jsonb;
  n int;
  r jsonb;
begin
  if not public._flag_on('invite', 2147483647) then return public._fail('feature_off'); end if;
  d := public._invite_due(u);
  n := (case when (d->>'self')::boolean then 1 else 0 end) + (d->>'others')::int;
  if n <= 0 then return public._fail('nothing'); end if;
  r := public._fm_pay(u, p_slot, p_rev, public._fm()->'invite_reward', n);
  if not (r->>'ok')::boolean then return r; end if;
  if (d->>'self')::boolean then
    update public.invites set invitee_paid = true where invitee = u;
  end if;
  update public.invites set inviter_paid = true where invitee in (select i.invitee from public.invites i
    where i.inviter = u and not i.inviter_paid and public._friends(u, i.invitee)
    order by i.created_at limit (d->>'others')::int);
  return r || jsonb_build_object('times', n);
end $$;

revoke all on function public._fm(), public._fm_pay(uuid, int, int, jsonb, int), public._pair_kind(),
  public._pair_task(uuid, uuid), public._level_ready(uuid, int, uuid), public._card_rank(uuid),
  public._suggest_target(uuid, bigint), public._invite_due(uuid)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.friends_list(), public.friend_favorite(text, boolean),
  public.friend_level_claim(text, int, int, int), public.pair_task_claim(text, int, int), public.friend_suggestions(),
  public.friend_suggest_request(bigint), public.invite_redeem(text), public.invite_state(), public.invite_claim(int, int)
  from public, anon, chimora_referee;
grant execute on function public.friends_list(), public.friend_favorite(text, boolean),
  public.friend_level_claim(text, int, int, int), public.pair_task_claim(text, int, int), public.friend_suggestions(),
  public.friend_suggest_request(bigint), public.invite_redeem(text), public.invite_state(), public.invite_claim(int, int)
  to authenticated;
