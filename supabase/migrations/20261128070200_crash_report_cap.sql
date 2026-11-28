-- 1.3.2 security review finding 6: 3 reports an hour per account let about 28 free accounts fill
-- the 2000 a day cap, so real reports were dropped. An account now keeps at most 5 reports a day
-- (rate_events keeps one day); more are answered kept: false. Filling the cap then takes 400
-- accounts. The app sends one report per unexpected end, so a real player stays far below.

create or replace function public.crash_report(p_version text, p_platform text, p_scene text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  if not public._rate_ok(u, 'crash_report', 3) then return public._fail('slow_down'); end if;
  if (select count(*) from public.rate_events where user_id = u and kind = 'crash_report'
      and at > now() - interval '1 day') > 5 then
    return jsonb_build_object('ok', true, 'kept', false);
  end if;
  delete from public.crash_reports where at < now() - interval '30 days';
  if (select count(*) from public.crash_reports where at > now() - interval '1 day') >= 2000 then
    return jsonb_build_object('ok', true, 'kept', false);
  end if;
  insert into public.crash_reports (version, platform, scene)
    values (left(coalesce(p_version, ''), 40), left(coalesce(p_platform, ''), 40), left(coalesce(p_scene, ''), 40));
  return jsonb_build_object('ok', true, 'kept', true);
end $$;

revoke all on function public.crash_report(text, text, text) from public, anon;
grant execute on function public.crash_report(text, text, text) to authenticated;
