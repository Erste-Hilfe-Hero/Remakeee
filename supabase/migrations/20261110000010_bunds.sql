-- Plan area 7, items 2817-2821, 2842, 2900: bunds (guilds). Names are two word numbers
-- (scripts/online/BundWords.gd), so nobody types free text. One bund per player, at most 30
-- members, roles leader, helper and member. Leaving is always possible and costs nothing.
-- Blocking works here too: no invite and no request between players who blocked each other.
-- Everything waits behind the feature flag 'bund'.

insert into public.server_config (key, value) values ('bund_max', '30'), ('bund_words', '120')
on conflict (key) do nothing;

create table if not exists public.bunds (
  id bigserial primary key,
  name_a int not null,
  name_b int not null,
  created_at timestamptz not null default now(),
  dissolve_at timestamptz
);
create table if not exists public.bund_members (
  user_id uuid primary key references auth.users (id) on delete cascade,
  bund_id bigint not null references public.bunds (id) on delete cascade,
  role text not null default 'member' check (role in ('leader', 'helper', 'member')),
  joined_at timestamptz not null default now()
);
create index if not exists bund_members_bund on public.bund_members (bund_id, joined_at);
create table if not exists public.bund_invites (
  id bigserial primary key,
  bund_id bigint not null references public.bunds (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('invite', 'request')),
  by_user uuid references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (bund_id, user_id)
);
alter table public.bunds enable row level security;
alter table public.bund_members enable row level security;
alter table public.bund_invites enable row level security;
revoke all on public.bunds, public.bund_members, public.bund_invites from public, anon, authenticated;

create or replace function public._bund_role(p_user uuid) returns text
language sql stable as $$
  select role from public.bund_members where user_id = p_user
$$;

create or replace function public._bund_id(p_user uuid) returns bigint
language sql stable as $$
  select bund_id from public.bund_members where user_id = p_user
$$;

-- A bund always has a leader: when the leader is gone (left, deleted the account), the oldest
-- helper takes over, otherwise the oldest member. An empty bund is removed.
create or replace function public._bund_fix(p_bund bigint) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if not exists (select 1 from public.bund_members where bund_id = p_bund) then
    delete from public.bunds where id = p_bund;
    return;
  end if;
  if not exists (select 1 from public.bund_members where bund_id = p_bund and role = 'leader') then
    update public.bund_members set role = 'leader' where user_id = (select user_id from public.bund_members
      where bund_id = p_bund order by role = 'helper' desc, joined_at, user_id limit 1);
  end if;
  if (select count(*) from public.bund_members where bund_id = p_bund) < 3 then
    update public.bunds set dissolve_at = null where id = p_bund and dissolve_at is not null;
  end if;
end $$;

create or replace function public._bund_check(u uuid) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if not public._flag_on('bund', 2147483647) then return 'feature_off'; end if;
  if not public._social(u) then return 'social_off'; end if;
  return null;
end $$;

create or replace function public._bund_join(p_bund bigint, p_user uuid, p_role text) returns text
language plpgsql volatile security definer set search_path = public as $$
begin
  if exists (select 1 from public.bund_members where user_id = p_user) then return 'in_bund'; end if;
  if (select count(*) from public.bund_members where bund_id = p_bund) >= public._config_int('bund_max', 30) then
    return 'full';
  end if;
  insert into public.bund_members (user_id, bund_id, role) values (p_user, p_bund, p_role);
  delete from public.bund_invites where user_id = p_user;
  return null;
end $$;

create or replace function public.bund_create(p_a int, p_b int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  n int := public._config_int('bund_words', 120);
  b bigint;
begin
  if e is not null then return public._fail(e); end if;
  if p_a is null or p_b is null or p_a not between 0 and n - 1 or p_b not between 0 and n - 1 then
    return public._fail('bad_name');
  end if;
  if public._bund_id(u) is not null then return public._fail('in_bund'); end if;
  if not public._rate_ok(u, 'bund_create', 3) then return public._fail('slow_down'); end if;
  insert into public.bunds (name_a, name_b) values (p_a, p_b) returning id into b;
  perform public._bund_join(b, u, 'leader');
  return jsonb_build_object('ok', true, 'bund', b);
end $$;

-- The own bund (members with name, code and role; open invites and requests for leader and
-- helpers) and the invitations waiting for the caller.
create or replace function public.bund_info() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  r text;
  bund jsonb := null;
begin
  if e is not null then return public._fail(e); end if;
  if b is not null then
    perform public._bund_fix(b);
    r := public._bund_role(u);
    select jsonb_build_object('id', x.id, 'name', jsonb_build_array(x.name_a, x.name_b), 'role', r,
      'dissolve_at', extract(epoch from x.dissolve_at)::bigint,
      'members', coalesce((select jsonb_agg(jsonb_build_object('name', p.name, 'code', p.code, 'role', m.role,
          'me', m.user_id = u, 'online', p.last_seen > now() - interval '5 minutes')
        order by m.role = 'leader' desc, m.role = 'helper' desc, m.joined_at)
        from public.bund_members m join public.profiles p on p.id = m.user_id where m.bund_id = x.id), '[]'::jsonb),
      'pending', case when r in ('leader', 'helper') then coalesce((select jsonb_agg(jsonb_build_object(
          'kind', i.kind, 'name', p.name, 'code', p.code) order by i.created_at)
        from public.bund_invites i join public.profiles p on p.id = i.user_id where i.bund_id = x.id), '[]'::jsonb)
        else '[]'::jsonb end)
    into bund from public.bunds x where x.id = b;
  end if;
  return jsonb_build_object('ok', true, 'bund', bund,
    'invites', coalesce((select jsonb_agg(jsonb_build_object('bund', x.id, 'name', jsonb_build_array(x.name_a, x.name_b),
        'by', (select name from public.profiles where id = i.by_user),
        'size', (select count(*) from public.bund_members where bund_id = x.id)) order by i.created_at)
      from public.bund_invites i join public.bunds x on x.id = i.bund_id
      where i.user_id = u and i.kind = 'invite'), '[]'::jsonb));
end $$;

create or replace function public.bund_invite(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  t uuid := public._by_code(p_code);
  b bigint := public._bund_id(u);
begin
  if e is not null then return public._fail(e); end if;
  if b is null or public._bund_role(u) not in ('leader', 'helper') then return public._fail('not_allowed'); end if;
  if t is null or t = u or public._blocked(u, t) or not public._social(t) then return public._fail('no_such_code'); end if;
  if public._bund_id(t) is not null then return public._fail('in_bund'); end if;
  if not public._rate_ok(u, 'bund_invite', 30) then return public._fail('slow_down'); end if;
  -- Asked to join already: an invite accepts it.
  if exists (select 1 from public.bund_invites where bund_id = b and user_id = t and kind = 'request') then
    e := public._bund_join(b, t, 'member');
    if e is not null then return public._fail(e); end if;
    return jsonb_build_object('ok', true, 'joined', true);
  end if;
  insert into public.bund_invites (bund_id, user_id, kind, by_user) values (b, t, 'invite', u)
  on conflict (bund_id, user_id) do nothing;
  return jsonb_build_object('ok', true, 'joined', false);
end $$;

-- Ask to join the bund of the player with code p_code.
create or replace function public.bund_request(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  t uuid := public._by_code(p_code);
  b bigint := public._bund_id(t);
begin
  if e is not null then return public._fail(e); end if;
  if t is null or t = u or public._blocked(u, t) or not public._social(t) or b is null then
    return public._fail('no_such_bund');
  end if;
  if public._bund_id(u) is not null then return public._fail('in_bund'); end if;
  if exists (select 1 from public.bund_members m where m.bund_id = b and public._blocked(u, m.user_id)) then
    return public._fail('no_such_bund');
  end if;
  if not public._rate_ok(u, 'bund_request', 10) then return public._fail('slow_down'); end if;
  if exists (select 1 from public.bund_invites where bund_id = b and user_id = u and kind = 'invite') then
    e := public._bund_join(b, u, 'member');
    if e is not null then return public._fail(e); end if;
    return jsonb_build_object('ok', true, 'joined', true);
  end if;
  insert into public.bund_invites (bund_id, user_id, kind, by_user) values (b, u, 'request', u)
  on conflict (bund_id, user_id) do nothing;
  return jsonb_build_object('ok', true, 'joined', false);
end $$;

-- The invited player says yes or no.
create or replace function public.bund_answer(p_bund bigint, p_accept boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
begin
  if e is not null then return public._fail(e); end if;
  if not exists (select 1 from public.bund_invites where bund_id = p_bund and user_id = u and kind = 'invite') then
    return public._fail('no_such_invite');
  end if;
  if not coalesce(p_accept, false) then
    delete from public.bund_invites where bund_id = p_bund and user_id = u;
    return jsonb_build_object('ok', true, 'joined', false);
  end if;
  e := public._bund_join(p_bund, u, 'member');
  if e is not null then return public._fail(e); end if;
  return jsonb_build_object('ok', true, 'joined', true);
end $$;

-- Leader or helper answer a request.
create or replace function public.bund_admit(p_code text, p_accept boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  t uuid := public._by_code(p_code);
  b bigint := public._bund_id(u);
begin
  if e is not null then return public._fail(e); end if;
  if b is null or public._bund_role(u) not in ('leader', 'helper') then return public._fail('not_allowed'); end if;
  if t is null or not exists (select 1 from public.bund_invites where bund_id = b and user_id = t and kind = 'request') then
    return public._fail('no_such_request');
  end if;
  if not coalesce(p_accept, false) then
    delete from public.bund_invites where bund_id = b and user_id = t;
    return jsonb_build_object('ok', true, 'joined', false);
  end if;
  e := public._bund_join(b, t, 'member');
  if e is not null then return public._fail(e); end if;
  return jsonb_build_object('ok', true, 'joined', true);
end $$;

-- Helpers remove members, the leader removes anyone.
create or replace function public.bund_kick(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  t uuid := public._by_code(p_code);
  b bigint := public._bund_id(u);
  mine text := public._bund_role(u);
begin
  if e is not null then return public._fail(e); end if;
  if b is null or t is null or t = u or public._bund_id(t) is distinct from b then return public._fail('no_such_member'); end if;
  if not (mine = 'leader' or (mine = 'helper' and public._bund_role(t) = 'member')) then
    return public._fail('not_allowed');
  end if;
  delete from public.bund_members where user_id = t;
  perform public._bund_fix(b);
  return jsonb_build_object('ok', true);
end $$;

-- Only the leader names helpers or hands the bund over (then becomes a helper).
create or replace function public.bund_role(p_code text, p_role text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  t uuid := public._by_code(p_code);
  b bigint := public._bund_id(u);
begin
  if e is not null then return public._fail(e); end if;
  if coalesce(p_role, '') not in ('leader', 'helper', 'member') then return public._fail('bad_role'); end if;
  if b is null or t is null or t = u or public._bund_id(t) is distinct from b then return public._fail('no_such_member'); end if;
  if public._bund_role(u) <> 'leader' then return public._fail('not_allowed'); end if;
  if p_role = 'leader' then
    update public.bund_members set role = 'helper' where user_id = u;
  end if;
  update public.bund_members set role = p_role where user_id = t;
  return jsonb_build_object('ok', true);
end $$;

-- Leave at any time, without a penalty (2821).
create or replace function public.bund_leave() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  b bigint := public._bund_id(u);
begin
  if b is null then return public._fail('no_bund'); end if;
  delete from public.bund_members where user_id = u;
  perform public._bund_fix(b);
  return jsonb_build_object('ok', true);
end $$;

-- Only the leader dissolves. With 3 or more members the leader confirms again after 24 hours (2842).
create or replace function public.bund_dissolve() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._bund_check(u);
  b bigint := public._bund_id(u);
  x public.bunds;
begin
  if e is not null then return public._fail(e); end if;
  if b is null or public._bund_role(u) <> 'leader' then return public._fail('not_allowed'); end if;
  select * into x from public.bunds where id = b for update;
  if (select count(*) from public.bund_members where bund_id = b) >= 3 then
    if x.dissolve_at is null then
      update public.bunds set dissolve_at = now() + interval '24 hours' where id = b;
      return jsonb_build_object('ok', true, 'dissolved', false, 'confirm_from', extract(epoch from now() + interval '24 hours')::bigint);
    end if;
    if x.dissolve_at > now() then
      return jsonb_build_object('ok', true, 'dissolved', false, 'confirm_from', extract(epoch from x.dissolve_at)::bigint);
    end if;
  end if;
  delete from public.bunds where id = b;
  return jsonb_build_object('ok', true, 'dissolved', true);
end $$;

-- The leader changes their mind.
create or replace function public.bund_keep() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
begin
  if public._bund_role(u) is distinct from 'leader' then return public._fail('not_allowed'); end if;
  update public.bunds set dissolve_at = null where id = public._bund_id(u);
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public._bund_role(uuid), public._bund_id(uuid), public._bund_fix(bigint), public._bund_check(uuid),
  public._bund_join(bigint, uuid, text) from public, anon, authenticated;
revoke all on function public.bund_create(int, int), public.bund_info(), public.bund_invite(text), public.bund_request(text),
  public.bund_answer(bigint, boolean), public.bund_admit(text, boolean), public.bund_kick(text), public.bund_role(text, text),
  public.bund_leave(), public.bund_dissolve(), public.bund_keep() from public, anon;
grant execute on function public.bund_create(int, int), public.bund_info(), public.bund_invite(text), public.bund_request(text),
  public.bund_answer(bigint, boolean), public.bund_admit(text, boolean), public.bund_kick(text), public.bund_role(text, text),
  public.bund_leave(), public.bund_dissolve(), public.bund_keep() to authenticated;
