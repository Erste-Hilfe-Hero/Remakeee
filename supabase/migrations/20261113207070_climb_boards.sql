-- KAMPF_PLAN_1000 (Schwierigkeit und Herausforderungen, Wayfarer-Teams):
-- 493: the number of challenge rules a journey runs with goes on the Wanderer card ("rules", 0..20).
-- 512, 553: weekly climb boards for the lighthouse stair (kind 'stair', floors 0..30) and the echo
--   tower (kind 'tower', floors 0..1000). Best floor per player and week counts; names only for you
--   and your friends (public._board_json). Off until the 'climb_board' flag is switched on.
-- 543: Wayfarer wins join the world goal rotation (kind 'wayfarers').
-- Same rules in scripts/online/LocalBackend.gd and scripts/online/LocalClimb.gd. Re-runnable.

insert into public.feature_flags (key, enabled, min_version, note) values
  ('climb_board', false, 1, 'Wochenbestenliste Leuchtturm-Treppe und Echo-Turm')
on conflict (key) do nothing;

update public.server_config set value = value || '[{"kind":"wayfarers","target":1500}]'::jsonb
where key = 'goal_rotation' and jsonb_typeof(value) = 'array' and not value @> '[{"kind":"wayfarers"}]'::jsonb;

create table if not exists public.climb_scores (
  week text not null,
  kind text not null check (kind in ('stair', 'tower')),
  user_id uuid not null references auth.users (id) on delete cascade,
  floor int not null check (floor between 0 and 1000),
  at timestamptz not null default now(),
  primary key (week, kind, user_id)
);
alter table public.climb_scores enable row level security;
revoke all on public.climb_scores from public, anon, authenticated, chimora_referee;

-- Highest floor allowed for a climb kind, or null for an unknown kind.
create or replace function public._climb_max(p_kind text) returns int
language sql immutable as $$
  select case p_kind when 'stair' then 30 when 'tower' then 1000 end
$$;

create or replace function public.climb_submit(p_kind text, p_floor int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  w text := public._week();
begin
  if not public._flag_on('climb_board', 2147483647) then return public._fail('feature_off'); end if;
  if public._climb_max(p_kind) is null then return public._fail('bad_kind'); end if;
  if coalesce(p_floor, -1) not between 1 and public._climb_max(p_kind) then return public._fail('implausible'); end if;
  perform public._ensure_profile(u);
  if not public._rate_ok(u, 'climb', 60) then return public._fail('slow_down'); end if;
  delete from public.climb_scores where week < to_char((now() - interval '7 days') at time zone 'utc', 'IYYY-"W"IW');
  insert into public.climb_scores (week, kind, user_id, floor) values (w, p_kind, u, p_floor)
  on conflict (week, kind, user_id) do update set floor = greatest(public.climb_scores.floor, excluded.floor),
    at = case when excluded.floor > public.climb_scores.floor then now() else public.climb_scores.at end;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.climb_board(p_kind text, p_friends boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  w text := public._week();
begin
  if not public._flag_on('climb_board', 2147483647) then return public._fail('feature_off'); end if;
  if public._climb_max(p_kind) is null then return public._fail('bad_kind'); end if;
  return jsonb_build_object('ok', true, 'week', w, 'kind', p_kind, 'rows', public._board_json(u, coalesce((
    select jsonb_agg(jsonb_build_object('u', c.user_id, 'v', c.floor, 'at', extract(epoch from c.at)))
    from public.climb_scores c
    where c.week = w and c.kind = p_kind
      and (not coalesce(p_friends, true) or c.user_id = u or public._friends(u, c.user_id))
      and not public._blocked(u, c.user_id)), '[]'::jsonb), false));
end $$;

-- profile_set as in 20261113200110_card_title.sql, plus "rules" (493).
create or replace function public.profile_set(p_name text, p_color int, p_favorite text, p_card jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  p public.profiles := public._ensure_profile(u);
  clean jsonb := '{}'::jsonb;
  k text;
  fr text;
begin
  -- Only small whole numbers go on the card.
  foreach k in array array['seals', 'seen', 'bonded', 'hours', 'achievements'] loop
    if p_card ? k and jsonb_typeof(p_card->k) = 'number' then
      clean := clean || jsonb_build_object(k, least(greatest((p_card->>k)::numeric, 0), 99999)::int);
    end if;
  end loop;
  -- Challenge rules of the journey (KAMPF_PLAN_1000 item 493): a count, never their names.
  if p_card ? 'rules' and jsonb_typeof(p_card->'rules') = 'number' and (p_card->>'rules')::numeric >= 1 then
    clean := clean || jsonb_build_object('rules', least((p_card->>'rules')::numeric, 20)::int);
  end if;
  -- A bought profile frame (item 4284), checked against the account's unlocks.
  if p_card ? 'frame' and jsonb_typeof(p_card->'frame') = 'string' then
    fr := p_card->>'frame';
    if fr = any(array['leaf', 'shell', 'gear', 'star', 'ripple', 'ember'])
      and exists (select 1 from public.entitlements e where e.user_id = u and e.key = 'card_frame_' || fr) then
      clean := clean || jsonb_build_object('frame', fr);
    end if;
  end if;
  -- A bought greeting card motif for gifts (item 4285), the same way.
  if p_card ? 'motif' and jsonb_typeof(p_card->'motif') = 'string' then
    fr := p_card->>'motif';
    if fr = any(array['lantern', 'moth', 'wave', 'pine', 'kite', 'moon', 'shell', 'ember'])
      and exists (select 1 from public.entitlements e where e.user_id = u and e.key = 'gift_card_' || fr) then
      clean := clean || jsonb_build_object('motif', fr);
    end if;
  end if;
  -- A worn title, only from the game's list.
  if p_card ? 'title' and jsonb_typeof(p_card->'title') = 'string' then
    fr := p_card->>'title';
    if exists (select 1 from public.known_ids i where i.kind = 'title' and i.id = fr) then
      clean := clean || jsonb_build_object('title', fr);
    end if;
  end if;
  update public.profiles set
    name = public._clean_name(p_name, p.code),
    color = least(greatest(coalesce(p_color, 0), 0), 3),
    favorite = left(regexp_replace(coalesce(p_favorite, ''), '[^[:alnum:] ]', '', 'g'), 20),
    card = clean,
    last_seen = now()
  where id = u returning * into p;
  return public._profile_json(p);
end $$;

revoke all on function public._climb_max(text) from public, anon, authenticated, chimora_referee;
revoke all on function public.climb_submit(text, int), public.climb_board(text, boolean) from public, anon, chimora_referee;
grant execute on function public.climb_submit(text, int), public.climb_board(text, boolean) to authenticated;
