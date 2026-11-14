-- KAMPF_PLAN_1000, area "Bosse und Wardens":
-- 419: the Raid Rift guardian has phases. Once the shared strength left (raids.hp_left) falls to a
--   phase's "left" percent of hp_total (server_config.raid_rules.phases, data/raid_rules.json), every
--   new attempt meets the guardian in that phase. The phase is fixed on the attempt when it starts
--   (raid_attempts.phase), so the referee replays the same battle however the Rift moved meanwhile.
-- 435: weekly boss boards by rounds for the heart stair (kind 'boss_tower', all Rift hearts, at most
--   90 rounds) and the week's prism heart (kind 'prism_boss', at most 30). Fewest rounds per player
--   and week count; names only for you and your friends (public._board_json). Off until the
--   'boss_board' flag is switched on.
-- Same rules in scripts/online/RaidRules.gd, LocalBackend.gd and LocalBossBoard.gd. Re-runnable.

alter table public.raid_attempts add column if not exists phase int not null default 0;

-- How many guardian phases a Rift with [p_left] of [p_total] strength left has reached.
create or replace function public._raid_phase(p_left int, p_total int) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int
  from jsonb_array_elements(coalesce((select value->'phases' from public.server_config
    where key = 'raid_rules' and jsonb_typeof(value->'phases') = 'array'), '[]'::jsonb)) x
  where p_total > 0 and p_left::bigint * 100 <= coalesce((x->>'left')::bigint, 0) * p_total
$$;

create or replace function public._raid_attempt_phase() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.phase := coalesce((select public._raid_phase(r.hp_left, r.hp_total) from public.raids r where r.id = new.raid_id), 0);
  return new;
end $$;

drop trigger if exists raid_attempt_phase on public.raid_attempts;
create trigger raid_attempt_phase before insert on public.raid_attempts
  for each row execute function public._raid_attempt_phase();

-- _raid_expect as in 20261112120040_shop_p2w_step4.sql, plus the phase (419).
create or replace function public._raid_expect(a public.raid_attempts) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', a.seed, 'teams', a.teams, 'ai', public._config_int('league_ai', 2),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false,
    'round_limit', public._config_int('raid_rounds', 10), 'seals', public._shop_seals(a.user_id),
    'amulets', public._shop_amulets(a.user_id), 'raid_phase', a.phase)
$$;

revoke all on function public._raid_phase(int, int), public._raid_attempt_phase(), public._raid_expect(public.raid_attempts)
  from public, anon, authenticated, chimora_referee;

-- 435: boss boards.
insert into public.feature_flags (key, enabled, min_version, note) values
  ('boss_board', false, 1, 'Wochenbestenliste Herzstiege und Prisma-Herz nach Runden')
on conflict (key) do nothing;

create table if not exists public.boss_scores (
  week text not null,
  kind text not null check (kind in ('boss_tower', 'prism_boss')),
  user_id uuid not null references auth.users (id) on delete cascade,
  rounds int not null check (rounds between 1 and 90),
  at timestamptz not null default now(),
  primary key (week, kind, user_id)
);
alter table public.boss_scores enable row level security;
revoke all on public.boss_scores from public, anon, authenticated, chimora_referee;

-- Most rounds a clear of a boss board kind can take, or null for an unknown kind.
create or replace function public._boss_max(p_kind text) returns int
language sql immutable as $$
  select case p_kind when 'boss_tower' then 90 when 'prism_boss' then 30 end
$$;

create or replace function public.boss_submit(p_kind text, p_rounds int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  w text := public._week();
begin
  if not public._flag_on('boss_board', 2147483647) then return public._fail('feature_off'); end if;
  if public._boss_max(p_kind) is null then return public._fail('bad_kind'); end if;
  if coalesce(p_rounds, -1) not between 1 and public._boss_max(p_kind) then return public._fail('implausible'); end if;
  perform public._ensure_profile(u);
  if not public._rate_ok(u, 'boss_board', 60) then return public._fail('slow_down'); end if;
  delete from public.boss_scores where week < to_char((now() - interval '7 days') at time zone 'utc', 'IYYY-"W"IW');
  insert into public.boss_scores (week, kind, user_id, rounds) values (w, p_kind, u, p_rounds)
  on conflict (week, kind, user_id) do update set rounds = least(public.boss_scores.rounds, excluded.rounds),
    at = case when excluded.rounds < public.boss_scores.rounds then now() else public.boss_scores.at end;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.boss_board(p_kind text, p_friends boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  w text := public._week();
begin
  if not public._flag_on('boss_board', 2147483647) then return public._fail('feature_off'); end if;
  if public._boss_max(p_kind) is null then return public._fail('bad_kind'); end if;
  return jsonb_build_object('ok', true, 'week', w, 'kind', p_kind, 'rows', public._board_json(u, coalesce((
    select jsonb_agg(jsonb_build_object('u', c.user_id, 'v', c.rounds, 'at', extract(epoch from c.at)))
    from public.boss_scores c
    where c.week = w and c.kind = p_kind
      and (not coalesce(p_friends, true) or c.user_id = u or public._friends(u, c.user_id))
      and not public._blocked(u, c.user_id)), '[]'::jsonb), true));
end $$;

revoke all on function public._boss_max(text) from public, anon, authenticated, chimora_referee;
revoke all on function public.boss_submit(text, int), public.boss_board(text, boolean) from public, anon, chimora_referee;
grant execute on function public.boss_submit(text, int), public.boss_board(text, boolean) to authenticated;
