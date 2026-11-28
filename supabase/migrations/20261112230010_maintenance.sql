-- Online 100 plan point 95: the game warns on the title screen 24 hours before a planned
-- maintenance. Set it with: update server_config set value = '<unix seconds>' where key = 'maintenance_at';
insert into public.server_config (key, value) values ('maintenance_at', '0') on conflict (key) do nothing;

create or replace function public.maintenance_info() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public._uid();
  return jsonb_build_object('at', coalesce((public._config('maintenance_at', '0'))::text::bigint, 0),
    'server_time', extract(epoch from now())::bigint);
end $$;

revoke all on function public.maintenance_info() from public, anon;
grant execute on function public.maintenance_info() to authenticated;
