-- Online step 1 (2026-11): Spirling trading between friends, weekly boards for Rift times and
-- league wins, and a daily online gift. Each part waits behind its own feature flag
-- (trade_spirling, rift_board, league_board, daily_gift), all off until Ali switches them on.
--
-- Spirling trading builds on the item trades (20261110000012_trades.sql): the server stays the
-- trustee. A Spirling put into a trade leaves the stored save at once and waits in trade_sides.mons;
-- once both confirmed (naming the other side's Spirlings by uid), each side collects the other's
-- Spirlings into its storage. A traded Spirling keeps its origin era ("origin_era", 1-4) and every
-- other value; the server only drops the nickname (no free text between players), the storage box
-- and the favourite mark. Spirlings that hold an item or carry a shop boost (Gleam, Power Core,
-- crystals) cannot be traded, so nothing bought ever changes hands. The team always keeps one Spirling.
--
-- Rift times: after a Warden battle the game uploads the battle (battle_submit, kind 'rift', ref =
-- the Rift id). Rounds count on the board only once the referee replayed the battle as "ok".
-- League board: league battles won this week, only rated wins the referee confirmed.
-- Daily gift: one free item per server day, rolled by the server from the open table
-- daily_gift_table and put straight into the stored save. Nothing is sold here.
-- Re-runnable.

insert into public.server_config (key, value) values
  ('trade_max_spirlings', '3'),
  ('board_rows', '20'),
  ('daily_gift_table', '[{"item": "tonic", "w": 30}, {"item": "remedy", "w": 20}, {"item": "strong_tonic", "w": 15}, {"item": "spark_drop", "w": 10}, {"item": "cooling_gel", "w": 5}, {"item": "dry_towel", "w": 5}, {"item": "wake_bell", "w": 5}, {"item": "power_brew", "w": 2}, {"item": "guard_brew", "w": 2}, {"item": "focus_brew", "w": 2}, {"item": "dash_brew", "w": 2}, {"item": "revival_leaf", "w": 2}]')
on conflict (key) do nothing;

insert into public.feature_flags (key, enabled, min_version, note) values
  ('trade_spirling', false, 1, 'Spirlings unter Freunden tauschen'),
  ('rift_board', false, 1, 'Wochenbestenliste Riss-Zeiten'),
  ('league_board', false, 1, 'Wochenbestenliste Liga'),
  ('daily_gift', false, 1, 'Tägliches Online-Geschenk')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------------------
-- Spirling trading

alter table public.trade_sides add column if not exists mons jsonb not null default '[]'::jsonb;
alter table public.trade_sides add column if not exists receive_mons jsonb;

-- Why Spirling [m] cannot be traded, or null.
create or replace function public._trade_mon_why(m jsonb) returns text
language sql immutable as $$
  select case
    when jsonb_typeof(m) <> 'object' or coalesce(m->>'uid', '') = '' or coalesce(m->>'species', '') = '' then 'no_spirling'
    when coalesce(m->>'held', '') <> '' then 'holds_item'
    when coalesce(m->>'gleam', 'false') = 'true' or coalesce(m->>'core', 'false') = 'true'
      or (jsonb_typeof(m->'crystal') = 'object' and m->'crystal' <> '{}'::jsonb) then 'shop_boosted'
    when coalesce(m->>'favorite', 'false') = 'true' then 'favorite'
  end
$$;

-- The Spirling as it travels: the same values, its origin era kept (1 when an older save has
-- none), no nickname, no box, no favourite mark.
create or replace function public._trade_mon_clean(m jsonb) returns jsonb
language sql immutable as $$
  select (m - 'nickname' - 'box' - 'favorite') || jsonb_build_object('origin_era',
    case when coalesce(m->>'origin_era', '') ~ '^[1-4]$' then (m->>'origin_era')::int else 1 end)
$$;

-- Sorted uids of a list of Spirlings.
create or replace function public._trade_uids(p jsonb) returns text[]
language sql immutable as $$
  select coalesce(array_agg(x->>'uid' order by x->>'uid'), '{}'::text[])
  from jsonb_array_elements(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) x
$$;

-- Changes the stored save of [u] in [p_slot]: the bag by [p_delta] ({item: +n/-n}), takes the
-- Spirlings with the uids [p_take] out of team or storage and adds [p_give] to storage. The device
-- must know the stored revision. Returns {ok, rev, took: [Spirlings]} or a failure; on a failure
-- nothing changed.
create or replace function public._trade_save(u uuid, p_slot int, p_rev int, p_delta jsonb, p_take text[], p_give jsonb)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  s public.saves;
  inv jsonb;
  party jsonb;
  store jsonb;
  took jsonb := '[]'::jsonb;
  k text;
  v jsonb;
  n int;
  id text;
  hit jsonb;
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
  party := case when jsonb_typeof(s.data->'party') = 'array' then s.data->'party' else '[]'::jsonb end;
  store := case when jsonb_typeof(s.data->'storage') = 'array' then s.data->'storage' else '[]'::jsonb end;
  foreach id in array coalesce(p_take, '{}'::text[]) loop
    select x into hit from jsonb_array_elements(party) x where x->>'uid' = id limit 1;
    if hit is not null then
      party := coalesce((select jsonb_agg(x) from jsonb_array_elements(party) x where x->>'uid' is distinct from id), '[]'::jsonb);
    else
      select x into hit from jsonb_array_elements(store) x where x->>'uid' = id limit 1;
      if hit is null then return public._fail('no_spirling'); end if;
      store := coalesce((select jsonb_agg(x) from jsonb_array_elements(store) x where x->>'uid' is distinct from id), '[]'::jsonb);
    end if;
    took := took || jsonb_build_array(hit);
    hit := null;
  end loop;
  if jsonb_array_length(party) = 0 and cardinality(coalesce(p_take, '{}'::text[])) > 0 then
    return public._fail('last_one');
  end if;
  if jsonb_typeof(p_give) = 'array' and jsonb_array_length(p_give) > 0 then
    store := store || p_give;
  end if;
  update public.saves set data = data || jsonb_build_object('inventory', inv)
      || case when cardinality(coalesce(p_take, '{}'::text[])) > 0 or jsonb_array_length(coalesce(p_give, '[]'::jsonb)) > 0
         then jsonb_build_object('party', party, 'storage', store) else '{}'::jsonb end,
    rev = s.rev + 1, saved_at = now(), request_id = null
  where user_id = u and slot = p_slot;
  return jsonb_build_object('ok', true, 'rev', s.rev + 1, 'took', took);
end $$;

-- The item trade's bag change, now through _trade_save.
create or replace function public._trade_bag(u uuid, p_slot int, p_rev int, p_delta jsonb) returns jsonb
language sql volatile security definer set search_path = public as $$
  select public._trade_save(u, p_slot, p_rev, p_delta, '{}'::text[], '[]'::jsonb) - 'took'
$$;

create or replace function public._trade_tidy() returns void
language sql volatile security definer set search_path = public as $$
  update public.trade_sides d set receive = d.items, receive_mons = d.mons
  from public.trades t where t.id = d.trade_id and t.state = 'open' and t.closes_at < now();
  update public.trades set state = 'cancelled' where state = 'open' and closes_at < now();
  delete from public.trades t where t.state <> 'open'
    and (not exists (select 1 from public.trade_sides d where d.trade_id = t.id and not d.collected)
      or t.created_at < now() - interval '90 days');
$$;

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
        'mine_mons', m.mons, 'theirs_mons', coalesce(o.mons, '[]'::jsonb),
        'my_ok', m.confirmed, 'their_ok', coalesce(o.confirmed, false),
        'collect', t.state <> 'open' and not m.collected) order by t.id desc)
    from public.trade_sides m
    join public.trades t on t.id = m.trade_id
    left join public.trade_sides o on o.trade_id = m.trade_id and o.user_id <> m.user_id
    left join public.profiles p on p.id = o.user_id
    where m.user_id = u and (t.state = 'open' or not m.collected)), '[]'::jsonb),
    'items', public._config('trade_items', '[]'),
    'spirlings', public._flag_on('trade_spirling', 2147483647),
    'max_spirlings', public._config_int('trade_max_spirlings', 3));
end $$;

-- Sets the caller's Spirling offer to exactly the uids [p_uids]. New ones leave the stored save
-- in [p_slot] ("took"), dropped ones go back to its storage ("back"). Both confirmations reset.
create or replace function public.trade_put_spirlings(p_trade bigint, p_slot int, p_rev int, p_uids text[]) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  why text := public._trade_check(u);
  m public.trade_sides;
  other uuid;
  want text[];
  have text[];
  take text[];
  back jsonb;
  s public.saves;
  id text;
  hit jsonb;
  r jsonb;
begin
  if why is not null then return public._fail(why); end if;
  if not public._flag_on('trade_spirling', 2147483647) then return public._fail('feature_off'); end if;
  perform public._trade_tidy();
  select x.* into m from public.trade_sides x join public.trades t on t.id = x.trade_id
  where x.trade_id = p_trade and x.user_id = u and t.state = 'open' for update of x;
  if not found then return public._fail('no_such_trade'); end if;
  select user_id into other from public.trade_sides where trade_id = p_trade and user_id <> u;
  why := public._trade_pair(u, other);
  if why is not null then return public._fail('partner_gone'); end if;
  select coalesce(array_agg(distinct x), '{}'::text[]) into want from unnest(coalesce(p_uids, '{}'::text[])) x
  where x is not null and x <> '';
  if cardinality(want) <> cardinality(array_remove(coalesce(p_uids, '{}'::text[]), null))
     or cardinality(want) > public._config_int('trade_max_spirlings', 3) then
    return public._fail('too_many_spirlings');
  end if;
  if not public._rate_ok(u, 'trade_put', 60) then return public._fail('slow_down'); end if;
  have := public._trade_uids(m.mons);
  take := array(select x from unnest(want) x where not x = any (have));
  back := coalesce((select jsonb_agg(x) from jsonb_array_elements(m.mons) x where not (x->>'uid') = any (want)), '[]'::jsonb);
  -- Every new Spirling must be tradeable before anything changes.
  select * into s from public.saves where user_id = u and slot = p_slot;
  if not found then return public._fail('no_save'); end if;
  foreach id in array take loop
    select x into hit from jsonb_array_elements(
      case when jsonb_typeof(s.data->'party') = 'array' then s.data->'party' else '[]'::jsonb end
      || case when jsonb_typeof(s.data->'storage') = 'array' then s.data->'storage' else '[]'::jsonb end) x
    where x->>'uid' = id limit 1;
    why := public._trade_mon_why(hit);
    if why is not null then return public._fail(why); end if;
    hit := null;
  end loop;
  r := public._trade_save(u, p_slot, p_rev, '{}'::jsonb, take, back);
  if not (r->>'ok')::boolean then return r; end if;
  update public.trade_sides set mons = coalesce((select jsonb_agg(x) from jsonb_array_elements(m.mons) x
      where (x->>'uid') = any (want)), '[]'::jsonb)
    || coalesce((select jsonb_agg(public._trade_mon_clean(x)) from jsonb_array_elements(r->'took') x), '[]'::jsonb)
  where trade_id = p_trade and user_id = u;
  update public.trade_sides set confirmed = false where trade_id = p_trade;
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'took', to_jsonb(take), 'back', back);
end $$;

-- Confirms the trade as the caller sees it: [p_theirs] must be the other side's items and
-- [p_their_mons] the uids of the other side's Spirlings right now.
create or replace function public.trade_confirm(p_trade bigint, p_theirs jsonb, p_their_mons text[]) returns jsonb
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
  if o.items is distinct from coalesce(public._trade_offer(p_theirs), '{}'::jsonb)
     or public._trade_uids(o.mons) is distinct from
       coalesce((select array_agg(x order by x) from unnest(coalesce(p_their_mons, '{}'::text[])) x), '{}'::text[]) then
    return public._fail('changed');
  end if;
  if m.items = '{}'::jsonb and o.items = '{}'::jsonb and m.mons = '[]'::jsonb and o.mons = '[]'::jsonb then
    return public._fail('empty');
  end if;
  update public.trade_sides set confirmed = true where trade_id = p_trade and user_id = u;
  if o.confirmed then
    update public.trade_sides x set receive = y.items, receive_mons = y.mons from public.trade_sides y
    where x.trade_id = p_trade and y.trade_id = p_trade and x.user_id <> y.user_id;
    update public.trades set state = 'done', done_at = now() where id = p_trade;
    return jsonb_build_object('ok', true, 'done', true);
  end if;
  return jsonb_build_object('ok', true, 'done', false);
end $$;

-- Older builds confirm with the items only; that only matches while the other side offers no Spirling.
create or replace function public.trade_confirm(p_trade bigint, p_theirs jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._uid();
  return public.trade_confirm(p_trade, p_theirs, '{}'::text[]);
end $$;

create or replace function public.trade_cancel(p_trade bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  if not exists (select 1 from public.trade_sides x join public.trades t on t.id = x.trade_id
      where x.trade_id = p_trade and x.user_id = u and t.state = 'open') then
    return public._fail('no_such_trade');
  end if;
  update public.trade_sides set receive = items, receive_mons = mons where trade_id = p_trade;
  update public.trades set state = 'cancelled' where id = p_trade;
  return jsonb_build_object('ok', true);
end $$;

-- Puts what the caller gets (items into the bag, Spirlings into storage) into the stored save.
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
  r := public._trade_save(u, p_slot, p_rev, coalesce(m.receive, '{}'::jsonb), '{}'::text[], coalesce(m.receive_mons, '[]'::jsonb));
  if not (r->>'ok')::boolean then return r; end if;
  update public.trade_sides set collected = true where trade_id = p_trade and user_id = u;
  perform public._trade_tidy();
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'bag', coalesce(m.receive, '{}'::jsonb),
    'mons', coalesce(m.receive_mons, '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------------------
-- Weekly boards: Rift times and league wins

-- Rift ids come from the game data at every deploy (tools/online/game_data_sql.py).
alter table public.known_ids drop constraint if exists known_ids_kind_check;
alter table public.known_ids add constraint known_ids_kind_check check (kind in ('species', 'move', 'item', 'rift'));

alter table public.battles drop constraint if exists battles_kind_check;
alter table public.battles add constraint battles_kind_check
  check (kind in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel', 'rift'));

-- One row per uploaded Rift battle the player won; it counts once battles.status is 'ok'.
create table if not exists public.rift_runs (
  battle_id bigint primary key references public.battles (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  week text not null,
  rift text not null,
  rounds int not null check (rounds between 1 and 400),
  at timestamptz not null default now()
);
create index if not exists rift_runs_board on public.rift_runs (week, rift, rounds);
alter table public.rift_runs enable row level security;
revoke all on public.rift_runs from public, anon, authenticated, chimora_referee;

-- battle_submit with Rift battles (built on the raids version, 20261110000011_raids.sql).
create or replace function public.battle_submit(p_kind text, p_ref text, p_replay jsonb, p_claim jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  b bigint;
  m public.league_matches;
  a public.raid_attempts;
  claim jsonb;
  ref_id bigint := case when coalesce(p_ref, '') ~ '^[0-9]{1,18}$' then p_ref::bigint else -1 end;
  rounds int;
begin
  perform public._ensure_profile(u);
  if p_kind is null or p_kind not in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel', 'rift') then
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
  if p_kind = 'rift' then
    insert into public.rift_runs (battle_id, user_id, week, rift, rounds) values (b, u, public._week(), p_ref, rounds);
  end if;
  perform public._referee_check(b, p_replay, claim);
  return jsonb_build_object('ok', true, 'battle_id', b, 'status', 'pending');
end $$;

-- Rows of a weekly board from (user_id, value, at), best first: names only for you and your
-- friends, strangers stay nameless. [p_low] = a lower value is better.
create or replace function public._board_json(u uuid, p_rows jsonb, p_low boolean) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('rank', r.rank, 'score', r.v, 'me', r.uid = u,
      'name', case when r.uid = u or public._friends(u, r.uid) then p.name else '' end) order by r.rank), '[]'::jsonb)
  from (select (x->>'u')::uuid as uid, (x->>'v')::int as v,
          rank() over (order by case when p_low then (x->>'v')::int else -(x->>'v')::int end, (x->>'at')::float8) as rank
        from jsonb_array_elements(p_rows) x) r
  join public.profiles p on p.id = r.uid
  where r.rank <= public._config_int('board_rows', 20) or r.uid = u
$$;

-- Fewest rounds per player for Rift [p_rift] this week; friends only or everyone.
create or replace function public.rift_board(p_rift text, p_friends boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  w text := public._week();
begin
  if not public._flag_on('rift_board', 2147483647) then return public._fail('feature_off'); end if;
  delete from public.rift_runs where at < now() - interval '35 days';
  return jsonb_build_object('ok', true, 'week', w, 'rift', p_rift, 'rows', public._board_json(u, coalesce((
    select jsonb_agg(jsonb_build_object('u', x.user_id, 'v', x.rounds, 'at', extract(epoch from x.at)))
    from (select distinct on (r.user_id) r.user_id, r.rounds, r.at
          from public.rift_runs r join public.battles b on b.id = r.battle_id and b.status = 'ok'
          where r.week = w and r.rift = p_rift
            and (not coalesce(p_friends, true) or r.user_id = u or public._friends(u, r.user_id))
            and not public._blocked(u, r.user_id)
          order by r.user_id, r.rounds, r.at) x), '[]'::jsonb), true));
end $$;

-- Rated league wins this week (confirmed by the referee) in [p_league].
create or replace function public.league_board(p_league text, p_friends boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  since timestamptz := date_trunc('week', now() at time zone 'utc') at time zone 'utc';
begin
  if not public._flag_on('league_board', 2147483647) then return public._fail('feature_off'); end if;
  if p_league is null or p_league not in ('fair', 'open') then return public._fail('bad_league'); end if;
  return jsonb_build_object('ok', true, 'week', public._week(), 'league', p_league, 'rows', public._board_json(u, coalesce((
    select jsonb_agg(jsonb_build_object('u', x.user_id, 'v', x.wins, 'at', x.last))
    from (select m.user_id, count(*)::int as wins, extract(epoch from max(m.created_at)) as last
          from public.league_matches m
          where m.league = p_league and m.state = 'done' and m.rated and m.score = 1 and m.created_at >= since
            and (not coalesce(p_friends, true) or m.user_id = u or public._friends(u, m.user_id))
            and not public._blocked(u, m.user_id)
          group by m.user_id) x), '[]'::jsonb), false));
end $$;

-- ---------------------------------------------------------------------------------------
-- Daily online gift

create table if not exists public.daily_gifts (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  item text not null,
  primary key (user_id, day)
);
alter table public.daily_gifts enable row level security;
revoke all on public.daily_gifts from public, anon, authenticated, chimora_referee;

-- Whether today's gift is still waiting, and the open table with its chances.
create or replace function public.daily_gift_state() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  if not public._flag_on('daily_gift', 2147483647) then return public._fail('feature_off'); end if;
  return jsonb_build_object('ok', true,
    'ready', not exists (select 1 from public.daily_gifts where user_id = u and day = public._today()),
    'table', public._config('daily_gift_table', '[]'));
end $$;

-- Takes today's gift: the server rolls the item and puts it into the bag of the stored save in
-- [p_slot] (the device sends the revision it knows, like a trade).
create or replace function public.daily_gift_claim(p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  tbl jsonb := public._config('daily_gift_table', '[{"item":"tonic","w":1}]');
  total int;
  roll int;
  acc int := 0;
  e jsonb;
  pick text := 'tonic';
  r jsonb;
begin
  if not public._flag_on('daily_gift', 2147483647) then return public._fail('feature_off'); end if;
  perform public._ensure_profile(u);
  delete from public.daily_gifts where day < public._today() - 7;
  if exists (select 1 from public.daily_gifts where user_id = u and day = public._today()) then
    return public._fail('already_today');
  end if;
  select sum((x->>'w')::int) into total from jsonb_array_elements(tbl) x;
  roll := floor(random() * greatest(total, 1))::int;
  for e in select * from jsonb_array_elements(tbl) loop
    acc := acc + (e->>'w')::int;
    if roll < acc then pick := e->>'item'; exit; end if;
  end loop;
  r := public._trade_save(u, p_slot, p_rev, jsonb_build_object(pick, 1), '{}'::text[], '[]'::jsonb);
  if not (r->>'ok')::boolean then return r; end if;
  insert into public.daily_gifts (user_id, day, item) values (u, public._today(), pick);
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'item', pick, 'bag', jsonb_build_object(pick, 1));
end $$;

-- ---------------------------------------------------------------------------------------

revoke all on function public._trade_mon_why(jsonb), public._trade_mon_clean(jsonb), public._trade_uids(jsonb),
  public._trade_save(uuid, int, int, jsonb, text[], jsonb), public._trade_bag(uuid, int, int, jsonb), public._trade_tidy(),
  public._board_json(uuid, jsonb, boolean)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.trade_list(), public.trade_put_spirlings(bigint, int, int, text[]),
  public.trade_confirm(bigint, jsonb, text[]), public.trade_confirm(bigint, jsonb), public.trade_cancel(bigint),
  public.trade_collect(bigint, int, int), public.battle_submit(text, text, jsonb, jsonb),
  public.rift_board(text, boolean), public.league_board(text, boolean),
  public.daily_gift_state(), public.daily_gift_claim(int, int)
  from public, anon, chimora_referee;
grant execute on function public.trade_list(), public.trade_put_spirlings(bigint, int, int, text[]),
  public.trade_confirm(bigint, jsonb, text[]), public.trade_confirm(bigint, jsonb), public.trade_cancel(bigint),
  public.trade_collect(bigint, int, int), public.battle_submit(text, text, jsonb, jsonb),
  public.rift_board(text, boolean), public.league_board(text, boolean),
  public.daily_gift_state(), public.daily_gift_claim(int, int)
  to authenticated;
