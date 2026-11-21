-- Plan area 7, items 2791-2795 and the trade part of 2900: trading items between friends.
-- Only confirmed friends from friendship level 3 who have been friends for at least 7 days can
-- trade, never blocked players. Only items listed in trade_items (filled from "tradeable": true in
-- data/items.json by tools/online/game_data_sql.py) can be traded; shop items never are, and
-- Spirlings never are. The server is the trustee: whatever a player puts in leaves the bag of the
-- stored save at once and waits in trade_sides; when both confirmed, each side receives the other's
-- items in one transaction (or nothing happens). Changing an offer resets both confirmations.
-- Every change of a stored save happens in a call of that save's own device, which sends the
-- revision it knows, so the device can change its bag the same way and keep saving normally.
-- trades carries no account id, so deleting an account never removes the other side's items.

insert into public.server_config (key, value) values
  ('trade_min_level', '3'), ('trade_min_days', '7'), ('trade_max_open', '5'), ('trade_max_kinds', '6'),
  ('trade_max_count', '99'), ('trade_days', '7'),
  ('trade_items', '["tonic", "strong_tonic", "remedy", "spark_drop", "revival_leaf", "kin_charm", "spark_coil", "bark_wrap", "iron_burr", "swift_feather", "keen_lens", "max_tonic", "cooling_gel", "dry_towel", "wake_bell", "power_brew", "guard_brew", "focus_brew", "dash_brew", "tide_pearl", "spark_charm", "echo_ember", "echo_tide", "echo_bloom", "echo_volt", "echo_stone", "echo_gale", "echo_lumen", "echo_umbra"]')
on conflict (key) do nothing;

-- When a friendship was accepted (item 2791 counts 7 days from here). Older friendships count from
-- the request.
alter table public.friendships add column if not exists accepted_at timestamptz;
update public.friendships set accepted_at = created_at where status = 'accepted' and accepted_at is null;

create or replace function public._friend_accepted() returns trigger
language plpgsql as $$
begin
  if new.status = 'accepted' and (tg_op = 'INSERT' or old.status is distinct from 'accepted') then
    new.accepted_at := now();
  end if;
  return new;
end $$;
drop trigger if exists friendships_accepted on public.friendships;
create trigger friendships_accepted before insert or update of status on public.friendships
  for each row execute function public._friend_accepted();

create table if not exists public.trades (
  id bigserial primary key,
  state text not null default 'open' check (state in ('open', 'done', 'cancelled')),
  created_at timestamptz not null default now(),
  closes_at timestamptz not null,
  done_at timestamptz
);
create table if not exists public.trade_sides (
  trade_id bigint not null references public.trades (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  -- What this side put in ({item id: count}); it already left this side's bag.
  items jsonb not null default '{}'::jsonb,
  confirmed boolean not null default false,
  -- What this side gets when it collects: the other side's items once done, its own if cancelled.
  receive jsonb,
  collected boolean not null default false,
  primary key (trade_id, user_id)
);
create index if not exists trade_sides_user on public.trade_sides (user_id, collected);
alter table public.trades enable row level security;
alter table public.trade_sides enable row level security;
revoke all on public.trades, public.trade_sides from public, anon, authenticated, chimora_referee;

create or replace function public._trade_check(u uuid) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if not public._flag_on('trade', 2147483647) then return 'feature_off'; end if;
  if not public._social(u) then return 'social_off'; end if;
  if public._cheat_held(u) then return 'under_review'; end if;
  return null;
end $$;

-- Why [x] and [y] cannot trade, or null.
create or replace function public._trade_pair(x uuid, y uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare f public.friendships;
begin
  if x is null or y is null or x = y or public._blocked(x, y) or not public._social(y) then return 'no_such_code'; end if;
  select * into f from public.friendships where a = least(x, y) and b = greatest(x, y) and status = 'accepted';
  if not found then return 'no_such_code'; end if;
  if public._level(f.points) < public._config_int('trade_min_level', 3) then return 'friend_level'; end if;
  if coalesce(f.accepted_at, f.created_at) > now() - make_interval(days => public._config_int('trade_min_days', 7)) then
    return 'too_new';
  end if;
  return null;
end $$;

-- A clean offer {item: count} or null when it breaks a rule (2792, 2793).
create or replace function public._trade_offer(p jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  ok jsonb := coalesce(public._config('trade_items', '[]'), '[]'::jsonb);
  k text;
  v jsonb;
  n int;
  out jsonb := '{}'::jsonb;
begin
  if p is null or jsonb_typeof(p) <> 'object' then return null; end if;
  if (select count(*) from jsonb_object_keys(p)) > public._config_int('trade_max_kinds', 6) then return null; end if;
  for k, v in select * from jsonb_each(p) loop
    if jsonb_typeof(v) <> 'number' or not ok ? k then return null; end if;
    if (v #>> '{}')::numeric <> floor((v #>> '{}')::numeric) then return null; end if;
    n := (v #>> '{}')::numeric::int;
    if n < 0 or n > public._config_int('trade_max_count', 99) then return null; end if;
    if n > 0 then out := out || jsonb_build_object(k, n); end if;
  end loop;
  return out;
end $$;

-- Changes the bag of [u]'s stored save in [p_slot] by [p_delta] ({item: +n/-n}). The device must
-- know the stored revision, so it can make the same change and save on top of the new revision.
-- Returns {ok, rev} or a failure.
create or replace function public._trade_bag(u uuid, p_slot int, p_rev int, p_delta jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  s public.saves;
  inv jsonb;
  k text;
  v jsonb;
  n int;
begin
  select * into s from public.saves where user_id = u and slot = p_slot for update;
  if not found then return public._fail('no_save'); end if;
  if s.rev <> coalesce(p_rev, -1) then return public._fail('sync_first'); end if;
  inv := case when jsonb_typeof(s.data->'inventory') = 'object' then s.data->'inventory' else '{}'::jsonb end;
  for k, v in select * from jsonb_each(coalesce(p_delta, '{}'::jsonb)) loop
    n := coalesce((inv->>k)::numeric::int, 0) + (v #>> '{}')::int;
    if n < 0 then return public._fail('not_enough'); end if;
    inv := case when n = 0 then inv - k else inv || jsonb_build_object(k, n) end;
  end loop;
  update public.saves set data = jsonb_set(data, '{inventory}', inv), rev = s.rev + 1, saved_at = now(), request_id = null
  where user_id = u and slot = p_slot;
  return jsonb_build_object('ok', true, 'rev', s.rev + 1);
end $$;

-- Open trades past their time end by themselves; finished ones go once both sides collected.
create or replace function public._trade_tidy() returns void
language sql volatile security definer set search_path = public as $$
  update public.trade_sides d set receive = d.items
  from public.trades t where t.id = d.trade_id and t.state = 'open' and t.closes_at < now();
  update public.trades set state = 'cancelled' where state = 'open' and closes_at < now();
  delete from public.trades t where t.state <> 'open'
    and (not exists (select 1 from public.trade_sides d where d.trade_id = t.id and not d.collected)
      or t.created_at < now() - interval '90 days');
$$;

create or replace function public.trade_open(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  why text := public._trade_check(u);
  old bigint;
  r bigint;
begin
  if why is not null then return public._fail(why); end if;
  why := public._trade_pair(u, t);
  if why is not null then return public._fail(why); end if;
  perform public._trade_tidy();
  select x.trade_id into old from public.trade_sides x join public.trade_sides y on y.trade_id = x.trade_id
    join public.trades tr on tr.id = x.trade_id
  where x.user_id = u and y.user_id = t and tr.state = 'open' limit 1;
  if old is not null then return jsonb_build_object('ok', true, 'trade', old, 'again', true); end if;
  if (select count(*) from public.trade_sides x join public.trades tr on tr.id = x.trade_id
      where x.user_id = u and tr.state = 'open') >= public._config_int('trade_max_open', 5) then
    return public._fail('too_many');
  end if;
  if not public._rate_ok(u, 'trade_open', 10) then return public._fail('slow_down'); end if;
  insert into public.trades (closes_at) values (now() + make_interval(days => public._config_int('trade_days', 7)))
  returning id into r;
  insert into public.trade_sides (trade_id, user_id) values (r, u), (r, t);
  return jsonb_build_object('ok', true, 'trade', r);
end $$;

-- The caller's trades: both offers, both confirmations, whether there is something to collect.
create or replace function public.trade_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._trade_tidy();
  return jsonb_build_object('ok', true, 'trades', coalesce((
    select jsonb_agg(jsonb_build_object('id', t.id, 'state', t.state,
        'closes_at', extract(epoch from t.closes_at)::bigint,
        'code', case when o.user_id is not null and not public._blocked(u, o.user_id) then p.code end,
        'name', case when o.user_id is not null and not public._blocked(u, o.user_id) then p.name end,
        'mine', m.items, 'theirs', coalesce(o.items, '{}'::jsonb),
        'my_ok', m.confirmed, 'their_ok', coalesce(o.confirmed, false),
        'collect', t.state <> 'open' and not m.collected) order by t.id desc)
    from public.trade_sides m
    join public.trades t on t.id = m.trade_id
    left join public.trade_sides o on o.trade_id = m.trade_id and o.user_id <> m.user_id
    left join public.profiles p on p.id = o.user_id
    where m.user_id = u and (t.state = 'open' or not m.collected)), '[]'::jsonb),
    'items', public._config('trade_items', '[]'));
end $$;

-- Sets the caller's offer to exactly [p_items]; the difference leaves or returns to the bag of the
-- stored save in [p_slot] (the answer's "bag" is that change). Both confirmations reset (2795).
create or replace function public.trade_put(p_trade bigint, p_slot int, p_rev int, p_items jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  why text := public._trade_check(u);
  m public.trade_sides;
  other uuid;
  offer jsonb := public._trade_offer(p_items);
  delta jsonb := '{}'::jsonb;
  k text;
  d int;
  r jsonb;
begin
  if why is not null then return public._fail(why); end if;
  perform public._trade_tidy();
  select x.* into m from public.trade_sides x join public.trades t on t.id = x.trade_id
  where x.trade_id = p_trade and x.user_id = u and t.state = 'open' for update of x;
  if not found then return public._fail('no_such_trade'); end if;
  select user_id into other from public.trade_sides where trade_id = p_trade and user_id <> u;
  why := public._trade_pair(u, other);
  if why is not null then return public._fail('partner_gone'); end if;
  if offer is null then return public._fail('not_tradeable'); end if;
  if not public._rate_ok(u, 'trade_put', 60) then return public._fail('slow_down'); end if;
  for k in select x from jsonb_object_keys(m.items || offer) x loop
    d := coalesce((m.items->>k)::int, 0) - coalesce((offer->>k)::int, 0);
    if d <> 0 then delta := delta || jsonb_build_object(k, d); end if;
  end loop;
  r := public._trade_bag(u, p_slot, p_rev, delta);
  if not (r->>'ok')::boolean then return r; end if;
  update public.trade_sides set items = offer where trade_id = p_trade and user_id = u;
  update public.trade_sides set confirmed = false where trade_id = p_trade;
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'bag', delta);
end $$;

-- Confirms the trade as the caller sees it: [p_theirs] must be the other side's offer right now,
-- so a change in the last second can never slip through. Both confirmed: the trade is done (2794).
create or replace function public.trade_confirm(p_trade bigint, p_theirs jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  why text := public._trade_check(u);
  m public.trade_sides;
  o public.trade_sides;
begin
  if why is not null then return public._fail(why); end if;
  perform public._trade_tidy();
  select x.* into m from public.trade_sides x join public.trades t on t.id = x.trade_id
  where x.trade_id = p_trade and x.user_id = u and t.state = 'open' for update of t;
  if not found then return public._fail('no_such_trade'); end if;
  select * into o from public.trade_sides where trade_id = p_trade and user_id <> u;
  if not found or public._trade_pair(u, o.user_id) is not null then return public._fail('partner_gone'); end if;
  if o.items is distinct from coalesce(public._trade_offer(p_theirs), '{}'::jsonb) then return public._fail('changed'); end if;
  if m.items = '{}'::jsonb and o.items = '{}'::jsonb then return public._fail('empty'); end if;
  update public.trade_sides set confirmed = true where trade_id = p_trade and user_id = u;
  if o.confirmed then
    update public.trade_sides x set receive = y.items from public.trade_sides y
    where x.trade_id = p_trade and y.trade_id = p_trade and x.user_id <> y.user_id;
    update public.trades set state = 'done', done_at = now() where id = p_trade;
    return jsonb_build_object('ok', true, 'done', true);
  end if;
  return jsonb_build_object('ok', true, 'done', false);
end $$;

-- Either side can end an open trade; both then take their own items back with trade_collect.
create or replace function public.trade_cancel(p_trade bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  if not exists (select 1 from public.trade_sides x join public.trades t on t.id = x.trade_id
      where x.trade_id = p_trade and x.user_id = u and t.state = 'open') then
    return public._fail('no_such_trade');
  end if;
  update public.trade_sides set receive = items where trade_id = p_trade;
  update public.trades set state = 'cancelled' where id = p_trade;
  return jsonb_build_object('ok', true);
end $$;

-- Puts what the caller gets from a finished or ended trade into the bag of the stored save.
create or replace function public.trade_collect(p_trade bigint, p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  m public.trade_sides;
  r jsonb;
begin
  perform public._trade_tidy();
  select x.* into m from public.trade_sides x join public.trades t on t.id = x.trade_id
  where x.trade_id = p_trade and x.user_id = u and t.state <> 'open' for update of x;
  if not found then return public._fail('no_such_trade'); end if;
  if m.collected then return public._fail('already'); end if;
  r := public._trade_bag(u, p_slot, p_rev, coalesce(m.receive, '{}'::jsonb));
  if not (r->>'ok')::boolean then return r; end if;
  update public.trade_sides set collected = true where trade_id = p_trade and user_id = u;
  perform public._trade_tidy();
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'bag', coalesce(m.receive, '{}'::jsonb));
end $$;

revoke all on function public._friend_accepted(), public._trade_check(uuid), public._trade_pair(uuid, uuid),
  public._trade_offer(jsonb), public._trade_bag(uuid, int, int, jsonb), public._trade_tidy()
  from public, anon, authenticated, chimora_referee;
revoke all on function public.trade_open(text), public.trade_list(), public.trade_put(bigint, int, int, jsonb),
  public.trade_confirm(bigint, jsonb), public.trade_cancel(bigint), public.trade_collect(bigint, int, int)
  from public, anon, chimora_referee;
grant execute on function public.trade_open(text), public.trade_list(), public.trade_put(bigint, int, int, jsonb),
  public.trade_confirm(bigint, jsonb), public.trade_cancel(bigint), public.trade_collect(bigint, int, int)
  to authenticated;
