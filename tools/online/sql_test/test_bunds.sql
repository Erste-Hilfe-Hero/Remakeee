-- Plan area 7, items 2817-2821, 2842, 2900: bunds with invites, requests, roles, leaving and dissolving.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000b1'), ('20000000-0000-0000-0000-0000000000b2'),
  ('20000000-0000-0000-0000-0000000000b3'), ('20000000-0000-0000-0000-0000000000b4')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000' || u, false)
$$;
create temp table bc (who text primary key, code text);
create temp table br (k text primary key, v jsonb);
grant all on bc, br to authenticated;

set role authenticated;
select pg_temp.as_user('b1');
insert into bc values ('b1', public.hello(1)->'profile'->>'code');
insert into br values ('off', public.bund_create(1, 2));
select pg_temp.as_user('b2');
insert into bc values ('b2', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('b3');
insert into bc values ('b3', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('b4');
insert into bc values ('b4', public.hello(1)->'profile'->>'code');
reset role;
update public.feature_flags set enabled = true where key = 'bund';

set role authenticated;
select pg_temp.as_user('b1');
insert into br values ('badname', public.bund_create(1, 500));
insert into br values ('create', public.bund_create(3, 7));
insert into br values ('twice', public.bund_create(1, 2));
insert into br values ('inv2', public.bund_invite((select code from bc where who = 'b2')));
-- b4 blocked b1: no invite and no request (2900).
select pg_temp.as_user('b4');
select public.block((select code from bc where who = 'b1'));
insert into br values ('req4', public.bund_request((select code from bc where who = 'b1')));
select pg_temp.as_user('b1');
insert into br values ('inv4', public.bund_invite((select code from bc where who = 'b4')));
-- b2 accepts the invite; b3 asks through b2 and b2 (only a member) cannot admit.
select pg_temp.as_user('b2');
insert into br values ('info2', public.bund_info());
insert into br values ('ans2', public.bund_answer(((select v from br where k = 'info2')->'invites'->0->>'bund')::bigint, true));
select pg_temp.as_user('b3');
insert into br values ('req3', public.bund_request((select code from bc where who = 'b2')));
select pg_temp.as_user('b2');
insert into br values ('adm_member', public.bund_admit((select code from bc where who = 'b3'), true));
select pg_temp.as_user('b1');
insert into br values ('role2', public.bund_role((select code from bc where who = 'b2'), 'helper'));
select pg_temp.as_user('b2');
insert into br values ('adm_helper', public.bund_admit((select code from bc where who = 'b3'), true));
insert into br values ('kick_leader', public.bund_kick((select code from bc where who = 'b1')));
insert into br values ('info', public.bund_info());
-- Dissolving with 3 members needs a second yes after 24 hours (2842).
select pg_temp.as_user('b2');
insert into br values ('dis_helper', public.bund_dissolve());
select pg_temp.as_user('b1');
insert into br values ('dis1', public.bund_dissolve());
insert into br values ('dis2', public.bund_dissolve());
reset role;

do $$
declare
  info jsonb := (select v->'bund' from br where k = 'info');
begin
  assert (select v->>'error' from br where k = 'off') = 'feature_off', 'flag off';
  assert (select v->>'error' from br where k = 'badname') = 'bad_name', 'word numbers only';
  assert ((select v from br where k = 'create')->>'ok')::boolean, 'created';
  assert (select v->>'error' from br where k = 'twice') = 'in_bund', 'one bund per player';
  assert (select v->>'error' from br where k = 'req4') = 'no_such_bund', 'blocked: no request';
  assert (select v->>'error' from br where k = 'inv4') = 'no_such_code', 'blocked: no invite';
  assert ((select v from br where k = 'ans2')->>'joined')::boolean, 'invite accepted';
  assert (select v->>'error' from br where k = 'adm_member') = 'not_allowed', 'members cannot admit';
  assert ((select v from br where k = 'adm_helper')->>'joined')::boolean, 'helper admits';
  assert (select v->>'error' from br where k = 'kick_leader') = 'not_allowed', 'helper cannot remove the leader';
  assert jsonb_array_length(info->'members') = 3, 'three members';
  assert info->'members'->0->>'role' = 'leader', 'leader first';
  assert info->'name' = '[3, 7]'::jsonb, 'name as two numbers';
  assert (select v->>'error' from br where k = 'dis_helper') = 'not_allowed', 'only the leader dissolves';
  assert not ((select v from br where k = 'dis1')->>'dissolved')::boolean, 'first yes waits';
  assert not ((select v from br where k = 'dis2')->>'dissolved')::boolean, 'still waiting';
end $$;

update public.bunds set dissolve_at = now() - interval '1 minute';
set role authenticated;
select pg_temp.as_user('b1');
insert into br values ('dis3', public.bund_dissolve());
reset role;
do $$ begin
  assert ((select v from br where k = 'dis3')->>'dissolved')::boolean, 'dissolved after 24 hours';
  assert not exists (select 1 from public.bund_members where user_id in
    ('20000000-0000-0000-0000-0000000000b1', '20000000-0000-0000-0000-0000000000b2', '20000000-0000-0000-0000-0000000000b3')),
    'members are free again';
end $$;

-- Leaving: always possible; the leader leaving hands over, the last one closes the bund.
set role authenticated;
select pg_temp.as_user('b1');
select public.bund_create(5, 5);
select public.bund_invite((select code from bc where who = 'b3'));
select pg_temp.as_user('b3');
insert into br values ('info3a', public.bund_info());
select public.bund_answer(((select v from br where k = 'info3a')->'invites'->0->>'bund')::bigint, true);
set role authenticated;
select pg_temp.as_user('b1');
insert into br values ('leave1', public.bund_leave());
select pg_temp.as_user('b3');
insert into br values ('info3', public.bund_info());
insert into br values ('leave3', public.bund_leave());
reset role;
do $$ begin
  assert ((select v from br where k = 'leave1')->>'ok')::boolean, 'leader may leave';
  assert (select v->'bund'->>'role' from br where k = 'info3') = 'leader', 'the next member leads';
  assert not exists (select 1 from public.bunds where name_a = 5 and name_b = 5), 'empty bund removed';
end $$;

update public.feature_flags set enabled = false where key = 'bund';
delete from auth.users where id::text like '20000000-0000-0000-0000-0000000000b_';
