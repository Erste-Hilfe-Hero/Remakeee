-- Plan area 9 (privacy): the deletion periods the privacy policy promises, as one daily run.
-- server/cleanup.sh calls public._daily_cleanup() every night (cron from server/setup.sh).
-- docs/legal/VVT.md lists every table with purpose, legal basis and period.
--   3899: accounts unused for 24 months (after a 30-day grace mark; playing again clears it)
--   3900: reports after at most 6 months, weekly values after the end of the following week
--   3904: sign-in audit log entries (they hold IP addresses) after 7 days

alter table public.profiles add column if not exists inactive_since timestamptz;

create or replace function public._daily_cleanup() returns jsonb
language plpgsql volatile security definer set search_path = public, auth as $$
declare
  last_week text := to_char((now() - interval '7 days') at time zone 'utc', 'IYYY-"W"IW');
  n_mail int; n_reports int; n_weekly int; n_contrib int; n_rate int; n_tries int; n_codes int;
  n_marked int; n_accounts int; n_audit int := 0;
begin
  delete from public.mail where created_at < now() - interval '30 days';
  get diagnostics n_mail = row_count;
  delete from public.reports where created_at < now() - interval '6 months';
  get diagnostics n_reports = row_count;
  delete from public.weekly_scores where week < last_week;
  get diagnostics n_weekly = row_count;
  delete from public.community_contrib where week < last_week;
  get diagnostics n_contrib = row_count;
  delete from public.rate_events where at < now() - interval '1 day';
  get diagnostics n_rate = row_count;
  delete from public.transfer_attempts where at < now() - interval '1 day';
  get diagnostics n_tries = row_count;
  delete from public.transfer_codes where created_at < now() - interval '7 days';
  get diagnostics n_codes = row_count;

  -- Inactive accounts: marked when 24 months pass without a visit, deleted 30 days later if
  -- the player still has not come back. Coming back (hello, presence) moves last_seen and
  -- the mark is cleared here.
  update public.profiles set inactive_since = null
    where inactive_since is not null and last_seen > inactive_since;
  update public.profiles set inactive_since = now()
    where inactive_since is null and last_seen < now() - interval '24 months';
  get diagnostics n_marked = row_count;
  with gone as (
    delete from auth.users u using public.profiles p
    where p.id = u.id and p.inactive_since < now() - interval '30 days'
      and p.last_seen < now() - interval '24 months'
    returning 1)
  select count(*) into n_accounts from gone;

  -- GoTrue keeps an audit log with IP addresses; the policy promises 7 days.
  if to_regclass('auth.audit_log_entries') is not null then
    begin
      execute 'delete from auth.audit_log_entries where created_at < now() - interval ''7 days''';
      get diagnostics n_audit = row_count;
    exception when insufficient_privilege then
      -- Reported by cleanup.sh; the rest of the run still counts.
      n_audit := -1;
    end;
  end if;

  return jsonb_build_object('mail', n_mail, 'reports', n_reports, 'weekly_scores', n_weekly,
    'community_contrib', n_contrib, 'rate_events', n_rate, 'transfer_attempts', n_tries,
    'transfer_codes', n_codes, 'inactive_marked', n_marked, 'accounts_deleted', n_accounts,
    'audit_log', n_audit, 'at', now());
end $$;
revoke all on function public._daily_cleanup() from public, anon, authenticated;
