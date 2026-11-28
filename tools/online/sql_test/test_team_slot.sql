-- Shop (area 10): the bought sixth team slot lets saves hold a team of 6, nobody else.
-- test_rules.sql replays the older online_rules migration, so load this one again first.
\ir ../../../supabase/migrations/20261110000023_shop_team_slot.sql
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000c6') on conflict do nothing;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000c6', false);
do $$ begin
  assert public._party_max('20000000-0000-0000-0000-0000000000c6') = 5;
  assert not public._save_ok('{"party": [{},{},{},{},{},{}]}'), 'six without the slot';
  assert public._party_max(null) = 5;
end $$;
insert into public.entitlements (user_id, key) values ('20000000-0000-0000-0000-0000000000c6', 'team_slot_6');
do $$ begin
  assert public._party_max('20000000-0000-0000-0000-0000000000c6') = 6;
  assert public._save_ok('{"party": [{},{},{},{},{},{}]}'), 'six with the slot';
  assert not public._save_ok('{"party": [{},{},{},{},{},{},{}]}'), 'never seven';
end $$;
select set_config('request.jwt.claim.sub', '', false);
