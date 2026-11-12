-- Online 100: the referee decides a live duel from the choices the server kept, so a phone that
-- reports something else cannot void it (3); a borrowed Spirling goes into one raid attempt or one
-- live duel (45). LocalBackend and LocalLiveMore.gd do the same.

-- --- 3: the referee plays the live duel again ---------------------------------------------------

alter table public.live_duels add column if not exists judge_id bigint;
alter table public.live_duels add column if not exists judged_round int not null default 0;
create index if not exists live_duels_judge on public.live_duels (judge_id) where judge_id is not null;

alter table public.battles drop constraint if exists battles_kind_check;
alter table public.battles add constraint battles_kind_check
  check (kind in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel', 'rift', 'bund_war', 'tourney', 'live_judge'));

-- The picked teams of both sides, [] before both picked.
create or replace function public._live_teams(d public.live_duels) returns jsonb
language plpgsql stable as $$
declare
  teams jsonb := '[]'::jsonb;
  rows jsonb;
  i jsonb;
begin
  if jsonb_typeof(d.pick->0) = 'array' and jsonb_typeof(d.pick->1) = 'array' then
    for s in 0 .. 1 loop
      rows := '[]'::jsonb;
      for i in select * from jsonb_array_elements(d.pick->s) loop
        rows := rows || jsonb_build_array(d.show->s->(i::int));
      end loop;
      teams := teams || jsonb_build_array(rows);
    end loop;
  end if;
  return teams;
end $$;

-- Like 20261111000040_live_duel.sql, but the clock rests while the referee looks at the duel. A
-- referee that stays silent for 10 minutes ends the duel without a winner.
create or replace function public._live_tick(p_id bigint) returns public.live_duels
language plpgsql volatile as $$
declare
  d public.live_duels;
  have jsonb;
  away0 boolean;
  away1 boolean;
begin
  select * into d from public.live_duels where id = p_id for update;
  if not found then return d; end if;
  if d.state = 'invited' and now() > d.deadline then
    update public.live_duels set state = 'expired' where id = p_id returning * into d;
  elsif d.state = 'running' and d.judge_id is not null then
    if now() > d.deadline + interval '10 minutes' then
      update public.live_duels set state = 'done', reason = 'disputed', winner = -1, judge_id = null
      where id = p_id returning * into d;
    end if;
  elsif d.state in ('picking', 'running') and now() > d.deadline + make_interval(secs => public._live_cfg('reconnect_seconds')) then
    have := case when d.state = 'picking' then d.pick else coalesce(d.moves->(d.round::text), '[null, null]'::jsonb) end;
    away0 := jsonb_typeof(have->0) = 'null';
    away1 := jsonb_typeof(have->1) = 'null';
    update public.live_duels set state = 'done', reason = 'timeout',
      winner = case when away0 = away1 then -1 when away0 then 1 else 0 end
    where id = p_id returning * into d;
  end if;
  return d;
end $$;

-- Like 20261113000030_tourney_watch.sql, plus "judging" while the referee looks at the duel.
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
    'winner', d.winner, 'reason', d.reason, 'emotes', d.emotes, 'judging', d.judge_id is not null);
end $$;

-- A player says the duel is over. The server does not take the winner from the phone: it hands the
-- finished rounds to the referee, which plays them again (BattleReferee, LiveDuelSim.judge). One
-- check per finished round at most.
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
    jsonb_build_object('expect', jsonb_build_object('live', true, 'seed', d.seed, 'teams', teams,
      'moves', coalesce((select jsonb_object_agg(key, value) from jsonb_each(d.moves) where key::int <= last_round), '{}'::jsonb))));
  return public._live_out(d, u);
end $$;

-- The referee's answer for a live duel: over (with the winner), not over yet (the duel goes on),
-- or it could not be played again (no winner).
create or replace function public._live_judged(p_battle_id bigint, p_verdict text, p_detail jsonb) returns void
language plpgsql volatile security definer set search_path = public as $$
declare d public.live_duels;
begin
  select * into d from public.live_duels where judge_id = p_battle_id for update;
  if not found then return; end if;
  if d.state <> 'running' then
    update public.live_duels set judge_id = null where id = d.id;
  elsif p_verdict = 'ok' and p_detail->>'finished' = 'true' and coalesce(p_detail->>'winner', '') ~ '^(-1|0|1)$' then
    update public.live_duels set state = 'done', reason = 'played', winner = (p_detail->>'winner')::int, judge_id = null
    where id = d.id;
  elsif p_verdict = 'ok' then
    update public.live_duels set judge_id = null, deadline = now() + make_interval(secs => public._live_cfg('turn_seconds'))
    where id = d.id;
  else
    update public.live_duels set state = 'done', reason = 'disputed', winner = -1, judge_id = null where id = d.id;
  end if;
end $$;

-- Built on 20261113000030_tourney_watch.sql: live duels get their result from the referee too.
create or replace function public._battle_result_in() returns trigger
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  update public.battles set status = new.verdict, decided_at = new.decided_at
  where id = new.battle_id and status = 'pending'
  returning kind into k;
  delete from public.battle_queue where battle_id = new.battle_id;
  if k in ('league_fair', 'league_open') then
    if new.verdict = 'ok' then
      perform public._league_apply(new.battle_id, new.detail);
    else
      update public.league_matches set state = 'done', rated = false where battle_id = new.battle_id;
    end if;
  elsif k = 'raid' then
    perform public._raid_apply(new.battle_id, new.verdict = 'ok', new.detail);
  elsif k = 'bund_war' then
    perform public._bund_war_apply(new.battle_id, new.verdict = 'ok', new.detail);
  elsif k = 'tourney' then
    perform public._tourney_apply(new.battle_id, new.verdict = 'ok', new.detail);
  elsif k = 'live_judge' then
    perform public._live_judged(new.battle_id, new.verdict, new.detail);
  end if;
  return new;
end $$;

-- --- 45: a borrowed Spirling in a live duel and in a raid attempt ---------------------------------

-- An unused loan of [u], locked; id is null when there is none. [p_why] says why.
create or replace function public._lend_take(u uuid, p_loan bigint, out l public.spirling_loans, out p_why text)
language plpgsql volatile as $$
begin
  p_why := null;
  if not public._flag_on('lend', 2147483647) then p_why := 'feature_off'; l := null; return; end if;
  perform public._lend_tidy();
  select * into l from public.spirling_loans where id = p_loan and borrower = u for update;
  if not found or public._blocked(u, l.lender)
     or not exists (select 1 from public.game_species where name = l.mon->>'species') then
    l := null;
    p_why := 'no_such_loan';
  elsif l.state <> 'lent' then
    l := null;
    p_why := 'used';
  end if;
end $$;

-- While both pick: the borrowed Spirling joins the Spirlings the player shows (the rival sees it
-- too) and can be picked like the others. One per duel; the loan is used up.
create or replace function public.live_borrow(p_id bigint, p_loan bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
  my_side int;
  t record;
  entry jsonb;
begin
  if d.id is null then return public._fail('no_such_duel'); end if;
  my_side := public._live_side(d, u);
  if d.state <> 'picking' or jsonb_typeof(d.pick->my_side) <> 'null' then return public._fail('duel_closed'); end if;
  if exists (select 1 from jsonb_array_elements(d.show->my_side) x where x ? 'loan') then return public._fail('used'); end if;
  select * into t from public._lend_take(u, p_loan);
  if t.p_why is not null then return public._fail(t.p_why); end if;
  entry := jsonb_build_object('species', (t.l).mon->>'species',
    'level', least(greatest(coalesce(((t.l).mon->>'level')::numeric, 1), 1), public._config_int('level_max', 60))::int,
    'moves', (select coalesce(jsonb_agg(m order by n), '[]'::jsonb) from (
      select m, n from jsonb_array_elements(case when jsonb_typeof((t.l).mon->'moves') = 'array' then (t.l).mon->'moves' else '[]'::jsonb end)
        with ordinality x(m, n) where jsonb_typeof(m) = 'string' order by n limit 4) q),
    'loan', true);
  update public.spirling_loans set state = 'used', used_for = 'live_duel' where id = (t.l).id;
  update public.live_duels set show = jsonb_set(show, array[my_side::text], (show->my_side) || jsonb_build_array(entry))
  where id = d.id returning * into d;
  return public._live_out(d, u);
end $$;

-- raid_start (20261110000011_raids.sql) with an optional loan: the borrowed Spirling takes the
-- last place of the team, with the fair league row like everyone (Ring 50, base values).
create or replace function public._raid_begin(u uuid, p_raid bigint, p_pick jsonb, p_loan bigint) returns jsonb
language plpgsql volatile as $$
declare
  e text := public._raid_check(u);
  r public.raids;
  team jsonb;
  a public.raid_attempts;
  t record;
  sp text;
begin
  if e is not null then return public._fail(e); end if;
  select * into r from public.raids where id = p_raid;
  if not found or not exists (select 1 from public.raid_members where raid_id = p_raid and user_id = u) then
    return public._fail('no_such_raid');
  end if;
  if r.hp_left <= 0 or r.closes_at <= now() then return public._fail('raid_closed'); end if;
  if (select count(*) from public.raid_attempts where raid_id = p_raid and user_id = u
      and created_at >= date_trunc('day', now())) >= public._config_int('raid_tries', 3) then
    return public._fail('no_tries');
  end if;
  if p_loan is not null then
    select * into t from public._lend_take(u, p_loan);
    if t.p_why is not null then return public._fail(t.p_why); end if;
    sp := (t.l).mon->>'species';
    if jsonb_typeof(p_pick) = 'array' and jsonb_array_length(p_pick) > 4 then return public._fail('bad_team'); end if;
    if jsonb_typeof(p_pick) = 'array' and exists (select 1 from jsonb_array_elements(p_pick) p
        where case when jsonb_typeof(p) = 'object' then p->>'species' else p #>> '{}' end = sp) then
      return public._fail('duplicate_species');
    end if;
  end if;
  team := public._league_team(u, 'fair', p_pick);
  if team ? 'error' then return public._fail(team->>'error'); end if;
  if sp is not null then
    team := jsonb_set(team, '{team}', (team->'team') || jsonb_build_array(public._league_fair_row(sp, (t.l).mon->'moves')));
    update public.spirling_loans set state = 'used', used_for = 'raid' where id = (t.l).id;
  end if;
  update public.raid_attempts set state = 'expired' where user_id = u and state = 'open';
  insert into public.raid_attempts (raid_id, user_id, seed, teams)
  values (p_raid, u, floor(random() * 2147483647)::bigint, jsonb_build_array(team->'team',
    jsonb_build_array(jsonb_build_object('species', r.guardian, 'level', r.level,
      'moves', public._league_default_moves(r.guardian, r.level)))))
  returning * into a;
  return jsonb_build_object('ok', true, 'attempt_id', a.id) || public._raid_expect(a);
end $$;

create or replace function public.raid_start(p_raid bigint, p_pick jsonb) returns jsonb
language sql volatile security definer set search_path = public as $$
  select public._raid_begin(public._uid(), p_raid, p_pick, null)
$$;

create or replace function public.raid_start_loan(p_raid bigint, p_pick jsonb, p_loan bigint) returns jsonb
language sql volatile security definer set search_path = public as $$
  select public._raid_begin(public._uid(), p_raid, p_pick, coalesce(p_loan, -1))
$$;

revoke all on function public._live_teams(public.live_duels), public._live_tick(bigint), public._live_out(public.live_duels, uuid),
  public._live_judged(bigint, text, jsonb), public._battle_result_in(), public._lend_take(uuid, bigint),
  public._raid_begin(uuid, bigint, jsonb, bigint) from public, anon, authenticated, chimora_referee;
revoke all on function public.live_finish(bigint, int), public.live_borrow(bigint, bigint), public.raid_start(bigint, jsonb),
  public.raid_start_loan(bigint, jsonb, bigint) from public, anon, chimora_referee;
grant execute on function public.live_finish(bigint, int), public.live_borrow(bigint, bigint), public.raid_start(bigint, jsonb),
  public.raid_start_loan(bigint, jsonb, bigint) to authenticated;
