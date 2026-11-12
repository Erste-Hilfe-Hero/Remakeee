-- Online 100, area 1: live duels between friends. Invite by friend code (or rematch), both see the
-- other's 6 and pick 3, then both send their choice for each round at the same time; the server keeps
-- the rounds, the 30 second clock and the 60 second reconnect window, forfeits and set emotes.
-- Values in server_config.live_duel (data/live_duel.json). LocalBackend does the same.

create table if not exists public.live_duels (
  id bigserial primary key,
  a uuid not null references auth.users (id) on delete cascade,
  b uuid not null references auth.users (id) on delete cascade,
  state text not null default 'invited' check (state in ('invited', 'picking', 'running', 'done', 'expired')),
  show jsonb not null,
  pick jsonb not null default '[null, null]'::jsonb,
  seed bigint not null,
  round int not null default 0,
  moves jsonb not null default '{}'::jsonb,
  deadline timestamptz not null,
  winner int not null default -1,
  reason text not null default '',
  emotes jsonb not null default '[]'::jsonb,
  report jsonb not null default '[null, null]'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists live_duels_a on public.live_duels (a, created_at desc);
create index if not exists live_duels_b on public.live_duels (b, created_at desc);
alter table public.live_duels enable row level security;
revoke all on public.live_duels from public, anon, authenticated;
revoke all on sequence public.live_duels_id_seq from public, anon, authenticated;

create or replace function public._live_cfg(p_key text) returns int
language sql stable as $$
  select coalesce((public._config('live_duel', '{}'::jsonb)->>p_key)::int,
    ('{"turn_seconds": 30, "reconnect_seconds": 60, "pick_seconds": 90, "invite_minutes": 10, "show": 6, "pick": 3,
      "emotes": 12, "emote_limit": 20, "invites_per_hour": 20}'::jsonb->>p_key)::int)
$$;

-- Invites run out; a side away longer than the turn plus the reconnect window loses.
create or replace function public._live_tick(p_id bigint) returns public.live_duels
language plpgsql volatile as $$
declare
  d public.live_duels;
  have jsonb;
  away0 boolean;
  away1 boolean;
begin
  select * into d from public.live_duels where id = p_id for update;
  if not found then return d; end if;
  if d.state = 'invited' and now() > d.deadline then
    update public.live_duels set state = 'expired' where id = p_id returning * into d;
  elsif d.state in ('picking', 'running') and now() > d.deadline + make_interval(secs => public._live_cfg('reconnect_seconds')) then
    have := case when d.state = 'picking' then d.pick else coalesce(d.moves->(d.round::text), '[null, null]'::jsonb) end;
    away0 := jsonb_typeof(have->0) = 'null';
    away1 := jsonb_typeof(have->1) = 'null';
    update public.live_duels set state = 'done', reason = 'timeout',
      winner = case when away0 = away1 then -1 when away0 then 1 else 0 end
    where id = p_id returning * into d;
  end if;
  return d;
end $$;

create or replace function public._live_side(d public.live_duels, u uuid) returns int
language sql immutable as $$
  select case when d.a = u then 0 when d.b = u then 1 else -1 end
$$;

create or replace function public._live_out(d public.live_duels, u uuid) returns jsonb
language plpgsql stable as $$
declare
  teams jsonb := '[]'::jsonb;
  side int;
  rows jsonb;
  i jsonb;
begin
  if d.state in ('running', 'done') and jsonb_typeof(d.pick->0) = 'array' and jsonb_typeof(d.pick->1) = 'array' then
    for side in 0 .. 1 loop
      rows := '[]'::jsonb;
      for i in select * from jsonb_array_elements(d.pick->side) loop
        rows := rows || jsonb_build_array(d.show->side->(i::int));
      end loop;
      teams := teams || jsonb_build_array(rows);
    end loop;
  end if;
  return jsonb_build_object('ok', true, 'id', d.id, 'side', public._live_side(d, u), 'state', d.state, 'show', d.show,
    'picked', jsonb_build_array(jsonb_typeof(d.pick->0) = 'array', jsonb_typeof(d.pick->1) = 'array'),
    'teams', teams, 'seed', d.seed, 'round', d.round, 'moves', d.moves,
    'deadline', extract(epoch from d.deadline)::bigint, 'turn_seconds', public._live_cfg('turn_seconds'),
    'winner', d.winner, 'reason', d.reason, 'emotes', d.emotes);
end $$;

create or replace function public._live_new(u uuid, other uuid) returns jsonb
language plpgsql volatile as $$
declare
  ta jsonb;
  tb jsonb;
  n int := public._live_cfg('show');
  nid bigint;
begin
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb) into ta from (select x, o from jsonb_array_elements(
    (select team from public.profiles where id = u)) with ordinality t(x, o) where o <= n) s;
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb) into tb from (select x, o from jsonb_array_elements(
    (select team from public.profiles where id = other)) with ordinality t(x, o) where o <= n) s;
  if jsonb_array_length(ta) < public._live_cfg('pick') or jsonb_array_length(tb) < public._live_cfg('pick') then
    return public._fail('team_too_small');
  end if;
  insert into public.live_duels (a, b, show, seed, deadline)
  values (u, other, jsonb_build_array(ta, tb), floor(random() * 2147483647)::bigint,
    now() + make_interval(mins => public._live_cfg('invite_minutes')))
  returning live_duels.id into nid;
  return jsonb_build_object('ok', true, 'id', nid);
end $$;

create or replace function public.live_invite(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  other uuid := public._by_code(p_code);
begin
  if not public._flag_on('live_duel', 2147483647) then return public._fail('feature_off'); end if;
  perform public._ensure_profile(u);
  if other is null or other = u or public._blocked(u, other) or not public._friends(u, other) then
    return public._fail('not_friends');
  end if;
  if not public._rate_ok(u, 'live_invite', public._live_cfg('invites_per_hour')) then return public._fail('slow_down'); end if;
  return public._live_new(u, other);
end $$;

create or replace function public.live_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  r record;
  d public.live_duels;
  out_rows jsonb := '[]'::jsonb;
begin
  for r in select id from public.live_duels where (a = u or b = u) and state not in ('done', 'expired') order by id loop
    d := public._live_tick(r.id);
    if d.state not in ('done', 'expired') then
      out_rows := out_rows || jsonb_build_object('id', d.id, 'state', d.state, 'side', public._live_side(d, u),
        'name', (select name from public.profiles where id = case when d.a = u then d.b else d.a end));
    end if;
  end loop;
  return jsonb_build_object('ok', true, 'duels', out_rows);
end $$;

create or replace function public._live_mine(p_id bigint, u uuid) returns public.live_duels
language plpgsql volatile as $$
declare d public.live_duels;
begin
  d := public._live_tick(p_id);
  if d.id is null or public._live_side(d, u) < 0 then return null; end if;
  return d;
end $$;

create or replace function public.live_answer(p_id bigint, p_accept boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
begin
  if d.id is null or public._live_side(d, u) <> 1 then return public._fail('no_such_duel'); end if;
  if d.state <> 'invited' then return public._fail('duel_closed'); end if;
  if not coalesce(p_accept, false) then
    update public.live_duels set state = 'expired' where id = d.id;
    return jsonb_build_object('ok', true, 'state', 'expired');
  end if;
  update public.live_duels set state = 'picking', deadline = now() + make_interval(secs => public._live_cfg('pick_seconds'))
  where id = d.id returning * into d;
  return public._live_out(d, u);
end $$;

create or replace function public.live_pick(p_id bigint, p_pick jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
  side int;
  shown int;
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  side := public._live_side(d, u);
  if d.state <> 'picking' or jsonb_typeof(d.pick->side) <> 'null' then return public._fail('duel_closed'); end if;
  shown := jsonb_array_length(d.show->side);
  if jsonb_typeof(p_pick) is distinct from 'array' or jsonb_array_length(p_pick) <> public._live_cfg('pick')
     or exists (select 1 from jsonb_array_elements(p_pick) x where jsonb_typeof(x) <> 'number'
       or (x::text)::numeric <> floor((x::text)::numeric) or (x::text)::numeric < 0 or (x::text)::numeric >= shown)
     or (select count(distinct (x::text)::numeric) from jsonb_array_elements(p_pick) x) <> jsonb_array_length(p_pick) then
    return public._fail('bad_pick');
  end if;
  update public.live_duels set pick = jsonb_set(pick, array[side::text],
    (select jsonb_agg(((x::text)::numeric)::int) from jsonb_array_elements(p_pick) x))
  where id = d.id returning * into d;
  if jsonb_typeof(d.pick->0) = 'array' and jsonb_typeof(d.pick->1) = 'array' then
    update public.live_duels set state = 'running', round = 1,
      deadline = now() + make_interval(secs => public._live_cfg('turn_seconds'))
    where id = d.id returning * into d;
  end if;
  return public._live_out(d, u);
end $$;

create or replace function public.live_move(p_id bigint, p_round int, p_input jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
  side int;
  row_ jsonb;
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  side := public._live_side(d, u);
  if d.state <> 'running' then return public._fail('duel_closed'); end if;
  if p_round is distinct from d.round then return public._fail('wrong_round'); end if;
  if jsonb_typeof(p_input) is distinct from 'object' or length(p_input::text) > 400 then return public._fail('bad_input'); end if;
  row_ := coalesce(d.moves->(d.round::text), '[null, null]'::jsonb);
  if jsonb_typeof(row_->side) <> 'null' then return public._fail('already_moved'); end if;
  row_ := jsonb_set(row_, array[side::text], p_input);
  update public.live_duels set moves = moves || jsonb_build_object(d.round::text, row_) where id = d.id returning * into d;
  if jsonb_typeof(row_->0) <> 'null' and jsonb_typeof(row_->1) <> 'null' then
    update public.live_duels set round = round + 1, deadline = now() + make_interval(secs => public._live_cfg('turn_seconds'))
    where id = d.id returning * into d;
  end if;
  return public._live_out(d, u);
end $$;

create or replace function public.live_state(p_id bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  return public._live_out(d, u);
end $$;

create or replace function public.live_emote(p_id bigint, p_emote int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
  side int;
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  if p_emote is null or p_emote < 0 or p_emote >= public._live_cfg('emotes') then return public._fail('bad_emote'); end if;
  side := public._live_side(d, u);
  if (select count(*) from jsonb_array_elements(d.emotes) e where (e->>'side')::int = side) >= public._live_cfg('emote_limit') then
    return public._fail('slow_down');
  end if;
  update public.live_duels set emotes = emotes || jsonb_build_array(jsonb_build_object('side', side, 'emote', p_emote,
    'at', extract(epoch from now())::bigint)) where id = d.id;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.live_forfeit(p_id bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  if d.state not in ('picking', 'running') then return public._fail('duel_closed'); end if;
  update public.live_duels set state = 'done', reason = 'forfeit', winner = 1 - public._live_side(d, u)
  where id = d.id returning * into d;
  return public._live_out(d, u);
end $$;

-- Both report the winner they saw; the same answer counts, two different ones void the duel.
create or replace function public.live_finish(p_id bigint, p_winner int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  if d.state <> 'running' or p_winner is null or p_winner < -1 or p_winner > 1 then return public._fail('duel_closed'); end if;
  update public.live_duels set report = jsonb_set(report, array[public._live_side(d, u)::text], to_jsonb(p_winner))
  where id = d.id returning * into d;
  if jsonb_typeof(d.report->0) <> 'null' and jsonb_typeof(d.report->1) <> 'null' then
    update public.live_duels set state = 'done',
      reason = case when d.report->0 = d.report->1 then 'played' else 'disputed' end,
      winner = case when d.report->0 = d.report->1 then (d.report->>0)::int else -1 end
    where id = d.id returning * into d;
  end if;
  return public._live_out(d, u);
end $$;

create or replace function public.live_rematch(p_id bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
  other uuid;
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  if d.state <> 'done' then return public._fail('duel_closed'); end if;
  other := case when d.a = u then d.b else d.a end;
  if public._blocked(u, other) or not public._friends(u, other) then return public._fail('not_friends'); end if;
  if not public._rate_ok(u, 'live_invite', public._live_cfg('invites_per_hour')) then return public._fail('slow_down'); end if;
  return public._live_new(u, other);
end $$;

revoke all on function public._live_cfg(text), public._live_tick(bigint), public._live_side(public.live_duels, uuid),
  public._live_out(public.live_duels, uuid), public._live_new(uuid, uuid), public._live_mine(bigint, uuid)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.live_invite(text), public.live_list(), public.live_answer(bigint, boolean),
  public.live_pick(bigint, jsonb), public.live_move(bigint, int, jsonb), public.live_state(bigint),
  public.live_emote(bigint, int), public.live_forfeit(bigint), public.live_finish(bigint, int), public.live_rematch(bigint)
  from public, anon, chimora_referee;
grant execute on function public.live_invite(text), public.live_list(), public.live_answer(bigint, boolean),
  public.live_pick(bigint, jsonb), public.live_move(bigint, int, jsonb), public.live_state(bigint),
  public.live_emote(bigint, int), public.live_forfeit(bigint), public.live_finish(bigint, int), public.live_rematch(bigint)
  to authenticated;
