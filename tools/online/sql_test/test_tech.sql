-- Plan area 9: request id for save_put, size limit, feature switches, statement timeout.
-- Earlier tests replay older migrations (old five-argument save_put); this one replays ours.
\ir ../../../supabase/migrations/20261110090001_tech_sync.sql
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1') on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
do $$
declare r jsonb; big text;
begin
  r := public.save_put(1, '{"schema": 1, "money": 1}', 'a', 0, false, 'req-1');
  assert (r->>'ok')::boolean and (r->>'rev')::int = 1, 'first upload: ' || r::text;
  -- The answer got lost; the game sends the same upload again with the same id and old base.
  r := public.save_put(1, '{"schema": 1, "money": 1}', 'a', 0, false, 'req-1');
  assert (r->>'ok')::boolean and (r->>'rev')::int = 1 and (r->>'repeat')::boolean, 'resend counts once: ' || r::text;
  r := public.save_put(1, '{"schema": 1, "money": 2}', 'b', 1, false, 'req-2');
  assert (r->>'rev')::int = 2, 'next upload';
  -- A new upload with a stale base is still a conflict.
  r := public.save_put(1, '{"schema": 1, "money": 3}', 'c', 1, false, 'req-3');
  assert (r->>'conflict')::boolean, 'stale base conflicts';
  -- Old builds call it with five arguments.
  r := public.save_put(1, '{"schema": 1, "money": 4}', 'd', 2, false);
  assert (r->>'rev')::int = 3, 'five-argument call still works';
  big := repeat('x', 300000);
  r := public.save_put(2, jsonb_build_object('schema', 1, 'note', big), '', 0);
  assert r->>'error' = 'too_big', 'over 256 KB refused: ' || r::text;
end $$;
reset role;

-- Feature switches: a switched-off feature fails before the function runs.
do $$
begin
  assert public._feature_of('friend_request') = 'friends';
  assert public._feature_of('save_put') is null;
  assert public._feature_on('friends');
  update public.server_config set value = jsonb_set(value, '{friends}', 'false') where key = 'features';
  assert not public._feature_on('friends');
  assert public._feature_on(null), 'saves and sign-in can never be switched off';
  perform set_config('request.path', '/rpc/friend_request', true);
  begin
    perform public._pre_request();
    raise exception 'switched-off feature must fail';
  exception when sqlstate 'PT503' then null;
  end;
  perform set_config('request.path', '/rpc/save_put', true);
  perform public._pre_request();
  update public.server_config set value = jsonb_set(value, '{friends}', 'true') where key = 'features';
end $$;

do $$ begin
  assert exists (select 1 from pg_db_role_setting s join pg_roles r on r.oid = s.setrole
    where r.rolname = 'authenticated' and 'statement_timeout=3s' = any(s.setconfig)), 'timeout for players';
end $$;
