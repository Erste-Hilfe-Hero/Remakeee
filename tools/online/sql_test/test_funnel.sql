-- New-player funnel (20261121079000_funnel_view.sql): counts per sign-up day on fixtures, and
-- players cannot call it. Sign-up days in 2020 so the accounts of the other tests are not counted.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-000000007901'), ('20000000-0000-0000-0000-000000007902'),
  ('20000000-0000-0000-0000-000000007903'), ('20000000-0000-0000-0000-000000007904'),
  ('20000000-0000-0000-0000-000000007905'), ('20000000-0000-0000-0000-000000007906'),
  ('20000000-0000-0000-0000-000000007907')
on conflict do nothing;
insert into public.profiles (id, code, created_at, last_seen) values
  -- 01: no save, never came back.
  ('20000000-0000-0000-0000-000000007901', 'FNTA2345', '2020-03-01 10:00+00', '2020-03-01 10:05+00'),
  ('20000000-0000-0000-0000-000000007902', 'FNTB2345', '2020-03-01 10:00+00', '2020-03-03 10:00+00'),
  ('20000000-0000-0000-0000-000000007903', 'FNTC2345', '2020-03-01 10:00+00', '2020-03-09 10:00+00'),
  -- 04: still playing.
  ('20000000-0000-0000-0000-000000007904', 'FNTD2345', '2020-03-01 10:00+00', now()),
  ('20000000-0000-0000-0000-000000007905', 'FNTE2345', '2020-03-01 23:59+00', '2020-03-02 00:30+00'),
  ('20000000-0000-0000-0000-000000007906', 'FNTF2345', '2020-03-02 23:30+00', now()),
  -- 07: after p_to, not counted.
  ('20000000-0000-0000-0000-000000007907', 'FNTG2345', '2020-03-04 00:00+00', now())
on conflict (id) do update set created_at = excluded.created_at, last_seen = excluded.last_seen;
insert into public.saves (user_id, slot, rev, data, saved_at) values
  ('20000000-0000-0000-0000-000000007902', 1, 1, '{"map": "lighthouse", "play_time": 600,
    "flags": {"got_starter": true, "aldo_gift": true}, "records": {"warden_losses": {"beaten_cinder_rift_orrin": 2}}}', '2020-03-01 11:00+00'),
  ('20000000-0000-0000-0000-000000007903', 1, 1, '{"map": "brindlewick", "play_time": 1200,
    "flags": {"got_starter": true, "aldo_gift": true, "met_kestra": true}, "records": {"difficulty_lowered": true}}', '2020-03-05 11:00+00'),
  -- An older second slot: its flag counts, its map and play time do not.
  ('20000000-0000-0000-0000-000000007903', 2, 1, '{"map": "lighthouse", "play_time": 50,
    "flags": {"beat_story_rival_jinks_1": true}}', '2020-03-02 11:00+00'),
  ('20000000-0000-0000-0000-000000007904', 1, 1, '{"map": "ashmere", "play_time": 3600, "flags": {"got_starter": true,
    "aldo_gift": true, "met_kestra": true, "beat_story_rival_jinks_1": true, "kestra_spar": true, "rift_cinder_sealed": true,
    "rift_tide_sealed": true, "aldo_dock_told": true}, "records": {"warden_losses": {"x": 1}}}', '2020-03-08 11:00+00'),
  -- 05: a false flag and a zero loss count are not counted.
  ('20000000-0000-0000-0000-000000007905', 1, 1, '{"map": "lighthouse", "play_time": 300,
    "flags": {"got_starter": false}, "records": {"warden_losses": {"x": 0}, "difficulty_lowered": false}}', '2020-03-01 23:59+00'),
  ('20000000-0000-0000-0000-000000007906', 1, 1, '{"map": "lighthouse", "play_time": 60, "flags": {"got_starter": true}}', '2020-03-03 00:00+00'),
  ('20000000-0000-0000-0000-000000007907', 1, 1, '{"map": "lighthouse", "flags": {"got_starter": true}}', '2020-03-04 00:00+00')
on conflict (user_id, slot) do update set data = excluded.data, saved_at = excluded.saved_at;

create temp table fn as select * from public.admin_funnel('2020-03-01', '2020-03-03');

do $$
declare r record;
begin
  assert (select count(*) from fn) = 3, 'one row per day, also empty days';
  select * into r from fn where day = '2020-03-01';
  assert r.accounts = 5 and r.with_save = 4, format('accounts %s, with save %s', r.accounts, r.with_save);
  assert (r.got_starter, r.aldo_gift, r.met_kestra, r.beat_story_rival_jinks_1, r.kestra_spar, r.rift_cinder_sealed,
    r.rift_tide_sealed, r.aldo_dock_told) = (3::bigint, 3::bigint, 2::bigint, 2::bigint, 1::bigint, 1::bigint, 1::bigint, 1::bigint),
    format('steps %s', row_to_json(r));
  assert r.back_1d = 3 and r.back_7d = 2, format('back %s %s', r.back_1d, r.back_7d);
  assert r.stopped = 4, format('stopped %s', r.stopped);
  assert r.stopped_median_play_min = 10.0, format('median %s', r.stopped_median_play_min);
  assert r.stopped_top_map = 'lighthouse', format('map %s', r.stopped_top_map);
  assert r.stopped_warden_loss_pct = 33.3 and r.stopped_lowered_pct = 33.3,
    format('shares %s %s', r.stopped_warden_loss_pct, r.stopped_lowered_pct);
  select * into r from fn where day = '2020-03-02';
  assert r.accounts = 1 and r.with_save = 1 and r.got_starter = 1 and r.stopped = 0 and r.back_7d = 1, format('day 2 %s', row_to_json(r));
  assert r.stopped_median_play_min is null and r.stopped_warden_loss_pct is null, 'no stopped players, no values';
  select * into r from fn where day = '2020-03-03';
  assert r.accounts = 0 and r.with_save = 0 and r.got_starter = 0, 'empty day';
  -- Only counts and map ids come out: no column holds an id, code or name.
  assert not exists (select 1 from fn f, jsonb_each_text(to_jsonb(f)) c
    where c.value like '20000000-%' or c.value like 'FNT%' or c.value = 'Tamer'), 'no account data in the output';
  assert has_function_privilege('service_role', 'public.admin_funnel(date, date, int)', 'execute'), 'admin can call it';
  assert not has_function_privilege('anon', 'public.admin_funnel(date, date, int)', 'execute'), 'anon cannot';
  assert not has_function_privilege('authenticated', 'public.admin_funnel(date, date, int)', 'execute'), 'players cannot';
end $$;

-- A signed-in player gets "permission denied".
set role authenticated;
do $$ begin perform set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000007904', false); end $$;
do $$
begin
  perform public.admin_funnel('2020-03-01', '2020-03-03');
  raise exception 'a player could call admin_funnel';
exception when insufficient_privilege then
  null;
end $$;
reset role;
set role anon;
do $$
begin
  perform public.admin_funnel('2020-03-01', '2020-03-03');
  raise exception 'anon could call admin_funnel';
exception when insufficient_privilege then
  null;
end $$;
reset role;
do $$ begin perform set_config('request.jwt.claim.sub', '', false); end $$;

delete from auth.users where id::text like '20000000-0000-0000-0000-0000000079%';
delete from public.profiles where id::text like '20000000-0000-0000-0000-0000000079%';
