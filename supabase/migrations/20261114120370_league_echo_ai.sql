-- KAMPF_PLAN_1000 item 876: the AI tier of the rival's echo in a league battle follows the searching
-- player's rank: server_config.league_ranks ranks[r].echo_ai (data/league_ranks.json), placement
-- counts as the first rank, league_ai when a rank sets none. league_find keeps the tier on the
-- match, so the referee replays the battle with the same tier (_league_expect).
-- LocalBackend does the same (LeagueRules.echo_ai). Re-runnable.

alter table public.league_matches add column if not exists ai int;

create or replace function public._league_echo_ai(p_rank int) returns int
language sql stable as $$
  select greatest(1, least(3, coalesce(
    (public._league_ranks()->'ranks'->greatest(0, least(coalesce(p_rank, 0), jsonb_array_length(public._league_ranks()->'ranks') - 1))->>'echo_ai')::int,
    public._config_int('league_ai', 2))))
$$;

-- league_find as in 20261113000010_safety.sql, with the echo tier per rank stored on the match.
create or replace function public.league_find(p_league text, p_waited int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  err text := public._league_ok(p_league);
  s public.league_seasons;
  me jsonb;
  opp record;
  span float8;
  m bigint;
  sd bigint := floor(random() * 2147483647)::bigint;
  wide boolean := coalesce(p_waited, 0) >= coalesce((public._league_ranks()->>'echo_after')::int, 45);
  qn int;
  ql timestamptz;
  w int;
  oteam jsonb;
  orating float8;
  rated boolean;
  pair_cap boolean := false;
  eai int;
begin
  if err is not null then return public._fail(err); end if;
  s := public._league_season();
  if public._league_state(s) = 'paused' then return public._fail('season_paused'); end if;
  me := public._league_entry(p_league, s.id, u);
  if me is null then return public._fail('not_joined'); end if;
  select count(*), max(expired_at) into qn, ql from public.league_matches
  where user_id = u and state = 'expired' and created_at > now() - interval '1 day'
    and expired_at >= created_at + make_interval(secs => coalesce((public._league_ranks()->>'quit_grace')::int, 30));
  w := public._league_quit_wait(qn, coalesce(extract(epoch from now() - ql)::int, 0));
  if w > 0 then return public._fail('quit_wait') || jsonb_build_object('wait', w); end if;
  if not public._rate_ok(u, 'league_find', 240) then return public._fail('slow_down'); end if;
  span := least(public._config_int('league_search_start', 100)
    + public._config_int('league_search_step', 50) * floor(greatest(coalesce(p_waited, 0), 0) / 10.0),
    public._config_int('league_search_max', 400));
  if p_league = 'fair' then
    select user_id, team, rating into opp from public.league_fair_entries e
    where e.season = s.id and e.user_id <> u and not public._blocked(u, e.user_id)
      and (wide or abs(e.rating - (me->>'rating')::float8) <= span)
    order by abs(e.rating - (me->>'rating')::float8), random() limit 1;
  else
    select user_id, team, rating into opp from public.league_open_entries e
    where e.season = s.id and e.user_id <> u and not public._blocked(u, e.user_id)
      and (wide or abs(e.rating - (me->>'rating')::float8) <= span)
    order by abs(e.rating - (me->>'rating')::float8), random() limit 1;
  end if;
  if opp.user_id is null and not wide then
    return jsonb_build_object('ok', true, 'found', false, 'range', span);
  end if;
  oteam := coalesce(opp.team, me->'team');
  orating := coalesce(opp.rating, (me->>'rating')::float8);
  rated := public._league_state(s) = 'running' and opp.user_id is not null;
  if rated and (select count(*) from public.league_matches x where x.user_id = u and x.opponent = opp.user_id
      and x.rated and x.state in ('submitted', 'done') and x.created_at > now() - interval '1 day') >= (public._safety()->>'pair_rated_daily')::int then
    rated := false;
    pair_cap := true;
  end if;
  eai := public._league_echo_ai(public._league_rank((me->>'rating')::float8, (me->>'games')::int));
  update public.league_matches set state = 'expired', expired_at = now() where user_id = u and state = 'open';
  insert into public.league_matches (league, season, user_id, opponent, seed, teams, rated, ai)
  values (p_league, s.id, u, opp.user_id, sd, jsonb_build_array(me->'team', oteam), rated, eai)
  returning id into m;
  return jsonb_build_object('ok', true, 'found', true, 'match_id', m, 'seed', sd,
    'teams', jsonb_build_array(me->'team', oteam), 'ai', eai,
    'opponent_tier', public._league_tier(orating), 'range', span, 'rated', rated, 'pair_limit', pair_cap,
    'echo', opp.user_id is null or abs(orating - (me->>'rating')::float8) > span);
end $$;

-- _league_expect as in 20261112120040_shop_p2w_step4.sql; the tier comes from the match.
create or replace function public._league_expect(m public.league_matches) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', m.seed, 'teams', m.teams, 'ai', coalesce(m.ai, public._config_int('league_ai', 2)),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false,
    'seals', case when m.league = 'open' then public._shop_seals(m.user_id) else '[0, 0, 0]'::jsonb end,
    'amulets', case when m.league = 'open' then public._shop_amulets(m.user_id) else '[0, 0, 0]'::jsonb end)
$$;

revoke all on function public._league_echo_ai(int), public._league_expect(public.league_matches)
  from public, anon, authenticated, chimora_referee;
