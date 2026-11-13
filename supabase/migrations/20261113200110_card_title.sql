-- KAMPF_PLAN_1000 (Endgame-Kampfmodi, Online-Kämpfe): a title on the Wanderer card. The game sends
-- "title" in p_card; the server keeps it only when it is one of the game's titles, loaded at every
-- deploy from data/battle_halls.json "card_titles" into known_ids (kind 'title') by
-- tools/online/game_data_sql.py. No free text: an unknown title, or any title before the first
-- data load, is dropped. Same rule in scripts/online/LocalBackend.gd (_fn_profile_set).

alter table public.known_ids drop constraint if exists known_ids_kind_check;
alter table public.known_ids add constraint known_ids_kind_check check (kind in ('species', 'move', 'item', 'rift', 'title'));

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
