-- Online 100, area 3: three raid tiers (23), a guardian that changes every week (24), a bonus for
-- the member with the most damage (28), a board of the fastest Rifts (29) and rare legendary
-- guardians (30). Values in server_config.raid_rules (data/raid_rules.json); LocalBackend and
-- RaidRules.gd do the same.

alter table public.raids add column if not exists tier int not null default 1;
alter table public.raids add column if not exists legendary boolean not null default false;

create or replace function public._raid_rules() returns jsonb
language sql stable as $$
  select public._config('raid_rules', '{"tiers": [{"id": "easy", "hp": 70, "level": 50}, {"id": "normal", "hp": 100, "level": 60},
    {"id": "hard", "hp": 150, "level": 60}], "legendaries": [], "legendary_chance": 0, "legendary_hp": 150, "top_bonus": 1,
    "board_rows": 10}'::jsonb)
$$;

drop function if exists public.raid_open(jsonb);
create or replace function public.raid_open(p_codes jsonb, p_tier int default 1) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._raid_check(u);
  rr jsonb := public._raid_rules();
  c jsonb;
  t uuid;
  who uuid[] := array[u];
  g text;
  leg boolean := false;
  wk int := floor(extract(epoch from now()) / 604800)::int;
  pool jsonb;
  r bigint;
  hp int;
begin
  if e is not null then return public._fail(e); end if;
  if p_tier is null or p_tier < 0 or p_tier >= jsonb_array_length(rr->'tiers') then return public._fail('bad_tier'); end if;
  if jsonb_typeof(p_codes) is distinct from 'array' or jsonb_array_length(p_codes) not between 1 and 3 then
    return public._fail('bad_party');
  end if;
  for c in select * from jsonb_array_elements(p_codes) loop
    t := public._by_code(c #>> '{}');
    if t is null or t = any(who) or public._blocked(u, t) or not public._social(t)
       or not (public._friends(u, t) or (public._bund_id(u) is not null and public._bund_id(u) = public._bund_id(t))) then
      return public._fail('no_such_code');
    end if;
    who := who || t;
  end loop;
  if not public._rate_ok(u, 'raid_open', 6) then return public._fail('slow_down'); end if;
  delete from public.raids where closes_at < now() - interval '7 days';
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb) into pool from jsonb_array_elements(rr->'legendaries') with ordinality l(x, o)
  where exists (select 1 from public.game_species s where s.name = x #>> '{}');
  if jsonb_array_length(pool) > 0 and floor(random() * 100) < coalesce((rr->>'legendary_chance')::int, 0) then
    g := pool->>(wk % jsonb_array_length(pool));
    leg := true;
  else
    select coalesce(jsonb_agg(x order by o), '[]'::jsonb) into pool from jsonb_array_elements(public._config('raid_guardians', '[]'))
      with ordinality l(x, o) where exists (select 1 from public.game_species s where s.name = x #>> '{}');
    if jsonb_array_length(pool) = 0 then return public._fail('no_guardian'); end if;
    g := pool->>(wk % jsonb_array_length(pool));
  end if;
  hp := public._raid_hp(array_length(who, 1)) * (rr->'tiers'->p_tier->>'hp')::int / 100;
  if leg then hp := hp * coalesce((rr->>'legendary_hp')::int, 150) / 100; end if;
  insert into public.raids (guardian, level, players, hp_total, hp_left, closes_at, tier, legendary)
  values (g, (rr->'tiers'->p_tier->>'level')::int, array_length(who, 1), hp, hp,
    now() + make_interval(hours => public._config_int('raid_hours', 48)), p_tier, leg)
  returning id into r;
  insert into public.raid_members (raid_id, user_id) select r, x from unnest(who) x;
  return jsonb_build_object('ok', true, 'raid', r, 'guardian', g, 'tier', p_tier, 'legendary', leg, 'hp', hp);
end $$;

-- The reward; the member with the most damage gets top_bonus more.
create or replace function public.raid_claim(p_raid bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  r public.raids;
  m public.raid_members;
  top boolean;
begin
  select * into r from public.raids where id = p_raid;
  select * into m from public.raid_members where raid_id = p_raid and user_id = u for update;
  if r.id is null or m.raid_id is null then return public._fail('no_such_raid'); end if;
  if r.won_at is null or m.damage * 100 < r.hp_total * public._config_int('raid_share_min', 5) then
    return public._fail('no_reward');
  end if;
  if m.claimed then return public._fail('claimed'); end if;
  update public.raid_members set claimed = true where raid_id = p_raid and user_id = u;
  top := m.damage >= (select max(damage) from public.raid_members where raid_id = p_raid);
  return jsonb_build_object('ok', true, 'item', r.reward->>'item', 'top', top,
    'count', coalesce((r.reward->>'count')::int, 1) + case when top then coalesce((public._raid_rules()->>'top_bonus')::int, 1) else 0 end);
end $$;

-- The fastest won Rifts, without names.
create or replace function public.raid_board() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  if public._raid_check(u) is not null then return public._fail(public._raid_check(u)); end if;
  return jsonb_build_object('ok', true, 'rows', coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('guardian', guardian, 'tier', tier, 'players', players,
      'seconds', extract(epoch from won_at - created_at)::int) x
    from public.raids where won_at is not null
    order by won_at - created_at limit coalesce((public._raid_rules()->>'board_rows')::int, 10)) s), '[]'::jsonb));
end $$;

revoke all on function public._raid_rules() from public, anon, authenticated, chimora_referee;
revoke all on function public.raid_open(jsonb, int), public.raid_claim(bigint), public.raid_board() from public, anon, chimora_referee;
grant execute on function public.raid_open(jsonb, int), public.raid_claim(bigint), public.raid_board() to authenticated;
