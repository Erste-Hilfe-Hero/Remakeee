-- Plan area 9: the daily deletion run keeps the periods of docs/legal/DATENSCHUTZ.md.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000d1'), ('00000000-0000-0000-0000-0000000000d2'),
  ('00000000-0000-0000-0000-0000000000d3')
on conflict do nothing;
create table if not exists auth.audit_log_entries (id uuid default gen_random_uuid(), ip_address text,
  created_at timestamptz default now());

do $$
declare
  a uuid := '00000000-0000-0000-0000-0000000000d1';
  b uuid := '00000000-0000-0000-0000-0000000000d2';
  c uuid := '00000000-0000-0000-0000-0000000000d3';
  r jsonb;
begin
  insert into public.profiles (id, code, last_seen) values
    (a, 'DDDDAAAA', now() - interval '25 months'),
    (b, 'DDDDBBBB', now() - interval '3 days'),
    (c, 'DDDDCCCC', now() - interval '25 months')
  on conflict (id) do update set last_seen = excluded.last_seen, inactive_since = null;
  insert into public.mail (sender, recipient, kind, created_at) values
    (b, b, 'wave', now() - interval '31 days'), (b, b, 'wave', now() - interval '2 days');
  insert into public.reports (reporter, target, target_name, reason, created_at) values
    (b, b, 'x', 1, now() - interval '7 months'), (b, b, 'x', 1, now() - interval '1 month');
  insert into public.weekly_scores (week, user_id, score) values ('2001-W01', b, 5),
    (to_char(now() at time zone 'utc', 'IYYY-"W"IW'), b, 7)
  on conflict do nothing;
  insert into auth.audit_log_entries (ip_address, created_at) values ('1.2.3.4', now() - interval '8 days'),
    ('1.2.3.5', now());

  r := public._daily_cleanup();
  assert (r->>'mail')::int >= 1 and (select count(*) from public.mail where recipient = b) = 1, 'old mail gone: ' || r::text;
  assert (select count(*) from public.reports where target = b) = 1, 'reports older than 6 months gone';
  assert not exists (select 1 from public.weekly_scores where week = '2001-W01'), 'old weekly values gone';
  assert exists (select 1 from public.weekly_scores where user_id = b), 'this week stays';
  assert (select count(*) from auth.audit_log_entries) = 1, 'audit log (IP addresses) after 7 days';
  -- First run only marks the inactive accounts.
  assert (select inactive_since is not null from public.profiles where id = a), 'inactive marked';
  assert (select inactive_since is null from public.profiles where id = b), 'active not marked';
  assert exists (select 1 from auth.users where id = a), 'not deleted on the first run';

  -- 31 days later: c came back meanwhile, a did not.
  update public.profiles set inactive_since = now() - interval '31 days' where id in (a, c);
  update public.profiles set last_seen = now() where id = c;
  r := public._daily_cleanup();
  assert not exists (select 1 from auth.users where id = a), 'inactive account deleted: ' || r::text;
  assert not exists (select 1 from public.profiles where id = a), 'its profile too (cascade)';
  assert exists (select 1 from auth.users where id = c), 'player who came back keeps the account';
  assert (select inactive_since is null from public.profiles where id = c), 'mark cleared';
  assert exists (select 1 from auth.users where id = b);
end $$;

set role authenticated;
do $$ begin
  begin
    perform public._daily_cleanup();
    raise exception 'players must not run the cleanup';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
