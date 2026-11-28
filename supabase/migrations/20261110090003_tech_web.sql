-- Plan area 9, item 3765: accounts from the browser test build are marked platform = 'web' and
-- deleted after 30 days without a visit (privacy policy 3.1). The game reports its platform
-- with platform_set after hello; an account moved to a phone (transfer code) becomes 'app'.

alter table public.profiles add column if not exists platform text not null default 'app';
do $$ begin
  alter table public.profiles add constraint profiles_platform_check check (platform in ('app', 'web'));
exception when duplicate_object then null;
end $$;

create or replace function public.platform_set(p_platform text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
begin
  if p_platform is null or p_platform not in ('app', 'web') then
    return jsonb_build_object('ok', false, 'error', 'bad_platform');
  end if;
  update public.profiles set platform = p_platform where id = u;
  return jsonb_build_object('ok', true, 'platform', p_platform);
end $$;
revoke all on function public.platform_set(text) from public, anon;
grant execute on function public.platform_set(text) to authenticated;

-- Called by server/cleanup.sh next to _daily_cleanup. Returns how many accounts were removed.
create or replace function public._web_cleanup() returns int
language plpgsql volatile security definer set search_path = public, auth as $$
declare
  gone uuid;
  n int := 0;
begin
  for gone in select p.id from public.profiles p
      where p.platform = 'web' and p.last_seen < now() - interval '30 days' loop
    perform public._purge_account(gone);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public._web_cleanup() from public, anon, authenticated;
