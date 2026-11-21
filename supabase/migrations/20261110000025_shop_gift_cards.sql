-- Chimora shop (plan area 10, item 4285): greeting card motifs for gifts to friends. The
-- sender picks a motif on their card ("motif", kept only with the unlock gift_card_<kind>);
-- gift_send stamps it on the gift and mail_list shows it to the friend. Only looks: the
-- gift itself is rolled as before.

alter table public.mail add column if not exists motif text;

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
  update public.profiles set
    name = public._clean_name(p_name, p.code),
    color = least(greatest(coalesce(p_color, 0), 0), 3),
    favorite = left(regexp_replace(coalesce(p_favorite, ''), '[^[:alnum:] ]', '', 'g'), 20),
    card = clean,
    last_seen = now()
  where id = u returning * into p;
  return public._profile_json(p);
end $$;

create or replace function public.gift_send(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or not public._friends(u, t) or public._blocked(u, t) or not public._social(u) or not public._social(t) then
    return public._fail('not_friends');
  end if;
  if exists (select 1 from public.mail where sender = u and recipient = t and kind = 'gift'
      and (created_at at time zone 'utc')::date = public._today()) then
    return public._fail('already_today');
  end if;
  insert into public.mail (sender, recipient, kind, place, motif)
    select u, t, 'gift', p.place, p.card->>'motif' from public.profiles p where p.id = u;
  perform public._add_points(u, t, 1);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.mail_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  -- Mail is kept for 30 days only (item 160).
  delete from public.mail where recipient = u and created_at < now() - interval '30 days';
  return coalesce((select jsonb_agg(r order by created_at desc) from (
      select jsonb_build_object('id', m.id, 'kind', m.kind, 'phrase', m.phrase, 'item', m.item,
          'place', m.place, 'opened', m.opened, 'at', extract(epoch from m.created_at)::bigint,
          'code', p.code, 'name', p.name, 'motif', coalesce(m.motif, '')) as r, m.created_at
      from public.mail m join public.profiles p on p.id = m.sender
      where m.recipient = u
      order by m.created_at desc limit 50) x), '[]'::jsonb);
end $$;
