-- First minutes of a journey (20261128160000_funnel_start.sql): counts and medians per sign-up
-- day on fixtures, nothing else comes out, and players cannot call it. Sign-up days in 2020-04.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-000000007951'), ('20000000-0000-0000-0000-000000007952'),
  ('20000000-0000-0000-0000-000000007953'), ('20000000-0000-0000-0000-000000007954')
on conflict do nothing;
insert into public.profiles (id, code, created_at, last_seen) values
  ('20000000-0000-0000-0000-000000007951', 'FSTA2345', '2020-04-01 10:00+00', '2020-04-01 10:05+00'),
  ('20000000-0000-0000-0000-000000007952', 'FSTB2345', '2020-04-01 11:00+00', '2020-04-01 11:30+00'),
  -- 53: an old journey without a funnel record.
  ('20000000-0000-0000-0000-000000007953', 'FSTC2345', '2020-04-01 12:00+00', '2020-04-02 12:00+00'),
  ('20000000-0000-0000-0000-000000007954', 'FSTD2345', '2020-04-02 09:00+00', '2020-04-02 09:10+00')
on conflict (id) do update set created_at = excluded.created_at, last_seen = excluded.last_seen;
insert into public.saves (user_id, slot, rev, data, saved_at) values
  ('20000000-0000-0000-0000-000000007951', 1, 1, '{"map": "fernstair", "records": {"funnel":
    {"new_game": 0, "first_control": 1, "first_wild": 3, "first_catch": 20, "first_save": 41}}}', '2020-04-01 10:05+00'),
  ('20000000-0000-0000-0000-000000007952', 1, 1, '{"map": "brindlewick", "records": {"funnel":
    {"new_game": 0, "first_control": 2, "first_wild": 5, "first_catch": 30, "first_save": 55, "story_start": 70}}}', '2020-04-01 11:30+00'),
  -- A second slot of 52 that only reached control; a step that is not a number does not count.
  ('20000000-0000-0000-0000-000000007952', 2, 1, '{"records": {"funnel": {"new_game": 0, "first_control": 4, "first_wild": "x"}}}', '2020-04-01 11:40+00'),
  ('20000000-0000-0000-0000-000000007953', 1, 1, '{"map": "ashmere", "records": {"warden_losses": {}}}', '2020-04-02 12:00+00')
on conflict (user_id, slot) do update set data = excluded.data, saved_at = excluded.saved_at;

create temp table fs as select * from public.admin_funnel_start('2020-04-01', '2020-04-03');

do $$
declare r record;
begin
  assert (select count(*) from fs) = 3, 'one row per day, also empty days';
  select * into r from fs where day = '2020-04-01';
  assert r.accounts = 3 and r.journeys = 3, format('accounts %s, journeys %s', r.accounts, r.journeys);
  assert (r.first_control, r.first_wild, r.first_catch, r.story_start, r.first_save)
    = (3::bigint, 2::bigint, 2::bigint, 1::bigint, 2::bigint), format('steps %s', row_to_json(r));
  assert r.first_control_median_s = 2.0 and r.first_wild_median_s = 4.0 and r.first_catch_median_s = 25.0
    and r.story_start_median_s = 70.0 and r.first_save_median_s = 48.0, format('medians %s', row_to_json(r));
  select * into r from fs where day = '2020-04-02';
  assert r.accounts = 1 and r.journeys = 0 and r.first_control = 0 and r.first_control_median_s is null,
    format('day 2 %s', row_to_json(r));
  -- Only counts and seconds come out: no column holds an id, code or name.
  assert not exists (select 1 from fs f, jsonb_each_text(to_jsonb(f)) c
    where c.value like '20000000-%' or c.value like 'FST%'), 'no account data in the output';
  assert has_function_privilege('service_role', 'public.admin_funnel_start(date, date)', 'execute'), 'admin can call it';
  assert not has_function_privilege('anon', 'public.admin_funnel_start(date, date)', 'execute'), 'anon cannot';
  assert not has_function_privilege('authenticated', 'public.admin_funnel_start(date, date)', 'execute'), 'players cannot';
end $$;

set role authenticated;
do $$ begin perform set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000007952', false); end $$;
do $$
begin
  perform public.admin_funnel_start('2020-04-01', '2020-04-03');
  raise exception 'a player could call admin_funnel_start';
exception when insufficient_privilege then
  null;
end $$;
reset role;
do $$ begin perform set_config('request.jwt.claim.sub', '', false); end $$;

delete from auth.users where id::text like '20000000-0000-0000-0000-00000000795%';
delete from public.profiles where id::text like '20000000-0000-0000-0000-00000000795%';
