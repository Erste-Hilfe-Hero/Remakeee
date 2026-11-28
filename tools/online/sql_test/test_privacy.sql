-- Plan area 7, items 2972, 2973, 2991: data_export covers every account table, never names other
-- players, and delete_account leaves no row with the account id anywhere.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000d1'), ('20000000-0000-0000-0000-0000000000d2')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;
create temp table pcodes (who text primary key, code text);
grant all on pcodes to authenticated;
create temp table pexport (e jsonb);
grant all on pexport to authenticated;

set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000d1');
insert into pcodes values ('a', public.hello(1)->'profile'->>'code');
select public.save_put(1, '{"schema": 1, "money": 5, "play_time": 1}', 'A', 0);
select public.team_set('[{"species": "Kindlop", "level": 10, "moves": []}]');
select pg_temp.as_user('20000000-0000-0000-0000-0000000000d2');
insert into pcodes values ('b', public.hello(1)->'profile'->>'code');
select public.friend_request((select code from pcodes where who = 'a'));
select public.report((select code from pcodes where who = 'a'), 0);
select pg_temp.as_user('20000000-0000-0000-0000-0000000000d1');
select public.friend_respond((select code from pcodes where who = 'b'), true);
select public.mail_send((select code from pcodes where who = 'b'), 'greeting', 1);
select public.league_join('fair', '["Kindlop"]');
insert into pexport select public.data_export();
reset role;

do $$
declare
  e jsonb := (select e from pexport);
  t text;
begin
  assert (e->>'ok')::boolean, e::text;
  -- Every table with an account column is in the export (2991).
  for t in select tbl from public._account_tables() loop
    assert (e->'tables') ? t, 'data_export misses table ' || t;
  end loop;
  assert jsonb_array_length(e->'tables'->'saves') = 1, 'own save';
  assert jsonb_array_length(e->'tables'->'league_fair_entries') = 1, 'league row';
  assert jsonb_array_length(e->'tables'->'reports') = 1, 'reports against the account are in it';
  assert position('20000000-0000-0000-0000-0000000000d2' in e::text) = 0, 'never names another player';
  assert position('20000000-0000-0000-0000-0000000000d1' in e::text) = 0, 'own id reads "you"';
  assert e->'tables'->'reports'->0->>'reporter' = 'another player' or not (e->'tables'->'reports'->0 ? 'reporter'),
    'reporter hidden';
end $$;

-- delete_account: no row anywhere still carries the id (2973).
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000d1');
select public.delete_account();
reset role;
do $$
declare
  r record;
  c text;
  n bigint;
begin
  for r in select * from public._account_tables() loop
    foreach c in array r.cols loop
      execute format('select count(*) from public.%I where %I = $1', r.tbl, c) into n
        using '20000000-0000-0000-0000-0000000000d1'::uuid;
      assert n = 0, format('%s.%s still holds the deleted account', r.tbl, c);
    end loop;
  end loop;
  assert exists (select 1 from public.profiles where id = '20000000-0000-0000-0000-0000000000d2'), 'others stay';
end $$;
delete from auth.users where id = '20000000-0000-0000-0000-0000000000d2';

-- Retention: old battle recordings and notes go.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000d3') on conflict do nothing;
insert into public.cheat_flags (user_id, reason, at) values
  ('20000000-0000-0000-0000-0000000000d3', 'money_fast', now() - interval '200 days'),
  ('20000000-0000-0000-0000-0000000000d3', 'money_fast', now());
select public._privacy_cleanup();
do $$ begin
  assert (select count(*) from public.cheat_flags where user_id = '20000000-0000-0000-0000-0000000000d3') = 1, 'old notes removed';
end $$;
delete from auth.users where id = '20000000-0000-0000-0000-0000000000d3';
