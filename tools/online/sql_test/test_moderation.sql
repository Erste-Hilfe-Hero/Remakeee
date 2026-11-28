-- Plan area 7, items 2895-2898, 2916: a report gets a number, the decision reaches both sides,
-- an appeal works once and only within 6 months, and players cannot decide anything themselves.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000e1'), ('20000000-0000-0000-0000-0000000000e2')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;
create temp table mcodes (who text primary key, code text);
grant all on mcodes to authenticated;
create temp table mres (k text primary key, v jsonb);
grant all on mres to authenticated;

set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000e1');
insert into mcodes values ('a', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('20000000-0000-0000-0000-0000000000e2');
insert into mcodes values ('b', public.hello(1)->'profile'->>'code');
insert into mres values ('r1', public.report_in((select code from mcodes where who = 'a'), 0, 'card', 'card'));
insert into mres values ('r2', public.report((select code from mcodes where who = 'a'), 1));
insert into mres values ('bad', public.report_in((select code from mcodes where who = 'a'), 0, 'chat', null));
reset role;

do $$
declare
  r1 jsonb := (select v from mres where k = 'r1');
begin
  assert (r1->>'ok')::boolean and (r1->>'report_id')::bigint > 0, 'report gets a number: ' || r1::text;
  assert (select v->>'error' from mres where k = 'bad') = 'bad_context', 'unknown place refused';
  assert (select context from public.reports where id = (r1->>'report_id')::bigint) = 'card', 'place kept';
  assert (select status from public.reports where id = (r1->>'report_id')::bigint) = 'open', 'open at first';
end $$;

-- Players cannot decide.
set role authenticated;
do $$ begin
  begin
    perform public.moderation_decide(1, true, 'warning');
    assert false, 'player could decide';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Ali upholds the first (name reset) and rejects the second.
select public.moderation_decide((select (v->>'report_id')::bigint from mres where k = 'r1'), true, 'name_reset');
select public.moderation_decide((select (v->>'report_id')::bigint from mres where k = 'r2'), false, null);
do $$
declare
  r1 bigint := (select (v->>'report_id')::bigint from mres where k = 'r1');
  n public.notices;
begin
  assert (public.moderation_decide(r1, false, null)->>'error') = 'decided', 'decided once';
  assert (select name from public.profiles where id = '20000000-0000-0000-0000-0000000000e1') like 'Wanderer %', 'name reset';
  select * into n from public.notices where user_id = '20000000-0000-0000-0000-0000000000e1' and kind = 'decision';
  assert n.body->>'action' = 'name_reset' and n.body->>'rule' = '4' and n.body ? 'appeal_until', 'statement of reasons';
  assert (select count(*) from public.notices where user_id = '20000000-0000-0000-0000-0000000000e1') = 1, 'no notice for a rejected report';
  assert (select count(*) from public.notices where user_id = '20000000-0000-0000-0000-0000000000e2' and kind = 'report_result') = 2,
    'reporter hears both outcomes';
end $$;

-- The reported player reads the notice and appeals once.
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000e1');
insert into mres values ('list', public.notices_list());
insert into mres values ('ap1', public.appeal(((select v from mres where k = 'list')->'notices'->0->>'id')::bigint, 0));
insert into mres values ('ap2', public.appeal(((select v from mres where k = 'list')->'notices'->0->>'id')::bigint, 0));
select pg_temp.as_user('20000000-0000-0000-0000-0000000000e2');
insert into mres values ('other', public.appeal(((select v from mres where k = 'list')->'notices'->0->>'id')::bigint, 0));
reset role;
do $$ begin
  assert jsonb_array_length((select v from mres where k = 'list')->'notices') = 1, 'own notices only';
  assert ((select v from mres where k = 'ap1')->>'ok')::boolean, 'appeal works';
  assert (select v->>'error' from mres where k = 'ap2') = 'appealed', 'once per decision';
  assert (select v->>'error' from mres where k = 'other') = 'no_such_notice', 'not for others';
end $$;

select public.appeal_answer((select (v->>'appeal_id')::bigint from mres where k = 'ap1'), false);
do $$ begin
  assert (select status from public.appeals where user_id = '20000000-0000-0000-0000-0000000000e1') = 'kept', 'answered';
  assert exists (select 1 from public.notices where user_id = '20000000-0000-0000-0000-0000000000e1' and kind = 'appeal_answer'),
    'answer reaches the player';
end $$;

-- League block and lifting it on appeal; old decisions cannot be appealed.
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000e2');
delete from mres where k = 'r3';
insert into mres values ('r3', public.report_in((select code from mcodes where who = 'a'), 2, 'league', null));
reset role;
select public.moderation_decide((select (v->>'report_id')::bigint from mres where k = 'r3'), true, 'league_block');
do $$
declare
  nid bigint := (select id from public.notices where user_id = '20000000-0000-0000-0000-0000000000e1'
    and kind = 'decision' and body->>'action' = 'league_block');
  aid bigint;
begin
  assert public._cheat_held('20000000-0000-0000-0000-0000000000e1'), 'league blocked';
  insert into public.appeals (notice_id, user_id, reason) values (nid, '20000000-0000-0000-0000-0000000000e1', 0) returning id into aid;
  perform public.appeal_answer(aid, true);
  assert not public._cheat_held('20000000-0000-0000-0000-0000000000e1'), 'block lifted';
  update public.notices set created_at = now() - interval '7 months' where id = nid;
  delete from public.appeals where id = aid;
end $$;
insert into mres select 'nid', to_jsonb(id) from public.notices where kind = 'decision' and body->>'action' = 'league_block';
set role authenticated;
select pg_temp.as_user('20000000-0000-0000-0000-0000000000e1');
insert into mres values ('late', public.appeal((select v::text::bigint from mres where k = 'nid'), 0));
reset role;
do $$ begin
  assert (select v->>'error' from mres where k = 'late') = 'too_late', 'six months';
end $$;

delete from auth.users where id in ('20000000-0000-0000-0000-0000000000e1', '20000000-0000-0000-0000-0000000000e2');
