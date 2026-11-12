-- Online 100, area 5: a gift wish list (46), two gifts a day from friendship level 3 (47), a
-- thank-you that gives both a friendship point once a day (49), and the trade history of the last
-- 30 days (50). Values in server_config.gift_rules (data/gift_rules.json); LocalBackend does the same.

alter table public.profiles add column if not exists wishes jsonb not null default '[]'::jsonb;

create or replace function public._gift_rule(p_key text) returns int
language sql stable as $$
  select coalesce((public._config('gift_rules', '{}'::jsonb)->>p_key)::int,
    ('{"two_gifts_level": 3, "thanks_points": 1, "wish_max": 3, "history_days": 30}'::jsonb->>p_key)::int)
$$;

create or replace function public._pair_points(x uuid, y uuid) returns int
language sql stable as $$
  select coalesce((select points from public.friendships where a = least(x, y) and b = greatest(x, y) and status = 'accepted'), 0)
$$;

create or replace function public.gift_send(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  allowed int;
begin
  if t is null or not public._friends(u, t) or public._blocked(u, t) or not public._social(u) or not public._social(t) then
    return public._fail('not_friends');
  end if;
  allowed := case when public._level(public._pair_points(u, t)) >= public._gift_rule('two_gifts_level') then 2 else 1 end;
  if (select count(*) from public.mail where sender = u and recipient = t and kind = 'gift'
      and (created_at at time zone 'utc')::date = public._today()) >= allowed then
    return public._fail('already_today');
  end if;
  insert into public.mail (sender, recipient, kind, place, motif)
    select u, t, 'gift', p.place, p.card->>'motif' from public.profiles p where p.id = u;
  perform public._add_points(u, t, 1);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.mail_send(p_code text, p_kind text, p_phrase int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  bonus boolean := false;
begin
  if p_kind not in ('phrase', 'wave', 'thanks') then return public._fail('bad_kind'); end if;
  if t is null or not public._friends(u, t) or public._blocked(u, t) or not public._social(u) or not public._social(t) then
    return public._fail('not_friends');
  end if;
  if coalesce(p_phrase, -1) not between 0 and 31
     or (p_kind = 'phrase' and not public._phrase_ok('post', p_phrase)) then
    return public._fail('bad_phrase');
  end if;
  if not public._rate_ok(u, 'mail', 30) then return public._fail('slow_down'); end if;
  -- The first thanks of the day for a gift from them: a friendship point for the pair.
  if p_kind = 'thanks' and exists (select 1 from public.mail where sender = t and recipient = u and kind = 'gift'
      and created_at > now() - interval '7 days')
     and not exists (select 1 from public.mail where sender = u and recipient = t and kind = 'thanks'
      and (created_at at time zone 'utc')::date = public._today()) then
    bonus := true;
  end if;
  insert into public.mail (sender, recipient, kind, phrase, place)
  values (u, t, p_kind, p_phrase, (select place from public.profiles where id = u));
  if bonus then perform public._add_points(u, t, public._gift_rule('thanks_points')); end if;
  return jsonb_build_object('ok', true, 'bonus', bonus);
end $$;

-- Up to wish_max items from the open gift table.
create or replace function public.wish_set(p_items jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._ensure_profile(u);
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) > public._gift_rule('wish_max')
     or exists (select 1 from jsonb_array_elements(p_items) x where jsonb_typeof(x) <> 'string'
       or not exists (select 1 from jsonb_array_elements(public._config('gift_table', '[]')) g where g->>'item' = x #>> '{}'))
     or (select count(distinct x) from jsonb_array_elements(p_items) x) <> jsonb_array_length(p_items) then
    return public._fail('bad_wish');
  end if;
  update public.profiles set wishes = p_items where id = u;
  return jsonb_build_object('ok', true);
end $$;

-- A friend's wish list (or the own one with the own code).
create or replace function public.wish_get(p_code text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or (t <> u and (not public._friends(u, t) or public._blocked(u, t))) then return public._fail('not_friends'); end if;
  return jsonb_build_object('ok', true, 'wishes', (select wishes from public.profiles where id = t));
end $$;

-- Finished trades of the last history_days days: date, the other side's name, given and got items.
create or replace function public.trade_history() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  return jsonb_build_object('ok', true, 'trades', coalesce((select jsonb_agg(jsonb_build_object(
      'at', extract(epoch from t.done_at)::bigint, 'name', p.name, 'gave', mine.items, 'got', theirs.items,
      'gave_mons', jsonb_array_length(coalesce(mine.mons, '[]'::jsonb)), 'got_mons', jsonb_array_length(coalesce(theirs.mons, '[]'::jsonb)))
      order by t.done_at desc)
    from public.trades t
    join public.trade_sides mine on mine.trade_id = t.id and mine.user_id = u
    join public.trade_sides theirs on theirs.trade_id = t.id and theirs.user_id <> u
    join public.profiles p on p.id = theirs.user_id
    where t.state = 'done' and t.done_at > now() - make_interval(days => public._gift_rule('history_days'))), '[]'::jsonb));
end $$;

revoke all on function public._gift_rule(text), public._pair_points(uuid, uuid) from public, anon, authenticated, chimora_referee;
revoke all on function public.gift_send(text), public.mail_send(text, text, int), public.wish_set(jsonb), public.wish_get(text),
  public.trade_history() from public, anon, chimora_referee;
grant execute on function public.gift_send(text), public.mail_send(text, text, int), public.wish_set(jsonb), public.wish_get(text),
  public.trade_history() to authenticated;
