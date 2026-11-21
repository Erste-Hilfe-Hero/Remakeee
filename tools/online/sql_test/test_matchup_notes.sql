-- KAMPF_PLAN_1000 item 107: matchup notes by Lantern Mail. The same cases as
-- tests/unit/test_kampf_k26.gd (LocalMatchupNotes).
insert into auth.users (id) values
  ('20000000-0000-0000-0000-00000000006a'), ('20000000-0000-0000-0000-00000000006b'),
  ('20000000-0000-0000-0000-00000000006c')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000' || u, false)
$$;
create temp table gc (who text primary key, code text);
create temp table gr (k text primary key, v jsonb);
grant all on gc, gr to authenticated;

set role authenticated;
select pg_temp.as_user('6a');
insert into gc values ('6a', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('6b');
insert into gc values ('6b', public.hello(1)->'profile'->>'code');
select public.friend_request((select code from gc where who = '6a'));
select pg_temp.as_user('6c');
insert into gc values ('6c', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('6a');
select public.friend_respond((select code from gc where who = '6b'), true);
insert into gr values ('stranger', public.notes_send((select code from gc where who = '6c'), '{"0:Mossling": 2}'));
insert into gr values ('empty', public.notes_send((select code from gc where who = '6b'), '{}'));
insert into gr values ('bad_key', public.notes_send((select code from gc where who = '6b'), '{"x:Mossling": 2}'));
insert into gr values ('bad_mult', public.notes_send((select code from gc where who = '6b'), '{"0:Mossling": 9}'));
insert into gr values ('not_obj', public.notes_send((select code from gc where who = '6b'), '[1, 2]'));
insert into gr values ('ok', public.notes_send((select code from gc where who = '6b'), '{"0:Mossling": 2, "1:Kindlop": 2, "4:Zippit": 0.5}'));
insert into gr values ('again', public.notes_send((select code from gc where who = '6b'), '{"0:Mossling": 2}'));
select pg_temp.as_user('6b');
insert into gr values ('list', public.mail_list());
reset role;
do $$
begin
  assert (select v->>'error' from gr where k = 'stranger') = 'not_friends', 'only friends get notes';
  assert (select v->>'error' from gr where k = 'empty') = 'bad_notes', 'no empty notes';
  assert (select v->>'error' from gr where k = 'bad_key') = 'bad_notes', 'keys are element:Species';
  assert (select v->>'error' from gr where k = 'bad_mult') = 'bad_notes', 'multipliers stay between 0.25 and 4';
  assert (select v->>'error' from gr where k = 'not_obj') = 'bad_notes', 'notes are an object';
  assert (select v->>'ok' from gr where k = 'ok') = 'true', 'notes sent ' || (select v::text from gr where k = 'ok');
  assert (select v->>'error' from gr where k = 'again') = 'already_today', 'one notes mail per friend and day';
  assert (select count(*) from gr, jsonb_array_elements(v) x where k = 'list' and x->>'kind' = 'notes') = 1, 'the friend sees the mail';
  assert (select points from public.friendships where a = '20000000-0000-0000-0000-00000000006a'
    and b = '20000000-0000-0000-0000-00000000006b') >= 1, 'the pair gets the Lantern Mail bonus';
end $$;

set role authenticated;
select pg_temp.as_user('6b');
insert into gr values ('open', public.notes_open((select (x->>'id')::bigint from gr, jsonb_array_elements(v) x
  where k = 'list' and x->>'kind' = 'notes')));
select pg_temp.as_user('6c');
insert into gr values ('open_other', public.notes_open((select (x->>'id')::bigint from gr, jsonb_array_elements(v) x
  where k = 'list' and x->>'kind' = 'notes')));
reset role;
do $$
begin
  assert (select v->'notes'->>'1:Kindlop' from gr where k = 'open') = '2', 'the notes arrive ' || (select v::text from gr where k = 'open');
  assert (select v->>'error' from gr where k = 'open_other') = 'no_such_mail', 'only the recipient opens them';
  assert (select opened from public.mail where kind = 'notes' and recipient = '20000000-0000-0000-0000-00000000006b'), 'opened';
end $$;

delete from auth.users where id in ('20000000-0000-0000-0000-00000000006a', '20000000-0000-0000-0000-00000000006b',
  '20000000-0000-0000-0000-00000000006c');
