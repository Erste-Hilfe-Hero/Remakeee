-- Core API: profiles, saves with revisions and conflicts, plausibility, delete account.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b')
on conflict do nothing;

create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;

set role authenticated;

-- Players cannot read tables directly.
do $$ begin
  begin
    perform * from public.saves;
    raise exception 'tables must not be readable';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Not signed in -> error.
select pg_temp.as_user('');
do $$ begin
  begin
    perform public.hello(1);
    raise exception 'hello without user must fail';
  exception when sqlstate '28000' then null;
  end;
end $$;

select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
do $$
declare h jsonb; c text; r jsonb;
begin
  h := public.hello(1);
  c := h->'profile'->>'code';
  assert length(c) = 8, 'code has 8 characters';
  assert c ~ '^[A-HJKMNP-Z2-9]{8}$', 'code avoids look-alike characters: ' || c;
  assert (h->>'update_required')::boolean = false, 'version 1 is current';
  assert (public.hello(1)->'profile'->>'code') = c, 'code is stable';
  assert (h->>'online_now')::int >= 1;

  r := public.profile_set('  Mara  ', 2, 'Kindlop', '{"seals": 2, "seen": 9, "evil": "x", "hours": -3}');
  assert r->>'name' = 'Mara', 'name trimmed';
  assert (r->'card'->>'seals')::int = 2 and not (r->'card' ? 'evil') and (r->'card'->>'hours')::int = 0, 'card cleaned';
  r := public.profile_set('B1tch', 9, 'x', '{}');
  assert r->>'name' = 'Wanderer ' || right(c, 4), 'banned word replaced: ' || (r->>'name');
  assert (r->>'color')::int = 3, 'color clamped';
  r := public.profile_set('<script>', 0, '', '{}');
  assert r->>'name' like 'Wanderer %', 'symbols replaced';

  -- Saves: first write, then revisions.
  r := public.save_put(1, '{"schema": 1, "party": [{"level": 5}], "money": 10}', 'Brindlewick 0:10', 0);
  assert (r->>'ok')::boolean and (r->>'rev')::int = 1, 'first save rev 1: ' || r::text;
  r := public.save_put(1, '{"schema": 1, "party": [{"level": 6}], "money": 20}', 'Brindlewick 0:20', 1);
  assert (r->>'rev')::int = 2, 'second save rev 2';
  -- A device that still thinks rev 1 gets a conflict and changes nothing.
  r := public.save_put(1, '{"schema": 1, "party": [], "money": 1}', 'old device', 1);
  assert (r->>'conflict')::boolean and (r->>'rev')::int = 2, 'conflict reported';
  assert (public.save_get(1)->'data'->>'money')::int = 20, 'conflict did not overwrite';
  r := public.save_put(1, '{"schema": 1, "party": [], "money": 1}', 'old device', 1, true);
  assert (r->>'rev')::int = 3, 'forced write';
  -- Implausible saves are refused.
  assert public.save_put(2, '{"schema": 1, "party": [{"level": 200}]}', '', 0)->>'error' = 'implausible';
  assert public.save_put(2, '{"schema": 1, "party": [{},{},{},{},{},{},{}]}', '', 0)->>'error' = 'implausible';
  assert public.save_put(2, '{"schema": 1, "money": -5}', '', 0)->>'error' = 'implausible';
  assert public.save_put(2, '{"schema": 1, "money": "lots"}', '', 0)->>'error' = 'implausible';
  assert public.save_put(4, '{}', '', 0)->>'error' = 'bad_slot';
  assert jsonb_array_length(public.save_list()) = 1;
  assert public.presence('Brindlewick <b>')->>'server_time' is not null;
end $$;

-- Player B sees none of A's saves.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
do $$ begin
  perform public.hello(1);
  assert jsonb_array_length(public.save_list()) = 0, 'saves are private';
  assert public.save_get(1) is null;
end $$;

-- Old builds are told to update.
reset role;
update public.server_config set value = '5' where key = 'min_version';
set role authenticated;
do $$ begin
  assert (public.hello(4)->>'update_required')::boolean, 'old build must update';
end $$;
reset role;
update public.server_config set value = '1' where key = 'min_version';
set role authenticated;

-- Deleting the account removes profile and saves.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
do $$ begin
  assert (public.delete_account()->>'ok')::boolean;
end $$;
reset role;
do $$ begin
  assert not exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-00000000000a');
  assert not exists (select 1 from public.saves where user_id = '00000000-0000-0000-0000-00000000000a');
end $$;

-- Moving to a new phone with a transfer code.
reset role;
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000c1'), ('00000000-0000-0000-0000-0000000000c2'), ('00000000-0000-0000-0000-0000000000c3')
on conflict do nothing;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
create temp table if not exists t_code (c text);
do $$
declare code text; fc text;
begin
  fc := public.hello(1)->'profile'->>'code';
  perform public.save_put(1, '{"schema": 1, "money": 42}', 'old phone', 0);
  code := public.transfer_create()->>'code';
  assert length(code) = 12;
  insert into t_code values (code);
  assert public.transfer_claim(code)->>'error' = 'bad_code', 'own code does nothing';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
do $$
declare code text := (select c from t_code);
begin
  perform public.hello(1);
  assert public.transfer_claim('WRONGCODE123')->>'error' = 'bad_code';
  assert (public.transfer_claim(lower(left(code, 6)) || '-' || lower(substr(code, 7)))->>'ok')::boolean, 'code works with dash and lower case';
  assert (public.save_get(1)->'data'->>'money')::int = 42, 'saves moved';
  assert public.transfer_claim(code)->>'error' = 'bad_code', 'code is one-time';
end $$;
reset role;
do $$ begin
  assert not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000c1'), 'old account removed';
  assert exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-0000000000c2');
end $$;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c3');
do $$
declare i int;
begin
  perform public.hello(1);
  for i in 1..10 loop perform public.transfer_claim('XXXXXXXXXXXX'); end loop;
  assert public.transfer_claim('XXXXXXXXXXXX')->>'error' = 'too_many_tries';
end $$;
reset role;
