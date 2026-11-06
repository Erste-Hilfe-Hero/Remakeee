-- Friends, blocks, reports, mail, gifts, echo teams, world goal, weekly board, account move.
insert into auth.users (id) values
  ('10000000-0000-0000-0000-00000000000a'), ('10000000-0000-0000-0000-00000000000b'),
  ('10000000-0000-0000-0000-00000000000c'), ('10000000-0000-0000-0000-00000000000d')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;
create temp table codes (who text primary key, code text);
grant all on codes to authenticated;
set role authenticated;

select pg_temp.as_user('10000000-0000-0000-0000-00000000000a');
insert into codes values ('a', public.hello(1)->'profile'->>'code');
select public.profile_set('Ann', 0, 'Kindlop', '{}');
select pg_temp.as_user('10000000-0000-0000-0000-00000000000b');
insert into codes values ('b', public.hello(1)->'profile'->>'code');
select public.profile_set('Ben', 1, 'Puddlet', '{}');
select pg_temp.as_user('10000000-0000-0000-0000-00000000000c');
insert into codes values ('c', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('10000000-0000-0000-0000-00000000000d');
insert into codes values ('d', public.hello(1)->'profile'->>'code');

-- A asks B; B sees it and accepts.
select pg_temp.as_user('10000000-0000-0000-0000-00000000000a');
do $$
declare b text := (select code from codes where who = 'b');
begin
  assert public.friend_request('ZZZZZZZZ')->>'error' = 'no_such_code';
  assert public.friend_request((select code from codes where who = 'a'))->>'error' = 'no_such_code', 'not yourself';
  assert public.friend_request(lower(left(b, 4)) || '-' || right(b, 4))->>'status' = 'pending', 'dash and case ignored';
  assert jsonb_array_length(public.friends_list()->'outgoing') = 1;
  -- Not friends yet: no mail, no gifts, no team.
  assert public.gift_send(b)->>'error' = 'not_friends';
  assert public.mail_send(b, 'phrase', 1)->>'error' = 'not_friends';
  assert public.friend_team(b)->>'error' = 'not_friends';
end $$;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000b');
do $$
declare a text := (select code from codes where who = 'a');
begin
  assert public.friends_list()->'incoming'->0->>'name' = 'Ann';
  perform public.friend_respond(a, true);
  assert public.friends_list()->'friends'->0->>'name' = 'Ann';
  assert (public.friends_list()->'friends'->0->>'level')::int = 1;
end $$;

-- Mail, gifts, gift limit, points.
select pg_temp.as_user('10000000-0000-0000-0000-00000000000a');
select public.presence('Thornridge');
do $$
declare b text := (select code from codes where who = 'b');
begin
  assert (public.mail_send(b, 'phrase', 3)->>'ok')::boolean;
  assert public.mail_send(b, 'phrase', 99)->>'error' = 'bad_phrase';
  assert public.mail_send(b, 'shout', 1)->>'error' = 'bad_kind', 'no free text kinds';
  assert (public.gift_send(b)->>'ok')::boolean;
  assert public.gift_send(b)->>'error' = 'already_today', 'one gift per friend per day';
  assert (public.friends_list()->'friends'->0->>'gift_sent')::boolean;
  assert (public.friends_list()->'friends'->0->>'points')::int = 1;
end $$;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000b');
do $$
declare m jsonb; g jsonb; r jsonb; i int;
begin
  m := public.mail_list();
  assert jsonb_array_length(m) = 2;
  select x into g from jsonb_array_elements(m) x where x->>'kind' = 'gift';
  assert g->>'place' = 'Thornridge' and g->>'name' = 'Ann' and g->>'item' = '', 'item hidden until opened';
  r := public.gift_open((g->>'id')::bigint);
  assert (r->>'ok')::boolean and r->>'item' in ('tonic','remedy','strong_tonic','spark_drop','cooling_gel','dry_towel','wake_bell','power_brew','guard_brew','focus_brew','dash_brew','revival_leaf');
  assert (public.gift_open((g->>'id')::bigint)->>'again')::boolean, 'opening twice gives nothing new';
  assert public.gift_open(999999)->>'error' = 'no_such_gift';
end $$;
-- The open limit per day.
reset role;
insert into public.mail (sender, recipient, kind)
  select '10000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-00000000000b', 'gift' from generate_series(1, 12);
set role authenticated;
do $$
declare g jsonb; opened int := 0; last jsonb;
begin
  for g in select x from jsonb_array_elements(public.mail_list()) x where x->>'kind' = 'gift' and not (x->>'opened')::boolean loop
    last := public.gift_open((g->>'id')::bigint);
    if (last->>'ok')::boolean then opened := opened + 1; end if;
  end loop;
  assert opened = 9, 'ten opens per day in all, got ' || (opened + 1);
  assert last->>'error' = 'limit_today';
end $$;

-- Echo teams: cleaned, only for friends; echo report gives points once a day.
select pg_temp.as_user('10000000-0000-0000-0000-00000000000b');
do $$
declare t jsonb; a text := (select code from codes where who = 'a');
begin
  t := public.team_set('[{"species":"Puddlet","level":250,"moves":["Brine Jet","<b>x</b>","a","b","c"],"nickname":"Bad Word"},{},{},{},{},{},{"species":"Seventh"}]');
  assert (t->>'size')::int = 5, 'team limited to 5';
  assert (public.echo_report(a, 'echo', true)->>'points')::int = 3;
  assert (public.echo_report(a, 'echo', true)->>'points')::int = 0, 'once per day';
  assert (public.echo_report(a, 'duel', false)->>'points')::int = 2;
  assert public.echo_report(a, 'trade', true)->>'error' = 'bad_kind';
end $$;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000a');
do $$
declare t jsonb := public.friend_team((select code from codes where who = 'b'));
begin
  assert t->>'name' = 'Ben';
  assert (t->'team'->0->>'level')::int = 60, 'level clamped to Ring 60';
  assert jsonb_array_length(t->'team'->0->'moves') = 4;
  assert t->'team'->0->'moves'->>1 = 'bxb', 'move names cleaned';
  assert not (t->'team'->0 ? 'nickname'), 'no nicknames go online';
  assert (public.friends_list()->'friends'->0->>'points')::int = 6;
  assert exists (select 1 from jsonb_array_elements(public.mail_list()) x where x->>'kind' = 'echo' and x->>'phrase' = '1');
end $$;

-- Blocking ends the friendship, hides the code and removes their mail.
select pg_temp.as_user('10000000-0000-0000-0000-00000000000c');
do $$
declare a text := (select code from codes where who = 'a');
begin
  assert public.friend_request(a)->>'status' = 'pending';
end $$;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000a');
do $$
declare c text := (select code from codes where who = 'c');
begin
  assert (public.block(c)->>'ok')::boolean;
  assert jsonb_array_length(public.friends_list()->'incoming') = 0, 'request gone';
  assert public.friends_list()->'blocked'->0->>'code' = c;
  assert (public.report(c, 0)->>'ok')::boolean;
end $$;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000c');
do $$ begin
  assert public.friend_request((select code from codes where who = 'a'))->>'error' = 'no_such_code', 'block looks like a bad code';
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.reports where target = '10000000-0000-0000-0000-00000000000c' and reason = 0) = 1;
end $$;

-- Parents switch social off: no new friends, no mail.
set role authenticated;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000d');
do $$ begin
  perform public.set_social(false);
  assert public.friend_request((select code from codes where who = 'a'))->>'error' = 'social_off';
  perform public.set_social(true);
end $$;
-- Friend request spam is limited.
do $$
declare i int; r jsonb;
begin
  for i in 1..25 loop r := public.friend_request('QQQQQQQQ'); end loop;
  assert r->>'error' = 'slow_down', 'rate limit: ' || r::text;
end $$;

-- World goal: only this week's kind counts, capped per call and per player, tiers claimable once.
reset role;
update public.server_config set value = '[{"kind":"battles","target":20}]' where key = 'goal_rotation';
update public.server_config set value = '12' where key = 'goal_user_cap';
delete from public.community_goals;
set role authenticated;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000a');
do $$
declare g jsonb;
begin
  g := public.community_get();
  assert g->>'kind' = 'battles' and (g->>'target')::int = 20;
  assert public.community_claim(1)->>'error' = 'not_helped';
  g := public.community_add('bonds', 5);
  assert (g->>'total')::int = 0, 'other kinds do not count';
  g := public.community_add('battles', 50);
  assert (g->>'mine')::int = 5, 'at most 5 per call';
  assert public.community_claim(1)->>'item' = 'strong_tonic', '25 % reached';
  assert public.community_claim(1)->>'error' = 'claimed';
  assert public.community_claim(2)->>'error' = 'not_reached';
  perform public.community_add('battles', 5);
  g := public.community_add('battles', 5);
  assert (g->>'mine')::int = 12, 'weekly cap per player';
end $$;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000b');
do $$
declare g jsonb;
begin
  g := public.community_add('battles', 5);
  g := public.community_add('battles', 5);
  assert (g->>'total')::int = 22;
  assert public.community_claim(4)->>'item' = 'spark_charm';
end $$;

-- Weekly board: plausible scores only, names only for friends.
select pg_temp.as_user('10000000-0000-0000-0000-00000000000a');
do $$
declare w text := to_char(now() at time zone 'utc', 'IYYY-"W"IW');
begin
  assert public.weekly_submit('2000-W01', 300)->>'error' = 'wrong_week';
  assert public.weekly_submit(w, 9999)->>'error' = 'implausible';
  perform public.weekly_submit(w, 250);
  perform public.weekly_submit(w, 100);
end $$;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000d');
do $$
declare w text := to_char(now() at time zone 'utc', 'IYYY-"W"IW'); b jsonb;
begin
  perform public.weekly_submit(w, 320);
  b := public.weekly_board(false);
  assert b->'rows'->0->>'score' = '320' and (b->'rows'->0->>'me')::boolean;
  assert b->'rows'->1->>'score' = '250', 'best score counts';
  assert b->'rows'->1->>'name' = '', 'strangers have no name';
  assert jsonb_array_length(public.weekly_board(true)->'rows') = 1, 'friends board: only me';
end $$;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000b');
do $$ begin
  assert public.weekly_board(false)->'rows'->1->>'name' = 'Ann', 'friends have names';
end $$;

-- Moving A to a new phone keeps friends and mail.
reset role;
insert into auth.users (id) values ('10000000-0000-0000-0000-0000000000a2') on conflict do nothing;
set role authenticated;
select pg_temp.as_user('10000000-0000-0000-0000-00000000000a');
create temp table tcode as select public.transfer_create()->>'code' as c;
select pg_temp.as_user('10000000-0000-0000-0000-0000000000a2');
do $$ begin
  perform public.hello(1);
  assert (public.transfer_claim((select c from tcode))->>'ok')::boolean;
  assert public.friends_list()->'friends'->0->>'name' = 'Ben', 'friend kept after the move';
  assert public.hello(1)->'profile'->>'code' = (select code from codes where who = 'a'), 'same friend code';
end $$;
reset role;
