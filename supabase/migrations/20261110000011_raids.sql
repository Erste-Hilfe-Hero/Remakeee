-- Plan area 7, items 2847-2851, 2871 and the raid part of 2691: Raid Rifts. 2 to 4 friends or
-- bund members weaken one strong guardian together, each on their own battle screen. The
-- guardian's strength lives here (raids.hp_left); a battle only takes damage off it once the
-- referee said "ok". A Rift stays open 48 hours, everyone gets 3 attempts a day, each at most
-- 10 rounds. Attempts cost nothing (the battle is friendly, the team is healed afterwards).
-- Everyone with at least 5 % of the damage gets the same reward, rolled here from the open
-- table raid_rewards that the game shows. Behind the feature flag 'raid'.
-- No raid row carries an account id, so deleting an account never removes the raid of the others.

insert into public.server_config (key, value) values
  ('raid_guardians', '["Leviarch", "Calderox", "Cairnhold", "Verdantusk", "Tempestrel", "Solmantle", "Obsidroth"]'),
  ('raid_level', '60'), ('raid_base', '1200'), ('raid_hours', '48'), ('raid_tries', '3'), ('raid_rounds', '10'),
  ('raid_share_min', '5'),
  ('raid_rewards', '[{"item":"max_tonic","count":2,"w":3},{"item":"revival_leaf","count":2,"w":3},{"item":"strong_tonic","count":5,"w":3},{"item":"keen_lens","count":1,"w":1},{"item":"swift_feather","count":1,"w":1}]')
on conflict (key) do nothing;

create table if not exists public.raids (
  id bigserial primary key,
  guardian text not null,
  level int not null,
  players int not null check (players between 2 and 4),
  hp_total int not null,
  hp_left int not null check (hp_left >= 0),
  reward jsonb,
  created_at timestamptz not null default now(),
  closes_at timestamptz not null,
  won_at timestamptz
);
create table if not exists public.raid_members (
  raid_id bigint not null references public.raids (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  damage int not null default 0,
  claimed boolean not null default false,
  primary key (raid_id, user_id)
);
create index if not exists raid_members_user on public.raid_members (user_id);
create table if not exists public.raid_attempts (
  id bigserial primary key,
  raid_id bigint not null references public.raids (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  seed bigint not null,
  teams jsonb not null,
  battle_id bigint references public.battles (id) on delete set null,
  state text not null default 'open' check (state in ('open', 'submitted', 'done', 'expired')),
  damage int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists raid_attempts_user on public.raid_attempts (user_id, created_at);
alter table public.raids enable row level security;
alter table public.raid_members enable row level security;
alter table public.raid_attempts enable row level security;
revoke all on public.raids, public.raid_members, public.raid_attempts from public, anon, authenticated, chimora_referee;

create or replace function public._raid_check(u uuid) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if not public._flag_on('raid', 2147483647) then return 'feature_off'; end if;
  if not public._social(u) then return 'social_off'; end if;
  if public._cheat_held(u) then return 'under_review'; end if;
  return null;
end $$;

-- Strength by party size (2850): 2 players 100 %, 3 players 140 %, 4 players 175 %.
create or replace function public._raid_hp(p_players int) returns int
language sql stable as $$
  select (public._config_int('raid_base', 1200) * case p_players when 2 then 100 when 3 then 140 else 175 end / 100)::int
$$;

create or replace function public._raid_expect(a public.raid_attempts) returns jsonb
language sql stable as $$
  select jsonb_build_object('seed', a.seed, 'teams', a.teams, 'ai', public._config_int('league_ai', 2),
    'wild', false, 'front', jsonb_build_array(1, 1), 'items_allowed', false,
    'round_limit', public._config_int('raid_rounds', 10))
$$;

-- Open a Rift with 1 to 3 others (friends or members of the own bund, never blocked).
create or replace function public.raid_open(p_codes jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._raid_check(u);
  c jsonb;
  t uuid;
  who uuid[] := array[u];
  g text;
  r bigint;
  hp int;
begin
  if e is not null then return public._fail(e); end if;
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
  -- Old Rifts go away 7 days after they closed, with members and attempts.
  delete from public.raids where closes_at < now() - interval '7 days';
  select x #>> '{}' into g from jsonb_array_elements(public._config('raid_guardians', '[]')) x
  where exists (select 1 from public.game_species s where s.name = x #>> '{}') order by random() limit 1;
  if g is null then return public._fail('no_guardian'); end if;
  hp := public._raid_hp(array_length(who, 1));
  insert into public.raids (guardian, level, players, hp_total, hp_left, closes_at)
  values (g, public._config_int('raid_level', 60), array_length(who, 1), hp, hp,
    now() + make_interval(hours => public._config_int('raid_hours', 48)))
  returning id into r;
  insert into public.raid_members (raid_id, user_id) select r, x from unnest(who) x;
  return jsonb_build_object('ok', true, 'raid', r);
end $$;

-- The caller's raids of the last 7 days with strength, damage per member, attempts left today and
-- the reward table (2851: the table is open, the game shows it).
create or replace function public.raid_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._raid_check(u);
  tries int := public._config_int('raid_tries', 3);
begin
  if e is not null then return public._fail(e); end if;
  return jsonb_build_object('ok', true, 'rewards', public._config('raid_rewards', '[]'), 'tries', tries,
    'share_min', public._config_int('raid_share_min', 5), 'rounds', public._config_int('raid_rounds', 10),
    'raids', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'guardian', r.guardian, 'level', r.level,
        'players', r.players, 'hp_total', r.hp_total, 'hp_left', r.hp_left,
        'closes_at', extract(epoch from r.closes_at)::bigint, 'open', r.hp_left > 0 and r.closes_at > now(),
        'won', r.won_at is not null,
        'tries_left', greatest(0, tries - (select count(*) from public.raid_attempts a where a.raid_id = r.id
          and a.user_id = u and a.created_at >= date_trunc('day', now()))),
        'reward', case when r.won_at is not null and me.damage * 100 >= r.hp_total * public._config_int('raid_share_min', 5)
          then r.reward end,
        'claimed', me.claimed,
        'members', (select jsonb_agg(jsonb_build_object('name', p.name, 'damage', m.damage, 'me', m.user_id = u)
          order by m.damage desc) from public.raid_members m join public.profiles p on p.id = m.user_id where m.raid_id = r.id))
      order by r.created_at desc)
      from public.raids r join public.raid_members me on me.raid_id = r.id and me.user_id = u
      where r.created_at > now() - interval '7 days'), '[]'::jsonb));
end $$;

-- Start an attempt: the server sets seed and both teams (the fair league team rules: Ring 50,
-- base stats) and the round limit. The game builds the battle from the answer.
create or replace function public.raid_start(p_raid bigint, p_pick jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  e text := public._raid_check(u);
  r public.raids;
  team jsonb;
  a public.raid_attempts;
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
  team := public._league_team(u, 'fair', p_pick);
  if team ? 'error' then return public._fail(team->>'error'); end if;
  update public.raid_attempts set state = 'expired' where user_id = u and state = 'open';
  insert into public.raid_attempts (raid_id, user_id, seed, teams)
  values (p_raid, u, floor(random() * 2147483647)::bigint, jsonb_build_array(team->'team',
    jsonb_build_array(jsonb_build_object('species', r.guardian, 'level', r.level,
      'moves', public._league_default_moves(r.guardian, r.level)))))
  returning * into a;
  return jsonb_build_object('ok', true, 'attempt_id', a.id) || public._raid_expect(a);
end $$;

-- The reward, once per member who dealt at least raid_share_min percent.
create or replace function public.raid_claim(p_raid bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  r public.raids;
  m public.raid_members;
begin
  select * into r from public.raids where id = p_raid;
  select * into m from public.raid_members where raid_id = p_raid and user_id = u for update;
  if r.id is null or m.raid_id is null then return public._fail('no_such_raid'); end if;
  if r.won_at is null or m.damage * 100 < r.hp_total * public._config_int('raid_share_min', 5) then
    return public._fail('no_reward');
  end if;
  if m.claimed then return public._fail('claimed'); end if;
  update public.raid_members set claimed = true where raid_id = p_raid and user_id = u;
  return jsonb_build_object('ok', true, 'item', r.reward->>'item', 'count', coalesce((r.reward->>'count')::int, 1));
end $$;

-- A checked raid battle takes its damage off the guardian; never below zero, two results at
-- the same time add up (row lock on the raid).
create or replace function public._raid_apply(p_battle_id bigint, p_ok boolean, p_detail jsonb) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  a public.raid_attempts;
  r public.raids;
  d int;
  tbl jsonb;
  total int;
  roll int;
  acc int := 0;
  x jsonb;
begin
  select * into a from public.raid_attempts where battle_id = p_battle_id and state = 'submitted' for update;
  if not found then return; end if;
  select * into r from public.raids where id = a.raid_id for update;
  d := case when p_ok then least(greatest(coalesce((p_detail->>'foe_damage')::int, 0), 0), r.hp_left) else 0 end;
  update public.raid_attempts set state = 'done', damage = d where id = a.id;
  if d = 0 then return; end if;
  update public.raid_members set damage = damage + d where raid_id = r.id and user_id = a.user_id;
  update public.raids set hp_left = hp_left - d where id = r.id;
  if r.hp_left - d = 0 then
    tbl := public._config('raid_rewards', '[]');
    select coalesce(sum((y->>'w')::int), 0) into total from jsonb_array_elements(tbl) y;
    if total > 0 then
      roll := floor(random() * total)::int;
      for x in select * from jsonb_array_elements(tbl) loop
        acc := acc + (x->>'w')::int;
        if roll < acc then exit; end if;
      end loop;
    end if;
    update public.raids set won_at = now(), reward = x - 'w' where id = r.id;
  end if;
end $$;

-- battle_submit with raids: the ref is the attempt id, and the claim gets the server's own setup.
create or replace function public.battle_submit(p_kind text, p_ref text, p_replay jsonb, p_claim jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  b bigint;
  m public.league_matches;
  a public.raid_attempts;
  claim jsonb;
  ref_id bigint := case when coalesce(p_ref, '') ~ '^[0-9]{1,18}$' then p_ref::bigint else -1 end;
begin
  perform public._ensure_profile(u);
  if p_kind is null or p_kind not in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel') then
    return public._fail('bad_kind');
  end if;
  if jsonb_typeof(p_replay) is distinct from 'object' or jsonb_typeof(p_claim) is distinct from 'object'
     or pg_column_size(p_replay) > 200000 or pg_column_size(p_claim) > 4000
     or jsonb_typeof(p_replay->'teams') is distinct from 'array'
     or jsonb_array_length(coalesce(p_replay->'inputs', '[]'::jsonb)) > 400 then
    return public._fail('bad_battle');
  end if;
  if not public._rate_ok(u, 'battle', public._config_int('battle_submit_limit', 60)) then
    return public._fail('slow_down');
  end if;
  claim := p_claim - 'expect';
  if p_kind in ('league_fair', 'league_open') then
    select * into m from public.league_matches
    where id = ref_id and user_id = u and league = substr(p_kind, 8) for update;
    if not found then return public._fail('no_such_match'); end if;
    if m.state <> 'open' or m.created_at < now() - make_interval(mins => public._config_int('league_match_minutes', 30)) then
      return public._fail('match_closed');
    end if;
    claim := claim || jsonb_build_object('expect', public._league_expect(m));
  elsif p_kind = 'raid' then
    select * into a from public.raid_attempts where id = ref_id and user_id = u for update;
    if not found then return public._fail('no_such_attempt'); end if;
    if a.state <> 'open' or a.created_at < now() - interval '30 minutes' then return public._fail('attempt_closed'); end if;
    claim := claim || jsonb_build_object('expect', public._raid_expect(a));
  end if;
  insert into public.battles (user_id, kind, ref) values (u, p_kind, left(coalesce(p_ref, ''), 40))
  returning id into b;
  if m.id is not null then
    update public.league_matches set state = 'submitted', battle_id = b,
      rated = rated and public._league_state((select s from public.league_seasons s where s.id = m.season)) = 'running'
    where id = m.id;
  end if;
  if a.id is not null then
    update public.raid_attempts set state = 'submitted', battle_id = b where id = a.id;
  end if;
  perform public._referee_check(b, p_replay, claim);
  return jsonb_build_object('ok', true, 'battle_id', b, 'status', 'pending');
end $$;

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
  end if;
  return new;
end $$;

revoke all on function public._raid_check(uuid), public._raid_hp(int), public._raid_expect(public.raid_attempts),
  public._raid_apply(bigint, boolean, jsonb), public._battle_result_in() from public, anon, authenticated, chimora_referee;
revoke all on function public.raid_open(jsonb), public.raid_list(), public.raid_start(bigint, jsonb), public.raid_claim(bigint),
  public.battle_submit(text, text, jsonb, jsonb) from public, anon, chimora_referee;
grant execute on function public.raid_open(jsonb), public.raid_list(), public.raid_start(bigint, jsonb), public.raid_claim(bigint),
  public.battle_submit(text, text, jsonb, jsonb) to authenticated;
