-- Plan area 7, item 2675: hello tells the game which features are on for its version, so menus
-- hide what is switched off instead of showing errors.
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
    'online_now', (select count(*) from public.profiles where last_seen > now() - interval '5 minutes'),
    'flags', coalesce((select jsonb_agg(f.key order by f.key) from public.feature_flags f
      where f.enabled and p_version >= f.min_version), '[]'::jsonb));
end $$;

revoke all on function public.hello(int) from public, anon;
grant execute on function public.hello(int) to authenticated;
