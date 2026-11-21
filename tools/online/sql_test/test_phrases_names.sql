-- Plan area 7, items 2876-2878: phrases per context, names without phone numbers or addresses.
do $$
begin
  assert public._clean_name('Mara 123', 'ABCDEFGH') = 'Mara 123', 'up to 3 digits';
  assert public._clean_name('Mara 1234', 'ABCDEFGH') = 'Wanderer EFGH', '4 digits';
  assert public._clean_name('0 1 7 2 9', 'ABCDEFGH') = 'Wanderer EFGH', 'digits with spaces';
  assert public._clean_name('wwwmara', 'ABCDEFGH') = 'Wanderer EFGH', 'web address';
  assert public._clean_name('Http Ann', 'ABCDEFGH') = 'Wanderer EFGH', 'web address';
  assert public._clean_name('mara@x', 'ABCDEFGH') = 'Wanderer EFGH', 'no @';
  assert public._clean_name('Wendy', 'ABCDEFGH') = 'Wendy', 'normal name';
  assert public._phrase_ok('post', 15) and not public._phrase_ok('post', 16), 'post list';
  assert public._phrase_ok('duel', 12) and not public._phrase_ok('duel', 8), 'no gift phrase in a duel';
  assert not public._phrase_ok('nowhere', 0), 'unknown context';
  assert not public._phrase_ok('post', null), 'no number';
end $$;

insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000e1'), ('20000000-0000-0000-0000-0000000000e2')
on conflict do nothing;
create temp table pn (k text primary key, v jsonb);
grant all on pn to authenticated;
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000e1', false);
insert into pn values ('e1', public.hello(1)->'profile');
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000e2', false);
insert into pn values ('e2', public.hello(1)->'profile');
select public.friend_request((select v->>'code' from pn where k = 'e1'));
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000e1', false);
select public.friend_respond((select v->>'code' from pn where k = 'e2'), true);
insert into pn values ('ok', public.mail_send((select v->>'code' from pn where k = 'e2'), 'phrase', 3));
insert into pn values ('bad', public.mail_send((select v->>'code' from pn where k = 'e2'), 'phrase', 20));
reset role;
do $$
begin
  assert ((select v from pn where k = 'ok')->>'ok')::boolean, 'a post phrase';
  assert (select v->>'error' from pn where k = 'bad') = 'bad_phrase', 'not on the post list';
end $$;
