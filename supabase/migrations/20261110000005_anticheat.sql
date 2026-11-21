-- Plan area 7, items 2921-2925: save_put compares every new save with the one before it.
-- Money may not grow faster than max_money_per_min per minute played, play time may only grow by
-- the real time since the last save plus save_time_slack seconds, and every Spirling kind, move
-- and item must exist in the game data (known_ids, filled at every deploy by
-- tools/online/game_data_sql.py). Values the server keeps itself are dropped from the save. A
-- refused save is noted in cheat_flags; cheat_flag_limit notes in cheat_flag_days take the
-- account out of leagues (and later raids) until Ali clears it (profiles.cheat_cleared_at).

insert into public.server_config (key, value) values
  ('max_money_per_min', '5000'),
  ('save_time_slack', '300'),
  ('start_money', '3000'),
  ('cheat_flag_limit', '3'),
  ('cheat_flag_days', '7'),
  ('save_server_keys', '["league", "leagues", "raid", "raids", "trades", "bund", "premium", "gems", "shards"]')
on conflict (key) do nothing;

create table if not exists public.known_ids (
  kind text not null check (kind in ('species', 'move', 'item')),
  id text not null,
  primary key (kind, id)
);

create table if not exists public.cheat_flags (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  slot int,
  reason text not null,
  detail jsonb not null default '{}'::jsonb,
  at timestamptz not null default now()
);
create index if not exists cheat_flags_user_at on public.cheat_flags (user_id, at);

alter table public.profiles add column if not exists cheat_cleared_at timestamptz;

alter table public.known_ids enable row level security;
alter table public.cheat_flags enable row level security;
revoke all on public.known_ids, public.cheat_flags from public, anon, authenticated;

-- Every id of [kind] in [ids] is known; true while known_ids has nothing of that kind yet (a fresh
-- server before the first data load), so honest players are never locked out by a missing load.
create or replace function public._ids_known(p_kind text, p_ids text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (select 1 from public.known_ids where kind = p_kind)
    or not exists (select 1 from unnest(p_ids) x(id)
      where x.id is not null and x.id <> '' and not exists (
        select 1 from public.known_ids k where k.kind = p_kind and k.id = x.id))
$$;

-- The reason a new save is refused, or null. [p_old] is the stored save of that slot (or null),
-- saved at [p_old_at].
create or replace function public._save_cheat(p_old jsonb, p_old_at timestamptz, p_new jsonb) returns text
language plpgsql stable security definer set search_path = public as $$
declare
  old_pt float8 := 0;
  new_pt float8 := coalesce((p_new->>'play_time')::float8, 0);
  old_money float8 := public._config_int('start_money', 3000);
  new_money float8 := coalesce((p_new->>'money')::float8, 0);
  played_min float8;
  mons jsonb := '[]'::jsonb;
  k text;
begin
  if p_old is not null and jsonb_typeof(p_old->'play_time') = 'number' then
    old_pt := (p_old->>'play_time')::float8;
    if new_pt >= old_pt then
      -- The same journey goes on: time grows with the clock, money with the time played.
      old_money := greatest(coalesce((p_old->>'money')::float8, 0), 0);
      if new_pt - old_pt > extract(epoch from now() - p_old_at) + public._config_int('save_time_slack', 300) then
        return 'play_time_fast';
      end if;
    else
      -- Less play time than before means a new journey in this slot: money counts from the start.
      old_pt := 0;
    end if;
  end if;
  played_min := greatest(ceil((new_pt - old_pt) / 60.0), 1);
  if new_money - old_money > public._config_int('max_money_per_min', 5000) * played_min then
    return 'money_fast';
  end if;
  foreach k in array array['party', 'storage', 'sanctuary'] loop
    if jsonb_typeof(p_new->k) = 'array' then mons := mons || (p_new->k); end if;
  end loop;
  if not public._ids_known('species', array(select m->>'species' from jsonb_array_elements(mons) m
      where jsonb_typeof(m) = 'object')) then
    return 'unknown_species';
  end if;
  if not public._ids_known('move', array(select mv #>> '{}' from jsonb_array_elements(mons) m,
      jsonb_array_elements(case when jsonb_typeof(m->'moves') = 'array' then m->'moves' else '[]'::jsonb end) mv
      where jsonb_typeof(m) = 'object')) then
    return 'unknown_move';
  end if;
  if not public._ids_known('item', array(
      select m->>'held' from jsonb_array_elements(mons) m where jsonb_typeof(m) = 'object'
      union all
      select key from jsonb_each(case when jsonb_typeof(p_new->'inventory') = 'object' then p_new->'inventory' else '{}'::jsonb end))) then
    return 'unknown_item';
  end if;
  return null;
end $$;

-- The account is out of leagues and raids while it has cheat_flag_limit notes in cheat_flag_days
-- since Ali last cleared it.
create or replace function public._cheat_held(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select count(*) >= public._config_int('cheat_flag_limit', 3)
  from public.cheat_flags f
  where f.user_id = p_user
    and f.at > greatest(now() - make_interval(days => public._config_int('cheat_flag_days', 7)),
      coalesce((select cheat_cleared_at from public.profiles where id = p_user), '-infinity'::timestamptz))
$$;

-- Drops what the server keeps itself (item 2924), even when a client sends it.
create or replace function public._save_strip(p_data jsonb) returns jsonb
language plpgsql stable as $$
declare
  keys jsonb := coalesce(public._config('save_server_keys', '[]'), '[]'::jsonb);
  k text;
  out jsonb := p_data;
begin
  if jsonb_typeof(keys) <> 'array' then return out; end if;
  for k in select * from jsonb_array_elements_text(keys) loop
    out := out - k;
  end loop;
  return out;
end $$;

create or replace function public.save_put(p_slot int, p_data jsonb, p_summary text, p_base_rev int, p_force boolean default false) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  cur public.saves;
  new_rev int;
  why text;
  data jsonb;
begin
  if p_slot not between 1 and 3 then
    return jsonb_build_object('ok', false, 'error', 'bad_slot');
  end if;
  if not public._save_schema_ok(p_data) then
    return jsonb_build_object('ok', false, 'error', 'schema');
  end if;
  if not public._save_ok(p_data) then
    return jsonb_build_object('ok', false, 'error', 'implausible');
  end if;
  data := public._save_strip(p_data);
  select * into cur from public.saves where user_id = u and slot = p_slot for update;
  if found and cur.rev <> p_base_rev and not p_force then
    return jsonb_build_object('ok', false, 'conflict', true, 'rev', cur.rev,
      'saved_at', extract(epoch from cur.saved_at)::bigint, 'summary', cur.summary);
  end if;
  why := public._save_cheat(cur.data, cur.saved_at, data);
  if why is not null then
    -- The game tries again at the next save; the same refusal counts once per 10 minutes.
    if not exists (select 1 from public.cheat_flags f where f.user_id = u and f.slot = p_slot
        and f.reason = why and f.at > now() - interval '10 minutes') then
      insert into public.cheat_flags (user_id, slot, reason, detail)
      values (u, p_slot, why, jsonb_build_object('money', data->'money', 'play_time', data->'play_time',
        'old_money', cur.data->'money', 'old_play_time', cur.data->'play_time'));
    end if;
    return jsonb_build_object('ok', false, 'error', 'refused', 'reason', why);
  end if;
  new_rev := coalesce(cur.rev, 0) + 1;
  insert into public.saves (user_id, slot, rev, data, summary, saved_at)
  values (u, p_slot, new_rev, data, left(coalesce(p_summary, ''), 60), now())
  on conflict (user_id, slot) do update
    set rev = excluded.rev, data = excluded.data, summary = excluded.summary, saved_at = excluded.saved_at;
  return jsonb_build_object('ok', true, 'rev', new_rev, 'saved_at', extract(epoch from now())::bigint);
end $$;

-- Leagues refuse accounts under review (2925). The league RPCs all ask _league_ok first.
create or replace function public._league_ok(p_league text) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if p_league is null or p_league not in ('fair', 'open') then return 'bad_league'; end if;
  if not public._flag_on('league_' || p_league, 2147483647) then return 'feature_off'; end if;
  if auth.uid() is not null and public._cheat_held(auth.uid()) then return 'under_review'; end if;
  return null;
end $$;

revoke all on function public._ids_known(text, text[]), public._save_cheat(jsonb, timestamptz, jsonb),
  public._cheat_held(uuid), public._save_strip(jsonb), public._league_ok(text) from public, anon, authenticated;
revoke all on function public.save_put(int, jsonb, text, int, boolean) from public, anon;
grant execute on function public.save_put(int, jsonb, text, int, boolean) to authenticated;
