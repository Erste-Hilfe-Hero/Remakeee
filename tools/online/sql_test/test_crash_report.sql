-- Anonymous crash reports (20261125140000_crash_report.sql, 200 list item 184): a player may send
-- three an hour, the row has no account, nobody can read the table, long texts are cut, old rows go.
create temp table cr (k text primary key, v jsonb);
grant all on cr to authenticated;
insert into auth.users (id) values ('20000000-0000-0000-0000-000000000184') on conflict do nothing;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000184', false);
delete from public.rate_events where kind = 'crash_report';
delete from public.crash_reports;
insert into public.crash_reports (at, version) values (now() - interval '31 days', 'old');
set role authenticated;
insert into cr values ('one', public.crash_report('1.3.1', 'Android', repeat('x', 90)));
reset role;
do $$ begin
  assert (select v->>'kept' from cr where k = 'one') = 'true', 'kept';
  assert (select count(*) from public.crash_reports) = 1, 'old row deleted, one new';
  assert (select length(scene) from public.crash_reports) = 40, 'scene cut to 40';
  assert not has_function_privilege('anon', 'public.crash_report(text, text, text)', 'execute'), 'needs sign-in';
  assert not has_table_privilege('authenticated', 'public.crash_reports', 'select'), 'players cannot read';
  assert (select enabled and min_version = 4 from public.feature_flags where key = 'crash_report'), 'flag on from 1.3.1';
end $$;
insert into public.crash_reports (version) select 'fill' from generate_series(1, 1999);
set role authenticated;
insert into cr values ('full', public.crash_report('1.3.1', 'iOS', 'battle'));
insert into cr values ('third', public.crash_report('1.3.1', 'iOS', 'battle'));
insert into cr values ('fourth', public.crash_report('1.3.1', 'iOS', 'battle'));
reset role;
do $$ begin
  assert (select v->>'kept' from cr where k = 'full') = 'false', 'daily cap';
  assert (select count(*) from public.crash_reports) = 2000, 'nothing over the cap';
  assert (select v->>'error' from cr where k = 'fourth') = 'slow_down', 'three an hour';
end $$;
delete from public.crash_reports;
delete from public.rate_events where kind = 'crash_report';

-- One account keeps at most 5 reports a day (20261128070200_crash_report_cap.sql), so a few
-- accounts cannot fill the daily cap.
insert into public.rate_events (user_id, kind, at)
  select '20000000-0000-0000-0000-000000000184', 'crash_report', now() - interval '2 hours' from generate_series(1, 5);
set role authenticated;
insert into cr values ('sixth', public.crash_report('1.3.1', 'iOS', 'battle'));
reset role;
do $$ begin
  assert (select v->>'kept' from cr where k = 'sixth') = 'false', 'five a day per account';
  assert (select count(*) from public.crash_reports) = 0, 'sixth not stored';
end $$;
delete from public.rate_events where kind = 'crash_report';
