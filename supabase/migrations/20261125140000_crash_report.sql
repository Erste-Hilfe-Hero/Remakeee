-- 200 list item 184: anonymous crash reports. The app keeps one short note when its last run
-- ended unexpectedly (game version, platform, last scene) and sends it once. The sign-in is used
-- only for a rate limit (3 an hour, rate_events keeps it one day); the report row has no account
-- id, name or save. Kept 30 days, at most 2000 a day.

create table if not exists public.crash_reports (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  version text not null default '',
  platform text not null default '',
  scene text not null default ''
);
create index if not exists crash_reports_at on public.crash_reports (at);
alter table public.crash_reports enable row level security;
revoke all on public.crash_reports from public, anon, authenticated;

create or replace function public.crash_report(p_version text, p_platform text, p_scene text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  if not public._rate_ok(u, 'crash_report', 3) then return public._fail('slow_down'); end if;
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

insert into public.feature_flags (key, enabled, min_version, note) values
  ('crash_report', true, 4, 'Anonyme Absturzberichte (ab 1.3.1)')
on conflict (key) do nothing;
