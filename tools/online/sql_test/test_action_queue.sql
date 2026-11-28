-- Plan area 7, item 3011: a small action sent twice with the same id counts once.
\o /dev/null
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000c1'), ('20000000-0000-0000-0000-0000000000c2')
on conflict do nothing;
create temp table aq (k text primary key, v jsonb);
grant all on aq to authenticated;
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000c1', false);
insert into aq values ('c1', public.hello(1)->'profile');
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000c2', false);
insert into aq values ('c2', public.hello(1)->'profile');
select public.friend_request((select v->>'code' from aq where k = 'c1'));
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000c1', false);
select public.friend_respond((select v->>'code' from aq where k = 'c2'), true);
insert into aq values ('wave1', public.action_once('aaaa1111bbbb2222', 'mail_send',
  jsonb_build_object('p_code', (select v->>'code' from aq where k = 'c2'), 'p_kind', 'wave', 'p_phrase', 0)));
insert into aq values ('wave2', public.action_once('aaaa1111bbbb2222', 'mail_send',
  jsonb_build_object('p_code', (select v->>'code' from aq where k = 'c2'), 'p_kind', 'wave', 'p_phrase', 0)));
insert into aq values ('goal0', public.community_get());
insert into aq values ('goal1', public.action_once('cccc3333dddd4444', 'community_add',
  jsonb_build_object('p_kind', (select v->>'kind' from aq where k = 'goal0'), 'p_amount', 2)));
insert into aq values ('goal2', public.action_once('cccc3333dddd4444', 'community_add',
  jsonb_build_object('p_kind', (select v->>'kind' from aq where k = 'goal0'), 'p_amount', 2)));
insert into aq values ('gift', public.action_once('eeee5555ffff6666', 'gift_send', '{}'));
insert into aq values ('short', public.action_once('abc', 'community_add', '{}'));
reset role;
\o
do $$
begin
  assert ((select v from aq where k = 'wave1')->>'ok')::boolean, 'the wave goes out';
  assert ((select v from aq where k = 'wave2')->>'repeat')::boolean, 'the same id again is a repeat';
  assert (select count(*) from public.mail where kind = 'wave'
    and sender = '20000000-0000-0000-0000-0000000000c1') = 1, 'one wave arrives';
  assert (select amount from public.community_contrib where user_id = '20000000-0000-0000-0000-0000000000c1') = 2,
    'the world goal counts once';
  assert ((select v from aq where k = 'goal2')->>'repeat')::boolean, 'goal repeat';
  assert (select v->>'error' from aq where k = 'gift') = 'bad_action', 'only small actions';
  assert (select v->>'error' from aq where k = 'short') = 'bad_id', 'an id is needed';
end $$;
