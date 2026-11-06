-- Plan area 9 (technology): safer saving and server limits.
-- 3658: save_put takes a request id, so an upload resent after a timeout counts only once.
-- 3662: a save may be at most 256 KB (Caddy also caps /rest/v1 bodies at 512 KB).
-- 3674: every online feature has a switch in server_config and can be turned off without a new build.
-- 3856: queries of players time out after 3 seconds.

insert into public.server_config (key, value) values
  ('save_max_bytes', '262144'),
  -- Off = the server answers {"ok": false, "error": "feature_off"} for that feature's functions.
  ('features', '{"friends": true, "mail": true, "world_goal": true, "board": true, "echoes": true}')
on conflict (key) do nothing;

alter table public.saves add column if not exists request_id text;

-- Which feature a player function belongs to (null = always on: sign-in, saves, account).
create or replace function public._feature_of(p_fn text) returns text
language sql immutable as $$
  select case
    when p_fn in ('friend_request', 'friend_respond', 'friend_remove', 'friends_list', 'block', 'unblock') then 'friends'
    when p_fn in ('mail_send', 'gift_send', 'mail_list', 'gift_open', 'mail_open') then 'mail'
    when p_fn in ('community_get', 'community_add', 'community_claim') then 'world_goal'
    when p_fn in ('weekly_submit', 'weekly_board') then 'board'
    when p_fn in ('team_set', 'friend_team', 'echo_report') then 'echoes'
  end
$$;

create or replace function public._feature_on(p_feature text) returns boolean
language sql stable security definer set search_path = public as $$
  select p_feature is null
    or coalesce((public._config('features', '{}'::jsonb)->>p_feature)::boolean, true)
$$;

-- PostgREST runs this before every request (PGRST_DB_PRE_REQUEST in server/docker-compose.yml).
-- A switched-off feature fails with a clean error the game shows as "not available right now".
create or replace function public._pre_request() returns void
language plpgsql stable security definer set search_path = public as $$
declare
  path text := coalesce(current_setting('request.path', true), '');
  fn text := substring(path from '^/rpc/([a-z_]+)$');
begin
  if fn is not null and not public._feature_on(public._feature_of(fn)) then
    raise exception 'feature_off' using errcode = 'PT503', detail = public._feature_of(fn),
      hint = 'This feature is switched off in server_config.';
  end if;
end $$;
revoke all on function public._pre_request(), public._feature_on(text), public._feature_of(text) from public;
grant execute on function public._pre_request() to anon, authenticated;

-- save_put with a request id. Built on the anticheat version (20261110000005): schema,
-- plausibility, strip and cheat checks stay. No defaults here, so the five-argument save_put
-- (old builds, and the tests that replay older migrations) never makes a call ambiguous.
create or replace function public.save_put(p_slot int, p_data jsonb, p_summary text, p_base_rev int,
  p_force boolean, p_request_id text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  cur public.saves;
  new_rev int;
  why text;
  data jsonb;
  rid text := nullif(left(coalesce(p_request_id, ''), 64), '');
begin
  if p_slot not between 1 and 3 then
    return jsonb_build_object('ok', false, 'error', 'bad_slot');
  end if;
  if octet_length(p_data::text) > coalesce((public._config('save_max_bytes'))::int, 262144) then
    return jsonb_build_object('ok', false, 'error', 'too_big');
  end if;
  if not public._save_schema_ok(p_data) then
    return jsonb_build_object('ok', false, 'error', 'schema');
  end if;
  if not public._save_ok(p_data) then
    return jsonb_build_object('ok', false, 'error', 'implausible');
  end if;
  data := public._save_strip(p_data);
  select * into cur from public.saves where user_id = u and slot = p_slot for update;
  -- The same upload again (the answer to the first one got lost): it is already stored.
  if found and rid is not null and cur.request_id = rid then
    return jsonb_build_object('ok', true, 'rev', cur.rev, 'saved_at', extract(epoch from cur.saved_at)::bigint,
      'repeat', true);
  end if;
  if found and cur.rev <> p_base_rev and not p_force then
    return jsonb_build_object('ok', false, 'conflict', true, 'rev', cur.rev,
      'saved_at', extract(epoch from cur.saved_at)::bigint, 'summary', cur.summary);
  end if;
  why := public._save_cheat(cur.data, cur.saved_at, data);
  if why is not null then
    -- The game tries again at the next save; the same refusal counts once per 10 minutes.
    if not exists (select 1 from public.cheat_flags f where f.user_id = u and f.slot = p_slot
        and f.reason = why and f.at > now() - interval '10 minutes') then
      insert into public.cheat_flags (user_id, slot, reason, detail)
      values (u, p_slot, why, jsonb_build_object('money', data->'money', 'play_time', data->'play_time',
        'old_money', cur.data->'money', 'old_play_time', cur.data->'play_time'));
    end if;
    return jsonb_build_object('ok', false, 'error', 'refused', 'reason', why);
  end if;
  new_rev := coalesce(cur.rev, 0) + 1;
  insert into public.saves (user_id, slot, rev, data, summary, saved_at, request_id)
  values (u, p_slot, new_rev, data, left(coalesce(p_summary, ''), 60), now(), rid)
  on conflict (user_id, slot) do update
    set rev = excluded.rev, data = excluded.data, summary = excluded.summary, saved_at = excluded.saved_at,
      request_id = excluded.request_id;
  return jsonb_build_object('ok', true, 'rev', new_rev, 'saved_at', extract(epoch from now())::bigint);
end $$;
revoke all on function public.save_put(int, jsonb, text, int, boolean, text) from public, anon;
grant execute on function public.save_put(int, jsonb, text, int, boolean, text) to authenticated;

-- Old builds call save_put with five arguments: same checks, just without a request id.
create or replace function public.save_put(p_slot int, p_data jsonb, p_summary text, p_base_rev int,
  p_force boolean default false) returns jsonb
language sql volatile security definer set search_path = public as $$
  select public.save_put(p_slot, p_data, p_summary, p_base_rev, coalesce(p_force, false), null::text)
$$;
revoke all on function public.save_put(int, jsonb, text, int, boolean) from public, anon;
grant execute on function public.save_put(int, jsonb, text, int, boolean) to authenticated;

-- A slow query must not hold the server (applies to new connections of these roles).
alter role anon set statement_timeout = '3s';
alter role authenticated set statement_timeout = '3s';
