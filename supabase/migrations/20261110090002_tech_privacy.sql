-- Plan area 9 (privacy): the deletion periods the privacy policy promises, as one daily run.
-- server/cleanup.sh calls public._daily_cleanup() every night (cron from server/setup.sh).
-- docs/legal/VERARBEITUNGEN.md lists every table with purpose, legal basis and period.
-- It also runs area 7's public._privacy_cleanup() (leagues, battles, cheat flags), so those
-- periods hold even on days nobody says hello.
--   3899: accounts unused for 24 months (after a 30-day grace mark; playing again clears it)
--   3900: reports after at most 6 months, weekly values after the end of the following week
--   3904: sign-in audit log entries (they hold IP addresses) after 7 days

alter table public.profiles add column if not exists inactive_since timestamptz;

-- Removes an account and every row anywhere that still carries its id, like delete_account
-- (20261110000006) does for the signed-in player.
create or replace function public._purge_account(p_user uuid) returns void
language plpgsql volatile security definer set search_path = public, auth as $$
declare
  r record;
  c text;
  pass int;
  left_over boolean;
begin
  delete from auth.users where id = p_user;
  for pass in 1..3 loop
    left_over := false;
    for r in select * from public._account_tables() loop
      foreach c in array r.cols loop
        begin
          execute format('delete from public.%I where %I = $1', r.tbl, c) using p_user;
        exception when foreign_key_violation then
          left_over := true;
        end;
      end loop;
    end loop;
    exit when not left_over;
  end loop;
end $$;
revoke all on function public._purge_account(uuid) from public, anon, authenticated;

create or replace function public._daily_cleanup() returns jsonb
language plpgsql volatile security definer set search_path = public, auth as $$
declare
  last_week text := to_char((now() - interval '7 days') at time zone 'utc', 'IYYY-"W"IW');
  n_mail int; n_reports int; n_weekly int; n_contrib int; n_rate int; n_tries int; n_codes int;
  n_marked int; n_accounts int := 0; n_audit int := 0;
  gone uuid;
begin
  perform public._privacy_cleanup();
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
  for gone in select p.id from public.profiles p
      where p.inactive_since < now() - interval '30 days' and p.last_seen < now() - interval '24 months' loop
    perform public._purge_account(gone);
    n_accounts := n_accounts + 1;
  end loop;

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
