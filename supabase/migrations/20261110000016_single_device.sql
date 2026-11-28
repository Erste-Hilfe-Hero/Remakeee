-- Plan area 7, item 3010: one account plays on one device at a time. After hello the game
-- claims the account with session_claim and sends the token it got in the request header
-- x-chimora-session. A save from a device whose token is not the newest one is refused
-- ("other_device"), and presence tells that device, which then shows "Signed in on another
-- device" and goes to the title, where the player can choose to play there again.
-- Requests without the header (older builds) are not checked.

alter table public.profiles add column if not exists session_token text;

-- The token this request was sent with, or null.
create or replace function public._device() returns text
language plpgsql stable set search_path = public as $$
declare h text := current_setting('request.headers', true);
begin
  if h is null or h = '' then
    return null;
  end if;
  return nullif(left(h::json->>'x-chimora-session', 64), '');
exception when others then
  return null;
end $$;

-- True when this request comes from a device that is no longer the newest one of [u].
create or replace function public._other_device(u uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.session_token is not null and public._device() is not null
    and p.session_token <> public._device() from public.profiles p where p.id = u), false)
$$;

-- Claims the account for this device. p_token: the token this device got before (empty on a
-- fresh start or when the player chose to play here). A device whose token was replaced in
-- the meantime gets other_device and nothing changes.
create or replace function public.session_claim(p_token text default null) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  cur text;
  t text := nullif(left(coalesce(p_token, ''), 64), '');
begin
  perform public._ensure_profile(u);
  select session_token into cur from public.profiles where id = u for update;
  if t is not null and cur is not null and cur <> t then
    return jsonb_build_object('ok', false, 'error', 'other_device');
  end if;
  if t is null or cur is null then
    t := replace(gen_random_uuid()::text, '-', '');
    update public.profiles set session_token = t where id = u;
  end if;
  return jsonb_build_object('ok', true, 'token', t);
end $$;

-- Every change of a stored save (saving, trades, restores) from an older device is refused.
-- Moving the account to a new phone changes no data and is not checked.
create or replace function public._save_device_check() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and old.data is not distinct from new.data and old.rev = new.rev then
    return new;
  end if;
  if public._other_device(new.user_id) then
    raise exception 'other_device';
  end if;
  return new;
end $$;
drop trigger if exists saves_device on public.saves;
create trigger saves_device before insert or update on public.saves for each row execute function public._save_device_check();

-- The heartbeat also says when another device took over.
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
    'online_now', (select count(*) from public.profiles where last_seen > now() - interval '5 minutes'),
    'other_device', public._other_device(u));
end $$;

revoke all on function public._device(), public._other_device(uuid), public._save_device_check()
  from public, anon, authenticated, chimora_referee;
revoke all on function public.session_claim(text), public.presence(text) from public, anon, chimora_referee;
grant execute on function public.session_claim(text), public.presence(text) to authenticated;
