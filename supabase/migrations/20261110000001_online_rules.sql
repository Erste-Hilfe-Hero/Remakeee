-- Chimora online rules catch-up (plan area 7, items 2669-2674).
-- * Saves and echo teams follow the real game rules: at most 5 Spirlings in the team, Ring 1-60.
--   Both limits live in server_config (party_max, level_max), so a later bought sixth slot
--   (area 10) only needs a config change plus an entitlement check.
-- * Echo duels use server_config.duel_ring (start 50) instead of the fixed Ring 30 in the app.
-- * Players are "Wanderer" now, not "Tamer": default names, fallback names and stored names.
-- * Every online save carries a whole number "schema" (start 1); save_put refuses saves
--   without it or newer than server_config.save_schema_max.
-- * feature_flags: leagues, trading, bunds, raids and live duels can be switched on one by one.
-- Re-runnable like the earlier migrations.

insert into public.server_config (key, value) values
  ('party_max', '5'),
  ('level_max', '60'),
  ('duel_ring', '50'),
  ('save_schema_max', '1')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------------------
-- Feature flags (item 2674). Off until Ali (or a later migration) switches them on.

create table if not exists public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  -- Lowest client version (Online.CLIENT_VERSION) that may use the feature.
  min_version int not null default 1,
  note text not null default ''
);
alter table public.feature_flags enable row level security;
revoke all on public.feature_flags from public, anon, authenticated;

insert into public.feature_flags (key, enabled, min_version, note) values
  ('league_fair', false, 1, 'Gleichstand-Liga'),
  ('league_open', false, 1, 'Offene Liga'),
  ('live_duel', false, 1, 'Live-Duelle unter Freunden'),
  ('trade', false, 1, 'Tausch unter Freunden'),
  ('bund', false, 1, 'Bünde'),
  ('raid', false, 1, 'Raid-Risse')
on conflict (key) do nothing;

-- True when the feature is on for this client version.
create or replace function public._flag_on(p_key text, p_version int) returns boolean
language sql stable as $$
  select coalesce((select enabled and coalesce(p_version, 0) >= min_version
    from public.feature_flags where key = p_key), false)
$$;

-- Whole-number config value with a fallback.
create or replace function public._config_int(p_key text, p_default int) returns int
language plpgsql stable as $$
begin
  return coalesce((public._config(p_key, to_jsonb(p_default)) #>> '{}')::int, p_default);
exception when others then
  return p_default;
end $$;

-- ---------------------------------------------------------------------------------------
-- Real game limits for saves (item 2669).

create or replace function public._save_ok(d jsonb) returns boolean
language plpgsql stable as $$
declare
  s jsonb;
  party_max int := public._config_int('party_max', 5);
  level_max int := public._config_int('level_max', 60);
begin
  if jsonb_typeof(d) <> 'object' then return false; end if;
  if pg_column_size(d) > 400000 then return false; end if;
  if jsonb_typeof(coalesce(d->'party', '[]'::jsonb)) <> 'array' then return false; end if;
  if jsonb_typeof(coalesce(d->'storage', '[]'::jsonb)) <> 'array' then return false; end if;
  if jsonb_array_length(coalesce(d->'party', '[]'::jsonb)) > party_max then return false; end if;
  if coalesce((d->>'money')::numeric, 0) not between 0 and 9999999 then return false; end if;
  for s in select * from jsonb_array_elements(coalesce(d->'party', '[]'::jsonb) || coalesce(d->'storage', '[]'::jsonb)) loop
    if coalesce((s->>'level')::numeric, 1) not between 1 and level_max then return false; end if;
  end loop;
  return true;
exception when others then
  return false;
end $$;

-- The online save format number (item 2673): present, whole, 1..save_schema_max.
create or replace function public._save_schema_ok(d jsonb) returns boolean
language plpgsql stable as $$
declare v numeric;
begin
  if jsonb_typeof(d->'schema') is distinct from 'number' then return false; end if;
  v := (d->>'schema')::numeric;
  return coalesce(v = trunc(v) and v between 1 and public._config_int('save_schema_max', 1), false);
exception when others then
  return false;
end $$;

create or replace function public.save_put(p_slot int, p_data jsonb, p_summary text, p_base_rev int, p_force boolean default false) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  cur public.saves;
  new_rev int;
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
  select * into cur from public.saves where user_id = u and slot = p_slot for update;
  if found and cur.rev <> p_base_rev and not p_force then
    return jsonb_build_object('ok', false, 'conflict', true, 'rev', cur.rev,
      'saved_at', extract(epoch from cur.saved_at)::bigint, 'summary', cur.summary);
  end if;
  new_rev := coalesce(cur.rev, 0) + 1;
  insert into public.saves (user_id, slot, rev, data, summary, saved_at)
  values (u, p_slot, new_rev, p_data, left(coalesce(p_summary, ''), 60), now())
  on conflict (user_id, slot) do update
    set rev = excluded.rev, data = excluded.data, summary = excluded.summary, saved_at = excluded.saved_at;
  return jsonb_build_object('ok', true, 'rev', new_rev, 'saved_at', extract(epoch from now())::bigint);
end $$;

-- ---------------------------------------------------------------------------------------
-- Echo teams follow the same limits; echo duels read their Ring from the server (2669, 2671).

create or replace function public.team_set(p_team jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  clean jsonb := '[]'::jsonb;
  s jsonb;
  moves jsonb;
  mv jsonb;
  party_max int := public._config_int('party_max', 5);
  level_max int := public._config_int('level_max', 60);
begin
  perform public._ensure_profile(u);
  if jsonb_typeof(p_team) <> 'array' then return public._fail('bad_team'); end if;
  for s in select * from jsonb_array_elements(p_team) limit party_max loop
    moves := '[]'::jsonb;
    for mv in select * from jsonb_array_elements(case when jsonb_typeof(s->'moves') = 'array' then s->'moves' else '[]'::jsonb end) limit 4 loop
      moves := moves || to_jsonb(left(regexp_replace(mv #>> '{}', '[^[:alnum:] ''-]', '', 'g'), 24));
    end loop;
    clean := clean || jsonb_build_object(
      'species', left(regexp_replace(coalesce(s->>'species', ''), '[^[:alnum:]]', '', 'g'), 20),
      'level', least(greatest(coalesce((s->>'level')::numeric, 1), 1), level_max)::int,
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
  return (select jsonb_build_object('ok', true, 'name', name, 'color', color, 'team', team,
      'duel_ring', least(greatest(public._config_int('duel_ring', 50), 1), public._config_int('level_max', 60)))
    from public.profiles where id = t);
end $$;

-- ---------------------------------------------------------------------------------------
-- "Wanderer" instead of "Tamer" (item 2672).

alter table public.profiles alter column name set default 'Wanderer';

-- A clean Wanderer name: 1-10 letters, digits or spaces, no banned word. Falls back to "Wanderer XXXX".
create or replace function public._clean_name(p_name text, p_code text) returns text
language plpgsql stable as $$
declare
  n text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  folded text;
begin
  if n = '' or length(n) > 10 or n !~ '^[[:alnum:] ]+$' then
    return 'Wanderer ' || right(p_code, 4);
  end if;
  folded := lower(translate(n, '013457@$ ', 'oieastas'));
  if exists (select 1 from public.banned_words b where position(b.word in folded) > 0) then
    return 'Wanderer ' || right(p_code, 4);
  end if;
  return n;
end $$;

-- Stored default names follow. A player who typed "Tamer" as their own name keeps it only if
-- it is not the old default (the old default was exactly "Tamer" or "Tamer " + code end).
update public.profiles set name = 'Wanderer ' || right(code, 4)
where name = 'Tamer' or name = 'Tamer ' || right(code, 4);

-- ---------------------------------------------------------------------------------------

revoke all on function public._flag_on(text, int), public._config_int(text, int), public._save_schema_ok(jsonb)
  from public, anon, authenticated;
