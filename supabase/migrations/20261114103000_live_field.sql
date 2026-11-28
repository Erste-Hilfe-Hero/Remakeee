-- KAMPF_PLAN_1000 340: the inviter of a live duel picks the field it is fought on (one of
-- server_config.live_duel.fields, data/live_duel.json; '' for none). A rematch keeps it. Both phones,
-- watchers and the referee play the duel on it. LocalBackend and LocalLiveMore.gd do the same.

alter table public.live_duels add column if not exists field text not null default '';

-- The field if it may be picked, '' for none, null for an unknown one.
create or replace function public._live_field_ok(p_field text) returns text
language sql stable as $$
  select case when coalesce(p_field, '') = '' then ''
    when coalesce(public._config('live_duel', '{}'::jsonb)->'fields',
      '["ash_storm", "high_tide", "deep_murk", "static_veil", "pollen_drift", "dawn_glow"]'::jsonb) ? p_field then p_field
    else null end
$$;

drop function if exists public.live_invite(text);
create or replace function public.live_invite(p_code text, p_field text default '') returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  other uuid := public._by_code(p_code);
  f text := public._live_field_ok(p_field);
  r jsonb;
begin
  if not public._flag_on('live_duel', 2147483647) then return public._fail('feature_off'); end if;
  perform public._ensure_profile(u);
  if other is null or other = u or public._blocked(u, other) or not public._friends(u, other) then
    return public._fail('not_friends');
  end if;
  if f is null then return public._fail('bad_field'); end if;
  if not public._rate_ok(u, 'live_invite', public._live_cfg('invites_per_hour')) then return public._fail('slow_down'); end if;
  r := public._live_new(u, other);
  if coalesce((r->>'ok')::boolean, false) then
    update public.live_duels set field = f where id = (r->>'id')::bigint;
  end if;
  return r;
end $$;

-- Like 20261111000040_live_duel.sql, and the new duel keeps the field.
create or replace function public.live_rematch(p_id bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
  other uuid;
  r jsonb;
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  if d.state <> 'done' then return public._fail('duel_closed'); end if;
  other := case when d.a = u then d.b else d.a end;
  if public._blocked(u, other) or not public._friends(u, other) then return public._fail('not_friends'); end if;
  if not public._rate_ok(u, 'live_invite', public._live_cfg('invites_per_hour')) then return public._fail('slow_down'); end if;
  r := public._live_new(u, other);
  if coalesce((r->>'ok')::boolean, false) then
    update public.live_duels set field = d.field where id = (r->>'id')::bigint;
  end if;
  return r;
end $$;

-- Like 20261113000040_live_referee.sql, plus the field.
create or replace function public._live_out(d public.live_duels, u uuid) returns jsonb
language plpgsql stable as $$
declare
  teams jsonb := '[]'::jsonb;
  my_side int := public._live_side(d, u);
  mv jsonb := d.moves;
  open_row jsonb := d.moves->(d.round::text);
begin
  if d.state in ('running', 'done') then
    teams := public._live_teams(d);
  end if;
  if d.state = 'running' then
    if my_side < 0 then
      mv := coalesce((select jsonb_object_agg(key, value) from jsonb_each(d.moves) where key::int < d.round - 1), '{}'::jsonb);
    elsif open_row is not null then
      mv := mv || jsonb_build_object(d.round::text, jsonb_set(open_row, array[(1 - my_side)::text], 'null'::jsonb));
    end if;
  end if;
  return jsonb_build_object('ok', true, 'id', d.id, 'side', my_side, 'state', d.state, 'show', d.show,
    'picked', jsonb_build_array(jsonb_typeof(d.pick->0) = 'array', jsonb_typeof(d.pick->1) = 'array'),
    'teams', teams, 'seed', d.seed, 'round', d.round, 'moves', mv,
    'deadline', extract(epoch from d.deadline)::bigint, 'turn_seconds', public._live_cfg('turn_seconds'),
    'winner', d.winner, 'reason', d.reason, 'emotes', d.emotes, 'judging', d.judge_id is not null,
    'field', d.field);
end $$;

-- Like 20261113000040_live_referee.sql; the referee plays on the duel's field.
create or replace function public.live_finish(p_id bigint, p_winner int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
  bid bigint;
  last_round int;
  teams jsonb;
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  if d.state <> 'running' then return public._fail('duel_closed'); end if;
  if d.judge_id is not null then return public._live_out(d, u); end if;
  last_round := d.round - 1;
  if last_round < 1 or last_round <= d.judged_round then return public._fail('not_over'); end if;
  insert into public.battles (user_id, kind, ref) values (u, 'live_judge', d.id::text) returning id into bid;
  update public.live_duels set judge_id = bid, judged_round = last_round, deadline = now(),
    report = jsonb_set(report, array[public._live_side(d, u)::text], to_jsonb(coalesce(p_winner, -1)))
  where id = d.id returning * into d;
  teams := public._live_teams(d);
  perform public._referee_check(bid, jsonb_build_object('teams', teams, 'inputs', '[]'::jsonb),
    jsonb_build_object('expect', jsonb_build_object('live', true, 'seed', d.seed, 'teams', teams, 'field', d.field,
      'moves', coalesce((select jsonb_object_agg(key, value) from jsonb_each(d.moves) where key::int <= last_round), '{}'::jsonb))));
  return public._live_out(d, u);
end $$;

revoke all on function public._live_field_ok(text), public._live_out(public.live_duels, uuid)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.live_invite(text, text), public.live_rematch(bigint), public.live_finish(bigint, int)
  from public, anon, chimora_referee;
grant execute on function public.live_invite(text, text), public.live_rematch(bigint), public.live_finish(bigint, int)
  to authenticated;
