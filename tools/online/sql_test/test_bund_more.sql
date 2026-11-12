-- Online 100, area 4: bund level, donations, week goal, board, search, open join.
-- The same cases as tests/unit/test_bund_more.gd.
insert into auth.users (id) values
  ('54000000-0000-0000-0000-00000000000a'), ('54000000-0000-0000-0000-00000000000b'),
  ('54000000-0000-0000-0000-00000000000c')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '54000000-0000-0000-0000-00000000000' || u, false)
$$;
create temp table bm (k text primary key, v text);
grant all on bm to authenticated;
begin;
delete from public.bunds;
update public.feature_flags set enabled = true where key = 'bund';
update public.server_config set value = jsonb_set(value, '{goal_target}', '5') where key = 'bund_rules';
insert into public.saves (user_id, slot, rev, data) values
  ('54000000-0000-0000-0000-00000000000a', 1, 1, '{"inventory": {"tonic": 30}, "party": [], "storage": []}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;
set role authenticated;
select pg_temp.as_user('b');
select public.hello(1);
select pg_temp.as_user('c');
select public.hello(1);
select pg_temp.as_user('a');
select public.hello(1);
do $$
declare r jsonb;
begin
  assert public.bund_stats()->>'error' = 'no_bund';
  insert into bm values ('bund', public.bund_create(3, 7)->>'bund');
  r := public.bund_stats();
  assert (r->>'level')::int = 1 and (r->>'xp')::int = 0 and not (r->>'open')::boolean, r::text;
  assert public.bund_settings('xx', true)->>'error' = 'bad_lang';
  assert (public.bund_settings('de', false)->>'ok')::boolean;
  assert public.bund_donate(1, 1, 'tonic', 21)->>'error' = 'limit_today';
  assert public.bund_donate(1, 1, 'remedy', 1)->>'error' = 'not_enough';
  assert public.bund_goal_claim(1, 1)->>'error' = 'goal_open';
  r := public.bund_donate(1, 1, 'tonic', 20);
  assert (r->>'xp')::int = 200 and (r->>'goal')::int = 20 and (r->>'rev')::int = 2, r::text;
  assert public.bund_donate(1, 2, 'tonic', 1)->>'error' = 'limit_today';
  r := public.bund_goal_claim(1, 2);
  assert (r->>'ok')::boolean and r->>'item' = 'strong_tonic', r::text;
  assert public.bund_goal_claim(1, (r->>'rev')::int)->>'error' = 'claimed';
  assert (public.bund_board()->'rows'->0->>'mine')::boolean;
end $$;
reset role;
do $$ begin
  assert (select data->'inventory'->>'tonic' from public.saves where user_id = '54000000-0000-0000-0000-00000000000a') = '10';
  assert public._bund_level(499) = 1 and public._bund_level(500) = 2 and public._bund_level(99999) = 20;
end $$;
set role authenticated;
select pg_temp.as_user('b');
do $$
declare r jsonb; b bigint := (select v::bigint from bm where k = 'bund');
begin
  r := public.bund_search('de');
  assert r->'bunds'->0->>'bund' = b::text and (r->'bunds'->0->>'size')::int = 1, r::text;
  assert jsonb_array_length(public.bund_search('en')->'bunds') = 0;
  r := public.bund_join(b);
  assert (r->>'ok')::boolean and not (r->>'joined')::boolean, 'closed: a request';
end $$;
select pg_temp.as_user('a');
select public.bund_settings('de', true);
select pg_temp.as_user('c');
do $$ begin
  assert (public.bund_join((select v::bigint from bm where k = 'bund'))->>'joined')::boolean, 'open: joined at once';
  assert public.bund_join((select v::bigint from bm where k = 'bund'))->>'error' = 'in_bund';
end $$;
reset role;
rollback;
