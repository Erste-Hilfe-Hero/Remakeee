-- Wayfarer Pass track (Chimora pay2win rebuild, 27 Nov 2026): 30 steps with a free and a premium
-- reward each. Premium = an active Wayfarer Pass (offer rg_pass, table subscriptions). Pass points
-- come from play (battles won, bonds, daily tasks); the game reports each event, the server counts
-- it with the points from its own copy of data/pass_track.json, at most day_cap a day and
-- hour_calls reports an hour, like community_add. Seasons last season_days days from season_epoch
-- (Berlin date), so the season number follows from the date alone.
-- Rewards go the shop's ways: Riftglass to the ledger ('pass_track'), unlocks to entitlements,
-- items, coins and Spirlings to deliveries (picked up by shop_claim).

-- Copy of data/pass_track.json without its comment (tests/unit/test_pass_track.gd checks they match).
insert into public.server_config (key, value) values ('pass_track', '{"season_days": 30, "season_epoch": "2026-01-01", "points_per_tier": 100, "day_cap": 400, "hour_calls": 120, "points": {"win": 10, "bond": 25, "daily_task": 40}, "tiers": [{"tier": 1, "free": [{"t": "coins", "n": 500}], "premium": [{"t": "rg", "n": 50}]}, {"tier": 2, "free": [{"t": "item", "id": "tonic", "n": 3}], "premium": [{"t": "item", "id": "rg_ring_tonic", "n": 2}]}, {"tier": 3, "free": [{"t": "rg", "n": 20}], "premium": [{"t": "item", "id": "rg_growth_x2", "n": 1}]}, {"tier": 4, "free": [{"t": "item", "id": "rg_echo_scent", "n": 1}], "premium": [{"t": "item", "id": "rg_rift_breath", "n": 3}]}, {"tier": 5, "free": [{"t": "coins", "n": 1000}], "premium": [{"t": "rg", "n": 100}]}, {"tier": 6, "free": [{"t": "item", "id": "rg_ring_tonic", "n": 1}], "premium": [{"t": "item", "id": "rg_spark_shard", "n": 2}]}, {"tier": 7, "free": [{"t": "item", "id": "strong_tonic", "n": 3}], "premium": [{"t": "item", "id": "rg_glass_tonic", "n": 2}]}, {"tier": 8, "free": [{"t": "rg", "n": 30}], "premium": [{"t": "item", "id": "rg_ring_tonic_5", "n": 1}]}, {"tier": 9, "free": [{"t": "item", "id": "rg_rift_breath", "n": 1}], "premium": [{"t": "item", "id": "rg_bond_seal", "n": 1}]}, {"tier": 10, "free": [{"t": "coins", "n": 2000}], "premium": [{"t": "rg", "n": 150}]}, {"tier": 11, "free": [{"t": "item", "id": "rg_growth_x2", "n": 1}], "premium": [{"t": "item", "id": "rg_riftheart", "n": 1}]}, {"tier": 12, "free": [{"t": "item", "id": "remedy", "n": 3}], "premium": [{"t": "item", "id": "rg_coin_boost", "n": 2}]}, {"tier": 13, "free": [{"t": "rg", "n": 40}], "premium": [{"t": "item", "id": "rg_glass_shield", "n": 1}]}, {"tier": 14, "free": [{"t": "item", "id": "rg_ring_tonic", "n": 2}], "premium": [{"t": "item", "id": "rg_overcharge", "n": 2}]}, {"tier": 15, "free": [{"t": "unlock", "id": "frame_lantern"}], "premium": [{"t": "unlock", "id": "jacket_ink"}, {"t": "rg", "n": 150}]}, {"tier": 16, "free": [{"t": "coins", "n": 3000}], "premium": [{"t": "item", "id": "rg_spark_forge", "n": 1}]}, {"tier": 17, "free": [{"t": "item", "id": "rg_echo_scent", "n": 2}], "premium": [{"t": "item", "id": "rg_rift_breath_full", "n": 2}]}, {"tier": 18, "free": [{"t": "rg", "n": 50}], "premium": [{"t": "item", "id": "rg_growth_x3", "n": 1}]}, {"tier": 19, "free": [{"t": "item", "id": "max_tonic", "n": 2}], "premium": [{"t": "item", "id": "rg_whirl_glass", "n": 1}]}, {"tier": 20, "free": [{"t": "coins", "n": 4000}], "premium": [{"t": "rg", "n": 250}]}, {"tier": 21, "free": [{"t": "item", "id": "rg_ring_tonic", "n": 3}], "premium": [{"t": "item", "id": "rg_ring_tonic_10", "n": 1}]}, {"tier": 22, "free": [{"t": "item", "id": "rg_rift_breath", "n": 2}], "premium": [{"t": "item", "id": "rg_last_stand", "n": 1}]}, {"tier": 23, "free": [{"t": "rg", "n": 60}], "premium": [{"t": "item", "id": "rg_vigor_glass", "n": 1}]}, {"tier": 24, "free": [{"t": "item", "id": "rg_growth_x2", "n": 2}], "premium": [{"t": "item", "id": "rg_overcharge", "n": 3}]}, {"tier": 25, "free": [{"t": "coins", "n": 5000}], "premium": [{"t": "rg", "n": 300}]}, {"tier": 26, "free": [{"t": "item", "id": "rg_bond_seal", "n": 1}], "premium": [{"t": "item", "id": "rg_clear_shard", "n": 1}]}, {"tier": 27, "free": [{"t": "rg", "n": 80}], "premium": [{"t": "item", "id": "rg_ring_elixir", "n": 1}]}, {"tier": 28, "free": [{"t": "item", "id": "rg_ring_tonic_5", "n": 1}], "premium": [{"t": "item", "id": "rg_grand_tonic", "n": 3}]}, {"tier": 29, "free": [{"t": "item", "id": "rg_glass_tonic", "n": 1}], "premium": [{"t": "item", "id": "rg_growth_x5", "n": 1}]}, {"tier": 30, "free": [{"t": "unlock", "id": "backdrop_star_meadow"}, {"t": "rg", "n": 100}], "premium": [{"t": "spirling", "species": "Vorlucent", "level": 40}, {"t": "unlock", "id": "hat_tricorn"}, {"t": "rg", "n": 500}]}]}')
on conflict (key) do update set value = excluded.value;

create table if not exists public.pass_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  season int not null,
  points int not null default 0 check (points >= 0),
  day date not null default '2000-01-01',
  day_points int not null default 0,
  hour_at timestamptz not null default now(),
  hour_calls int not null default 0,
  -- Bit (tier - 1) set = that reward was taken.
  claimed_free bigint not null default 0,
  claimed_premium bigint not null default 0,
  primary key (user_id, season)
);
alter table public.pass_progress enable row level security;
revoke all on public.pass_progress from public, anon, authenticated;

create or replace function public._pass_cfg() returns jsonb
language sql stable as $$ select public._config('pass_track', '{}'::jsonb) $$;

-- Season number of Berlin date [p_day]: 0 from season_epoch, one more every season_days days.
create or replace function public._pass_season(p_day date) returns int
language sql stable as $$
  select floor((p_day - coalesce((public._pass_cfg()->>'season_epoch')::date, date '2026-01-01'))::numeric
    / greatest(coalesce((public._pass_cfg()->>'season_days')::int, 30), 1))::int
$$;

create or replace function public._pass_season_start(p_season int) returns date
language sql stable as $$
  select coalesce((public._pass_cfg()->>'season_epoch')::date, date '2026-01-01')
    + p_season * greatest(coalesce((public._pass_cfg()->>'season_days')::int, 30), 1)
$$;

-- The caller's row of the running season, locked for the rest of the transaction.
create or replace function public._pass_row(p_uid uuid) returns public.pass_progress
language plpgsql volatile as $$
declare
  s int := public._pass_season(public._shop_today());
  r public.pass_progress;
begin
  insert into public.pass_progress (user_id, season) values (p_uid, s) on conflict do nothing;
  select * into r from public.pass_progress where user_id = p_uid and season = s for update;
  return r;
end $$;

create or replace function public._pass_json(r public.pass_progress, p_uid uuid) returns jsonb
language plpgsql stable as $$
declare
  cfg jsonb := public._pass_cfg();
  per int := greatest(coalesce((cfg->>'points_per_tier')::int, 100), 1);
  n int := jsonb_array_length(coalesce(cfg->'tiers', '[]'::jsonb));
  start date := public._pass_season_start(r.season);
begin
  return jsonb_build_object('ok', true, 'season', r.season, 'points', r.points,
    'tier', least(r.points / per, n), 'tiers', n, 'per_tier', per,
    'claimed_free', r.claimed_free, 'claimed_premium', r.claimed_premium,
    'premium', coalesce(public._shop_pass_until(p_uid) > now(), false),
    'day_points', case when r.day = public._shop_today() then r.day_points else 0 end,
    'day_cap', coalesce((cfg->>'day_cap')::int, 400),
    'starts', extract(epoch from (start::timestamp at time zone 'Europe/Berlin'))::bigint,
    'ends', extract(epoch from ((start + greatest(coalesce((cfg->>'season_days')::int, 30), 1))::timestamp
      at time zone 'Europe/Berlin'))::bigint);
end $$;

-- ---------------------------------------------------------------------------------------
-- Player API

-- The pass track screen: season, points, step, taken rewards and whether the premium row is open.
create or replace function public.pass_state() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
begin
  return public._pass_json(public._pass_row(u), u);
end $$;

-- One play event ("win", "bond", "daily_task"; [p_amount] events, at most 3 per report). Unknown
-- kinds count nothing. Too many reports in an hour answer slow_down (the game sends it again later).
create or replace function public.pass_points_add(p_kind text, p_amount int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  cfg jsonb := public._pass_cfg();
  r public.pass_progress := public._pass_row(u);
  today date := public._shop_today();
  each int := coalesce((cfg->'points'->>coalesce(p_kind, ''))::int, 0);
  cap int := coalesce((cfg->>'day_cap')::int, 400);
  n int;
begin
  if r.hour_at < now() - interval '1 hour' then
    r.hour_at := now();
    r.hour_calls := 0;
  end if;
  if r.hour_calls >= coalesce((cfg->>'hour_calls')::int, 120) then
    return public._fail('slow_down');
  end if;
  if r.day <> today then
    r.day := today;
    r.day_points := 0;
  end if;
  n := least(each * least(greatest(coalesce(p_amount, 0), 0), 3), greatest(cap - r.day_points, 0));
  update public.pass_progress set points = points + n, day = r.day, day_points = r.day_points + n,
    hour_at = r.hour_at, hour_calls = r.hour_calls + 1
  where user_id = u and season = r.season returning * into r;
  return public._pass_json(r, u) || jsonb_build_object('added', n);
end $$;

-- Takes the [p_lane] ('free' or 'premium') reward of step [p_tier] once per season. The premium
-- row needs an active Wayfarer Pass; a pass bought later opens every premium reward already reached.
create or replace function public.pass_claim(p_tier int, p_lane text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  cfg jsonb := public._pass_cfg();
  r public.pass_progress := public._pass_row(u);
  per int := greatest(coalesce((cfg->>'points_per_tier')::int, 100), 1);
  n int := jsonb_array_length(coalesce(cfg->'tiers', '[]'::jsonb));
  bit bigint;
  grants jsonb;
  g jsonb;
  bag jsonb := '[]'::jsonb;
  ref text;
begin
  if p_lane is null or p_lane not in ('free', 'premium') then return public._fail('bad_lane'); end if;
  if p_tier is null or p_tier < 1 or p_tier > n then return public._fail('bad_tier'); end if;
  if r.points / per < p_tier then return public._fail('not_reached'); end if;
  bit := (1::bigint << (p_tier - 1));
  if (case when p_lane = 'free' then r.claimed_free else r.claimed_premium end) & bit <> 0 then
    return public._fail('claimed');
  end if;
  if p_lane = 'premium' and not coalesce(public._shop_pass_until(u) > now(), false) then
    return public._fail('no_pass');
  end if;
  grants := coalesce(cfg->'tiers'->(p_tier - 1)->p_lane, '[]'::jsonb);
  ref := 'pass:' || r.season || ':' || p_tier || ':' || p_lane;
  for g in select * from jsonb_array_elements(grants) loop
    case g->>'t'
      when 'rg' then
        perform public._shop_ledger_add(u, (g->>'n')::int, 'pass_track', ref);
      when 'unlock' then
        insert into public.entitlements (user_id, key) values (u, g->>'id')
        on conflict (user_id, key) do update set count = public.entitlements.count + 1, at = now();
      when 'item', 'coins', 'spirling' then
        bag := bag || jsonb_build_array(g);
      else
        null;
    end case;
  end loop;
  if jsonb_array_length(bag) > 0 then
    insert into public.deliveries (user_id, grants) values (u, bag);
  end if;
  if p_lane = 'free' then
    update public.pass_progress set claimed_free = claimed_free | bit where user_id = u and season = r.season;
  else
    update public.pass_progress set claimed_premium = claimed_premium | bit where user_id = u and season = r.season;
  end if;
  return jsonb_build_object('ok', true, 'tier', p_tier, 'lane', p_lane, 'grants', grants,
    'balance', public._shop_balance(u));
end $$;

-- The action queue (20261110000017_action_queue.sql) also carries pass points, so a report sent
-- twice over a weak connection counts once.
create or replace function public.action_once(p_id text, p_fn text, p_args jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  rid text := left(coalesce(p_id, ''), 40);
  a jsonb := coalesce(p_args, '{}'::jsonb);
  r jsonb;
begin
  if length(rid) < 8 then
    return public._fail('bad_id');
  end if;
  delete from public.action_done where user_id = u and at < now() - interval '2 days';
  if exists (select 1 from public.action_done where user_id = u and id = rid) then
    return jsonb_build_object('ok', true, 'repeat', true);
  end if;
  if p_fn = 'mail_send' and a->>'p_kind' in ('phrase', 'wave', 'thanks') then
    r := public.mail_send(a->>'p_code', a->>'p_kind', coalesce((a->>'p_phrase')::int, 0));
  elsif p_fn = 'community_add' then
    r := public.community_add(a->>'p_kind', coalesce((a->>'p_amount')::int, 0));
  elsif p_fn = 'pass_points_add' then
    r := public.pass_points_add(a->>'p_kind', coalesce((a->>'p_amount')::int, 0));
  else
    return public._fail('bad_action');
  end if;
  -- Refused for going too fast: the game may send the same action again later.
  if coalesce(r->>'error', '') <> 'slow_down' then
    insert into public.action_done (user_id, id) values (u, rid) on conflict do nothing;
  end if;
  return r;
end $$;

revoke all on function public._pass_cfg(), public._pass_season(date), public._pass_season_start(int),
  public._pass_row(uuid), public._pass_json(public.pass_progress, uuid)
  from public, anon, authenticated;
revoke all on function public.pass_state(), public.pass_points_add(text, int), public.pass_claim(int, text),
  public.action_once(text, text, jsonb) from public, anon;
grant execute on function public.pass_state(), public.pass_points_add(text, int), public.pass_claim(int, text),
  public.action_once(text, text, jsonb) to authenticated;
