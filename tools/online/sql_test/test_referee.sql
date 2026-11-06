-- Plan area 7, items 2687-2691 and 2703: battle upload, referee queue, results, referee rights.
insert into auth.users (id) values ('30000000-0000-0000-0000-00000000000a') on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;
create temp table rb (n int primary key, id bigint);
grant all on rb to authenticated, chimora_referee;

set role authenticated;
select pg_temp.as_user('30000000-0000-0000-0000-00000000000a');
do $$
declare r jsonb;
  rep jsonb := '{"seed": 7, "teams": [[{"species": "Kindlop", "level": 5}], [{"species": "Puddlet", "level": 5}]], "inputs": []}';
  cl jsonb := '{"winner": "player", "hp": [[10], [0]], "rounds": 3}';
begin
  assert public.battle_submit('cheat', '', rep, cl)->>'error' = 'bad_kind';
  assert public.battle_submit('echo_duel', '', '[]', cl)->>'error' = 'bad_battle';
  assert public.battle_submit('echo_duel', '', '{"teams": 1}', cl)->>'error' = 'bad_battle';
  assert public.battle_submit('echo_duel', '', jsonb_set(rep, '{inputs}', (select jsonb_agg('{}'::jsonb) from generate_series(1, 401))), cl)->>'error' = 'bad_battle', 'too many inputs';
  r := public.battle_submit('echo_duel', 'ABCD', rep, cl);
  assert (r->>'ok')::boolean and r->>'status' = 'pending', r::text;
  insert into rb values (1, (r->>'battle_id')::bigint);
  r := public.battle_submit('echo_duel', 'ABCD', rep, cl);
  insert into rb values (2, (r->>'battle_id')::bigint);
  assert public.battle_status((select id from rb where n = 1))->>'status' = 'pending';
  assert public.battle_status(-1)->>'error' = 'no_such_battle';
  begin
    perform * from public.battle_queue;
    raise exception 'players must not read the queue';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.battle_results (battle_id, verdict) values ((select id from rb where n = 1), 'ok');
    raise exception 'players must not write results';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Someone else cannot see the state of my battle.
select pg_temp.as_user('30000000-0000-0000-0000-00000000000b');
do $$ begin
  assert public.battle_status((select id from rb where n = 1))->>'error' = 'no_such_battle';
end $$;

-- The referee: reads the queue (no account in it), writes results, nothing else (2703).
reset role;
set role chimora_referee;
do $$
declare q record;
begin
  select * into q from public.battle_queue where battle_id = (select id from rb where n = 1);
  assert q.replay->>'seed' = '7' and q.claim->>'winner' = 'player';
  begin
    perform * from public.battles;
    raise exception 'referee must not read battles';
  exception when insufficient_privilege then null;
  end;
  begin
    perform * from public.profiles;
    raise exception 'referee must not read profiles';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.battle_queue;
    raise exception 'referee must not delete the queue';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.battle_submit('echo_duel', '', '{}', '{}');
    raise exception 'referee must not upload battles';
  exception when insufficient_privilege then null;
  end;
  insert into public.battle_results (battle_id, verdict, detail) values ((select id from rb where n = 1), 'ok', '{"rounds": 3}');
  insert into public.battle_results (battle_id, verdict, detail) values ((select id from rb where n = 2), 'mismatch', '{"field": "hp"}');
  assert (select count(*) from public.battle_queue where battle_id in (select id from rb)) = 0, 'decided battles leave the queue';
end $$;
reset role;

do $$ begin
  assert public._battle_ok((select id from rb where n = 1)), 'ok counts';
  assert not public._battle_ok((select id from rb where n = 2)), 'mismatch does not count';
  assert not public._battle_ok(-1);
end $$;
set role authenticated;
select pg_temp.as_user('30000000-0000-0000-0000-00000000000a');
do $$ begin
  assert public.battle_status((select id from rb where n = 1))->>'status' = 'ok';
  assert public.battle_status((select id from rb where n = 2))->>'status' = 'mismatch';
  -- The limit per hour (server_config.battle_submit_limit).
  for i in 1..58 loop
    perform public.battle_submit('echo_duel', '', '{"teams": [[{}], [{}]]}', '{}');
  end loop;
  assert public.battle_submit('echo_duel', '', '{"teams": [[{}], [{}]]}', '{}')->>'error' = 'slow_down';
end $$;
reset role;

-- Deleting the account removes every battle, queue row and result.
do $$ begin
  delete from auth.users where id = '30000000-0000-0000-0000-00000000000a';
  assert not exists (select 1 from public.battles where user_id = '30000000-0000-0000-0000-00000000000a');
  assert not exists (select 1 from public.battle_results where battle_id in (select id from rb));
  assert not exists (select 1 from public.battle_queue where battle_id in (select id from rb));
end $$;
