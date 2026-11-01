-- Chimora online core: profiles, server saves, server config.
-- Chimora is online only. The server holds the saves; the phone keeps a cache copy.
--
-- Security model: every table has row level security on and NO policies, and the anon and
-- authenticated roles have no table rights. The game only talks to the security-definer
-- functions below (PostgREST /rest/v1/rpc/<name>), which check auth.uid() themselves.
-- That keeps all rules (plausibility, limits, rewards) on the server.

create table if not exists public.server_config (
  key text primary key,
  value jsonb not null
);

insert into public.server_config (key, value) values
  -- Builds older than this are sent to the store to update (version/code in export_presets.cfg).
  ('min_version', '1'),
  -- Short notice on the title screen, e.g. planned maintenance. Empty = none.
  ('motd', '""')
on conflict (key) do nothing;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  -- Friend code: 8 characters without look-alikes (no 0/O, 1/I/L).
  code text not null unique,
  name text not null default 'Tamer',
  color int not null default 0,
  -- Favourite Spirling species shown on the Tamer card.
  favorite text not null default '',
  -- Public card values: seals, spirlog count, play hours, achievements (numbers only).
  card jsonb not null default '{}'::jsonb,
  -- Where in the game the player is (in-game place name, never a real location).
  place text not null default '',
  -- Parents can switch off friends, mail and greetings. Saves stay online.
  social boolean not null default true,
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.saves (
  user_id uuid not null references auth.users (id) on delete cascade,
  slot int not null check (slot between 1 and 3),
  rev int not null default 1,
  data jsonb not null,
  summary text not null default '',
  saved_at timestamptz not null default now(),
  primary key (user_id, slot)
);

-- Moving to a new phone without email (item 4): a one-time transfer code, stored only as a hash.
create table if not exists public.transfer_codes (
  user_id uuid primary key references auth.users (id) on delete cascade,
  code_hash text not null unique,
  created_at timestamptz not null default now()
);
create table if not exists public.transfer_attempts (
  user_id uuid not null,
  at timestamptz not null default now()
);

-- Words a Tamer name may not contain (lower case). Ali can add rows in the dashboard.
create table if not exists public.banned_words (
  word text primary key
);
insert into public.banned_words (word) values
  ('fuck'), ('shit'), ('bitch'), ('nazi'), ('hitler'), ('arsch'), ('fotze'), ('hure'),
  ('wichser'), ('nigg'), ('schwuchtel'), ('sex'), ('porn'), ('kill'), ('cunt'), ('dick')
on conflict (word) do nothing;

alter table public.server_config enable row level security;
alter table public.profiles enable row level security;
alter table public.saves enable row level security;
alter table public.banned_words enable row level security;
alter table public.transfer_codes enable row level security;
alter table public.transfer_attempts enable row level security;
revoke all on public.server_config, public.profiles, public.saves, public.banned_words,
  public.transfer_codes, public.transfer_attempts from anon, authenticated;

-- ---------------------------------------------------------------------------------------
-- Helpers (not callable by players)

create or replace function public._uid() returns uuid
language plpgsql stable as $$
declare u uuid := auth.uid();
begin
  if u is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  return u;
end $$;

create or replace function public._config(p_key text, p_default jsonb default 'null'::jsonb) returns jsonb
language sql stable as $$
  select coalesce((select value from public.server_config where key = p_key), p_default)
$$;

create or replace function public._random_code(p_len int) returns text
language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  c text := '';
begin
  for i in 1..p_len loop
    c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return c;
end $$;

create or replace function public._new_code() returns text
language plpgsql volatile as $$
declare c text;
begin
  loop
    c := public._random_code(8);
    exit when not exists (select 1 from public.profiles where code = c);
  end loop;
  return c;
end $$;

create or replace function public._hash(p text) returns text
language sql immutable as $$
  select encode(sha256(convert_to(upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]', '', 'g')), 'UTF8')), 'hex')
$$;

-- A clean Tamer name: 1-10 letters, digits or spaces, no banned word. Falls back to "Tamer XXXX".
create or replace function public._clean_name(p_name text, p_code text) returns text
language plpgsql stable as $$
declare
  n text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  folded text;
begin
  if n = '' or length(n) > 10 or n !~ '^[[:alnum:] ]+$' then
    return 'Tamer ' || right(p_code, 4);
  end if;
  folded := lower(translate(n, '013457@$ ', 'oieastas'));
  if exists (select 1 from public.banned_words b where position(b.word in folded) > 0) then
    return 'Tamer ' || right(p_code, 4);
  end if;
  return n;
end $$;

create or replace function public._ensure_profile(p_uid uuid) returns public.profiles
language plpgsql volatile as $$
declare p public.profiles;
begin
  select * into p from public.profiles where id = p_uid;
  if not found then
    insert into public.profiles (id, code) values (p_uid, public._new_code()) returning * into p;
  end if;
  return p;
end $$;

create or replace function public._profile_json(p public.profiles) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'code', p.code, 'name', p.name, 'color', p.color, 'favorite', p.favorite,
    'card', p.card, 'place', p.place, 'social', p.social)
$$;

-- Plausibility check for a save (item 185): rejects states the game cannot reach.
create or replace function public._save_ok(d jsonb) returns boolean
language plpgsql immutable as $$
declare s jsonb;
begin
  if jsonb_typeof(d) <> 'object' then return false; end if;
  if pg_column_size(d) > 400000 then return false; end if;
  if jsonb_typeof(coalesce(d->'party', '[]'::jsonb)) <> 'array' then return false; end if;
  if jsonb_array_length(coalesce(d->'party', '[]'::jsonb)) > 6 then return false; end if;
  if coalesce((d->>'money')::numeric, 0) not between 0 and 9999999 then return false; end if;
  for s in select * from jsonb_array_elements(coalesce(d->'party', '[]'::jsonb) || coalesce(d->'storage', '[]'::jsonb)) loop
    if coalesce((s->>'level')::numeric, 1) not between 1 and 100 then return false; end if;
  end loop;
  return true;
exception when others then
  return false;
end $$;

-- ---------------------------------------------------------------------------------------
-- Player API

-- First call after sign-in. Creates the profile, returns it with server time and config.
create or replace function public.hello(p_version int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  p public.profiles;
  min_v int := coalesce((public._config('min_version', '1'))::text::int, 1);
begin
  p := public._ensure_profile(u);
  update public.profiles set last_seen = now() where id = u;
  return jsonb_build_object(
    'profile', public._profile_json(p),
    'server_time', extract(epoch from now())::bigint,
    'update_required', p_version < min_v,
    'motd', public._config('motd', '""'),
    'online_now', (select count(*) from public.profiles where last_seen > now() - interval '5 minutes'));
end $$;

-- Updates the public profile. Names are cleaned on the server.
create or replace function public.profile_set(p_name text, p_color int, p_favorite text, p_card jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  p public.profiles := public._ensure_profile(u);
  clean jsonb := '{}'::jsonb;
  k text;
begin
  -- Only small whole numbers go on the card.
  foreach k in array array['seals', 'seen', 'bonded', 'hours', 'achievements'] loop
    if p_card ? k and jsonb_typeof(p_card->k) = 'number' then
      clean := clean || jsonb_build_object(k, least(greatest((p_card->>k)::numeric, 0), 99999)::int);
    end if;
  end loop;
  update public.profiles set
    name = public._clean_name(p_name, p.code),
    color = least(greatest(coalesce(p_color, 0), 0), 3),
    favorite = left(regexp_replace(coalesce(p_favorite, ''), '[^[:alnum:] ]', '', 'g'), 20),
    card = clean,
    last_seen = now()
  where id = u returning * into p;
  return public._profile_json(p);
end $$;

-- Heartbeat while playing: last seen and the in-game place.
create or replace function public.presence(p_place text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._ensure_profile(u);
  update public.profiles set
    last_seen = now(),
    place = left(regexp_replace(coalesce(p_place, ''), '[^[:alnum:] ''-]', '', 'g'), 24)
  where id = u;
  return jsonb_build_object(
    'server_time', extract(epoch from now())::bigint,
    'online_now', (select count(*) from public.profiles where last_seen > now() - interval '5 minutes'));
end $$;

create or replace function public.save_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'slot', slot, 'rev', rev, 'summary', summary,
      'saved_at', extract(epoch from saved_at)::bigint) order by slot), '[]'::jsonb)
  from public.saves where user_id = public._uid()
$$;

create or replace function public.save_get(p_slot int) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('slot', slot, 'rev', rev, 'data', data, 'summary', summary,
      'saved_at', extract(epoch from saved_at)::bigint)
  from public.saves where user_id = public._uid() and slot = p_slot
$$;

-- Stores a save. p_base_rev is the revision the game last loaded or wrote (0 = new slot).
-- If another device wrote in between, nothing is stored and conflict = true comes back,
-- unless p_force is set (the player chose to keep this device's journey).
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

create or replace function public.save_delete(p_slot int) returns jsonb
language sql volatile security definer set search_path = public as $$
  with d as (delete from public.saves where user_id = public._uid() and slot = p_slot returning 1)
  select jsonb_build_object('ok', true, 'deleted', (select count(*) from d))
$$;

-- Makes a one-time code to move this account to another phone (valid 7 days, item 4).
-- Only its hash is stored; a new code replaces the old one.
create or replace function public.transfer_create() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  c text := public._random_code(12);
begin
  perform public._ensure_profile(u);
  insert into public.transfer_codes (user_id, code_hash, created_at) values (u, public._hash(c), now())
  on conflict (user_id) do update set code_hash = excluded.code_hash, created_at = excluded.created_at;
  return jsonb_build_object('code', c, 'valid_days', 7);
end $$;

-- On the new phone (signed in with a fresh account): takes over the account the code belongs to.
-- The fresh account is dropped. At most 10 tries per hour.
create or replace function public.transfer_claim(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public, auth as $$
declare
  u uuid := public._uid();
  old uuid;
begin
  if (select count(*) from public.transfer_attempts where user_id = u and at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many_tries');
  end if;
  insert into public.transfer_attempts (user_id) values (u);
  delete from public.transfer_attempts where at < now() - interval '1 day';
  select user_id into old from public.transfer_codes
    where code_hash = public._hash(p_code) and created_at > now() - interval '7 days';
  if old is null or old = u then
    return jsonb_build_object('ok', false, 'error', 'bad_code');
  end if;
  delete from public.transfer_codes where user_id = old;
  delete from public.saves where user_id = u;
  delete from public.profiles where id = u;
  perform public._move_account(old, u);
  delete from auth.users where id = old;
  return jsonb_build_object('ok', true);
end $$;

-- Moves every row of [old] to [new]. Later migrations replace this to move their own tables too.
create or replace function public._move_account(p_old uuid, p_new uuid) returns void
language plpgsql volatile as $$
begin
  update public.profiles set id = p_new where id = p_old;
  update public.saves set user_id = p_new where user_id = p_old;
end $$;

-- Deletes the account and everything that belongs to it (GDPR art. 17, store rules).
create or replace function public.delete_account() returns jsonb
language plpgsql volatile security definer set search_path = public, auth as $$
declare u uuid := public._uid();
begin
  delete from auth.users where id = u;
  return jsonb_build_object('ok', true);
end $$;

-- Only the player API is callable. Helpers stay private.
revoke all on function public._random_code(int), public._hash(text), public._move_account(uuid, uuid) from public, anon, authenticated;
revoke all on function public._uid(), public._config(text, jsonb), public._new_code(),
  public._clean_name(text, text), public._ensure_profile(uuid), public._profile_json(public.profiles),
  public._save_ok(jsonb) from public, anon, authenticated;
revoke all on function public.hello(int), public.profile_set(text, int, text, jsonb), public.presence(text),
  public.save_list(), public.save_get(int), public.save_put(int, jsonb, text, int, boolean),
  public.save_delete(int), public.delete_account(), public.transfer_create(), public.transfer_claim(text) from public, anon;
grant execute on function public.hello(int), public.profile_set(text, int, text, jsonb), public.presence(text),
  public.save_list(), public.save_get(int), public.save_put(int, jsonb, text, int, boolean),
  public.save_delete(int), public.delete_account(), public.transfer_create(), public.transfer_claim(text) to authenticated;
