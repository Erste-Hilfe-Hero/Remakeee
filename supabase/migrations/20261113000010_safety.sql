-- Online 100, area 9 (points 83, 85, 86, 88): safety and fairness.
--   83  a report straight after a league battle or a live duel (report_battle), the opponent's code
--       stays hidden
--   85  parent switches for live duels, Raid Rifts, bunds, both leagues and suggestions from league
--       battles (profiles.parent_off, parent_set / parent_get); switched-off features leave hello's
--       flags, and the server refuses them
--   86  under 16 (age band from the shop's age question) the default is friends only and the fair
--       league: open league, bunds and suggestions start switched off until a parent changes it
--   88  no pushing points: a pair of players is rated at most pair_rated_daily times a day, and a
--       rated loss without any damage to the rival counts as sandbagged (not rated, noted, and from
--       sandbag_limit sandbagged battles in sandbag_days days a cheat note)
-- Values in server_config.safety (data/safety.json). LocalBackend does the same
-- (scripts/online/LocalSafety.gd, scripts/online/SafetyRules.gd). Re-runnable.

alter table public.profiles add column if not exists parent_off text[];
alter table public.league_matches add column if not exists sandbagged boolean not null default false;

create or replace function public._safety() returns jsonb
language sql stable as $$
  select '{"parent_keys": ["live_duel", "raid", "bund", "league_open", "league_fair", "suggest"],
    "young_band": 16, "young_off": ["league_open", "bund", "suggest"], "pair_rated_daily": 3,
    "sandbag_limit": 3, "sandbag_days": 7, "reports_per_hour": 10}'::jsonb
    || case when jsonb_typeof(public._config('safety', '{}'::jsonb)) = 'object'
      then public._config('safety', '{}'::jsonb) else '{}'::jsonb end
$$;

create or replace function public._young(u uuid) returns boolean
language sql stable as $$
  select coalesce((select age_band < (public._safety()->>'young_band')::int from public.shop_profiles where user_id = u), false)
$$;

-- 85, 86: the switched-off keys of [u]; a parent's own choice wins over the default by age.
create or replace function public._parent_off_list(u uuid) returns text[]
language sql stable as $$
  select coalesce((select parent_off from public.profiles where id = u),
    case when public._young(u) then array(select jsonb_array_elements_text(public._safety()->'young_off'))
      else '{}'::text[] end)
$$;

create or replace function public._parent_off(u uuid, p_key text) returns boolean
language sql stable as $$
  select u is not null and p_key = any(public._parent_off_list(u))
$$;

create or replace function public.parent_get() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._ensure_profile(u);
  return jsonb_build_object('ok', true, 'off', to_jsonb(public._parent_off_list(u)), 'young', public._young(u),
    'custom', (select parent_off is not null from public.profiles where id = u), 'keys', public._safety()->'parent_keys');
end $$;

-- [p_off]: the keys to switch off (an empty list switches everything on). Returns the flags that are
-- on now for [p_version], like hello.
create or replace function public.parent_set(p_off jsonb, p_version int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  k text;
  keys text[] := '{}';
begin
  perform public._ensure_profile(u);
  if jsonb_typeof(p_off) <> 'array' then return public._fail('bad_key'); end if;
  for k in select jsonb_array_elements_text(p_off) loop
    if not (public._safety()->'parent_keys') ? k then return public._fail('bad_key'); end if;
    if not k = any(keys) then keys := keys || k; end if;
  end loop;
  update public.profiles set parent_off = keys where id = u;
  return jsonb_build_object('ok', true, 'off', to_jsonb(keys),
    'flags', coalesce((select jsonb_agg(f.key order by f.key) from public.feature_flags f
      where f.enabled and p_version >= f.min_version and not public._parent_off(u, f.key)), '[]'::jsonb));
end $$;

-- hello as in 20261110000006_privacy.sql; flags a parent switched off are left out (85).
create or replace function public.hello(p_version int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  p public.profiles;
  min_v int := coalesce((public._config('min_version', '1'))::text::int, 1);
begin
  p := public._ensure_profile(u);
  update public.profiles set last_seen = now() where id = u;
  if random() < 0.01 then
    perform public._privacy_cleanup();
  end if;
  return jsonb_build_object(
    'profile', public._profile_json(p),
    'server_time', extract(epoch from now())::bigint,
    'update_required', p_version < min_v,
    'motd', public._config('motd', '""'),
    'online_now', (select count(*) from public.profiles where last_seen > now() - interval '5 minutes'),
    'flags', coalesce((select jsonb_agg(f.key order by f.key) from public.feature_flags f
      where f.enabled and p_version >= f.min_version and not public._parent_off(u, f.key)), '[]'::jsonb),
    'parent_off', to_jsonb(public._parent_off_list(u)));
end $$;

-- The checks every league, bund and raid call asks first, plus the parent switch.
create or replace function public._league_ok(p_league text) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if p_league is null or p_league not in ('fair', 'open') then return 'bad_league'; end if;
  if not public._flag_on('league_' || p_league, 2147483647) then return 'feature_off'; end if;
  if public._parent_off(auth.uid(), 'league_' || p_league) then return 'parent_off'; end if;
  if auth.uid() is not null and public._cheat_held(auth.uid()) then return 'under_review'; end if;
  return null;
end $$;

create or replace function public._bund_check(u uuid) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if not public._flag_on('bund', 2147483647) then return 'feature_off'; end if;
  if not public._social(u) then return 'social_off'; end if;
  if public._parent_off(u, 'bund') then return 'parent_off'; end if;
  return null;
end $$;

create or replace function public._raid_check(u uuid) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if not public._flag_on('raid', 2147483647) then return 'feature_off'; end if;
  if not public._social(u) then return 'social_off'; end if;
  if public._parent_off(u, 'raid') then return 'parent_off'; end if;
  if public._cheat_held(u) then return 'under_review'; end if;
  return null;
end $$;

-- Live duels (20261111000040_live_duel.sql): no new duel with a side whose parents switched them off.
create or replace function public._live_new(u uuid, other uuid) returns jsonb
language plpgsql volatile as $$
declare
  ta jsonb;
  tb jsonb;
  n int := public._live_cfg('show');
  nid bigint;
begin
  if public._parent_off(u, 'live_duel') or public._parent_off(other, 'live_duel') then
    return public._fail('parent_off');
  end if;
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb) into ta from (select x, o from jsonb_array_elements(
    (select team from public.profiles where id = u)) with ordinality t(x, o) where o <= n) s;
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb) into tb from (select x, o from jsonb_array_elements(
    (select team from public.profiles where id = other)) with ordinality t(x, o) where o <= n) s;
  if jsonb_array_length(ta) < public._live_cfg('pick') or jsonb_array_length(tb) < public._live_cfg('pick') then
    return public._fail('team_too_small');
  end if;
  insert into public.live_duels (a, b, show, seed, deadline)
  values (u, other, jsonb_build_array(ta, tb), floor(random() * 2147483647)::bigint,
    now() + make_interval(mins => public._live_cfg('invite_minutes')))
  returning live_duels.id into nid;
  return jsonb_build_object('ok', true, 'id', nid);
end $$;

create or replace function public.live_answer(p_id bigint, p_accept boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d public.live_duels := public._live_mine(p_id, u);
begin
  if d.id is null or public._live_side(d, u) <> 1 then return public._fail('no_such_duel'); end if;
  if d.state <> 'invited' then return public._fail('duel_closed'); end if;
  if not coalesce(p_accept, false) then
    update public.live_duels set state = 'expired' where id = d.id;
    return jsonb_build_object('ok', true, 'state', 'expired');
  end if;
  if public._parent_off(u, 'live_duel') then return public._fail('parent_off'); end if;
  update public.live_duels set state = 'picking', deadline = now() + make_interval(secs => public._live_cfg('pick_seconds'))
  where id = d.id returning * into d;
  return public._live_out(d, u);
end $$;

-- Suggestions (20261112230020_friends_more.sql): nobody whose parents switched suggestions off is
-- suggested, and they see none.
create or replace function public._suggest_target(u uuid, p_match bigint) returns uuid
language sql stable as $$
  select m.opponent from public.league_matches m
  where m.id = p_match and m.user_id = u and m.opponent is not null and m.opponent <> u
    and m.created_at > now() - make_interval(days => (public._fm()->>'suggest_days')::int)
    and not exists (select 1 from public.friendships f where f.a = least(u, m.opponent) and f.b = greatest(u, m.opponent))
    and not public._blocked(u, m.opponent) and public._social(m.opponent)
    and not public._parent_off(u, 'suggest') and not public._parent_off(m.opponent, 'suggest')
$$;

-- ---------------------------------------------------------------------------------------
-- 88: no pushing points

-- league_find as in 20261111000030_league_ranks.sql; a pair already rated pair_rated_daily times in
-- the last day is not rated again.
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
  update public.league_matches set state = 'expired', expired_at = now() where user_id = u and state = 'open';
  insert into public.league_matches (league, season, user_id, opponent, seed, teams, rated)
  values (p_league, s.id, u, opp.user_id, sd, jsonb_build_array(me->'team', oteam), rated)
  returning id into m;
  return jsonb_build_object('ok', true, 'found', true, 'match_id', m, 'seed', sd,
    'teams', jsonb_build_array(me->'team', oteam), 'ai', public._config_int('league_ai', 2),
    'opponent_tier', public._league_tier(orating), 'range', span, 'rated', rated, 'pair_limit', pair_cap,
    'echo', opp.user_id is null or abs(orating - (me->>'rating')::float8) > span);
end $$;

-- _league_apply as in 20261111000030_league_ranks.sql; a rated loss without any damage to the rival
-- is sandbagged: not rated, noted, and from sandbag_limit sandbagged battles in sandbag_days days a cheat note.
create or replace function public._league_apply(p_battle_id bigint, p_detail jsonb) returns void
language plpgsql volatile as $$
declare
  m public.league_matches;
  me jsonb;
  opp jsonb;
  sc float8;
  nr jsonb;
  sh jsonb;
begin
  select * into m from public.league_matches where battle_id = p_battle_id and state = 'submitted' for update;
  if not found then return; end if;
  sc := case p_detail->>'winner' when 'player' then 1 else 0 end;
  update public.league_matches set state = 'done', score = sc where id = m.id;
  if not m.rated then return; end if;
  if sc = 0 and coalesce((p_detail->>'foe_damage')::int, 1) = 0 then
    update public.league_matches set rated = false, sandbagged = true where id = m.id;
    if (select count(*) from public.league_matches where user_id = m.user_id and sandbagged
        and created_at > now() - make_interval(days => (public._safety()->>'sandbag_days')::int))
        >= (public._safety()->>'sandbag_limit')::int then
      insert into public.cheat_flags (user_id, reason, detail) values (m.user_id, 'league_sandbag', jsonb_build_object('match', m.id));
    end if;
    return;
  end if;
  me := public._league_entry(m.league, m.season, m.user_id);
  opp := public._league_entry(m.league, m.season, m.opponent);
  if me is null then return; end if;
  nr := public._league_rate((me->>'rating')::float8, (me->>'rd')::float8, (me->>'vol')::float8,
    coalesce((opp->>'rating')::float8, 1500), coalesce((opp->>'rd')::float8, 350), sc);
  sh := public._league_shield((me->>'rating')::float8, (nr->>'rating')::float8, (me->>'games')::int + 1,
    coalesce((me->>'shield')::int, 0));
  if m.league = 'fair' then
    update public.league_fair_entries set rating = (sh->>'rating')::float8, shield = (sh->>'shield')::int, rd = (nr->>'rd')::float8,
      vol = (nr->>'vol')::float8, games = games + 1, wins = wins + sc::int, updated_at = now()
    where season = m.season and user_id = m.user_id;
  else
    update public.league_open_entries set rating = (sh->>'rating')::float8, shield = (sh->>'shield')::int, rd = (nr->>'rd')::float8,
      vol = (nr->>'vol')::float8, games = games + 1, wins = wins + sc::int, updated_at = now()
    where season = m.season and user_id = m.user_id;
  end if;
end $$;

-- ---------------------------------------------------------------------------------------
-- 83: report straight after a battle

-- [p_kind] 'league' (league match id) or 'duel' (live duel id) of the caller's own battle.
create or replace function public.report_battle(p_kind text, p_ref text, p_reason int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid;
  n bigint;
begin
  if coalesce(p_ref, '') !~ '^[0-9]{1,18}$' then return public._fail('no_such_battle'); end if;
  if p_kind = 'league' then
    select opponent into t from public.league_matches where id = p_ref::bigint and user_id = u;
  elsif p_kind = 'duel' then
    select case when a = u then b else a end into t from public.live_duels where id = p_ref::bigint and (a = u or b = u);
  else
    return public._fail('bad_context');
  end if;
  if t is null or t = u then return public._fail('no_such_battle'); end if;
  if not public._rate_ok(u, 'report', (public._safety()->>'reports_per_hour')::int) then return public._fail('slow_down'); end if;
  insert into public.reports (reporter, target, target_name, reason, context, object_id)
  values (u, t, (select name from public.profiles where id = t), least(greatest(coalesce(p_reason, 3), 0), 3), p_kind, p_ref)
  returning id into n;
  return jsonb_build_object('ok', true, 'report_id', n);
end $$;

revoke all on function public._safety(), public._young(uuid), public._parent_off_list(uuid), public._parent_off(uuid, text)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.parent_get(), public.parent_set(jsonb, int), public.report_battle(text, text, int)
  from public, anon, chimora_referee;
grant execute on function public.parent_get(), public.parent_set(jsonb, int), public.report_battle(text, text, int)
  to authenticated;
