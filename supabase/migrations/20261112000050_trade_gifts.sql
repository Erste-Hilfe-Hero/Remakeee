-- Online 100, area 5 (points 41-50): trading and gifting between friends. Builds on the item and
-- Spirling trades (20261110000012_trades.sql, 20261111000002_online_step1.sql) and Lantern Mail.
--   42  at most trades_per_day finished trades per player and server day
--   45  lend a Spirling to a friend for one raid or one live duel (flag "lend", off at first): a copy
--       without nickname or Keepsake, the original stays in the lender's journey
--   46  a wish list of up to wish_max items that friends see
--   47  two gifts a day to a friend from friendship level close_level (else one)
--   48  greeting cards with a Spirling motif: a set phrase plus a species from the sender's journey
--   49  thanks for a gift: once per gift, thanks_points friendship points for the pair
--   50  trade history of the last history_days days
-- Values in server_config.trade_gifts (data/trade_gifts.json). LocalBackend does the same
-- (scripts/online/LocalTradeGifts.gd). Re-runnable.

insert into public.feature_flags (key, enabled, min_version, note) values
  ('lend', false, 1, 'Spirlings an Freunde ausleihen')
on conflict (key) do nothing;

create or replace function public._tg_cfg(p_key text) returns int
language sql stable as $$
  select coalesce((public._config('trade_gifts', '{}'::jsonb)->>p_key)::int,
    ('{"trades_per_day": 5, "history_days": 30, "gifts_per_day": 1, "gifts_per_day_close": 2, "close_level": 3,
      "wish_max": 3, "cards_per_day": 10, "thanks_points": 2, "lend_min_level": 3, "lend_hours": 48,
      "lends_per_day": 3, "borrow_max": 1}'::jsonb->>p_key)::int)
$$;

-- ---------------------------------------------------------------------------------------
-- 42, 50: trade limit per day and trade history

create table if not exists public.trade_log (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  partner uuid references auth.users (id) on delete set null,
  gave jsonb not null default '{}'::jsonb,
  got jsonb not null default '{}'::jsonb,
  -- Spirlings only as species, Ring and era: no uid, no values.
  gave_mons jsonb not null default '[]'::jsonb,
  got_mons jsonb not null default '[]'::jsonb,
  done_at timestamptz not null default now()
);
create index if not exists trade_log_user on public.trade_log (user_id, done_at desc);
alter table public.trade_log enable row level security;
revoke all on public.trade_log from public, anon, authenticated, chimora_referee;
revoke all on sequence public.trade_log_id_seq from public, anon, authenticated;

create or replace function public._tg_mons(p jsonb) returns jsonb
language sql immutable as $$
  select coalesce(jsonb_agg(jsonb_build_object('species', x->>'species', 'level', coalesce((x->>'level')::numeric::int, 1),
    'origin_era', coalesce((x->>'origin_era')::numeric::int, 1))), '[]'::jsonb)
  from jsonb_array_elements(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) x
$$;

-- Finished trades of [u] this server day.
create or replace function public._trades_today(u uuid) returns int
language sql stable as $$
  select count(*)::int from public.trade_log where user_id = u and (done_at at time zone 'utc')::date = public._today()
$$;

-- The trade_confirm of online step 1, plus the day limit and a history row for each side.
create or replace function public.trade_confirm(p_trade bigint, p_theirs jsonb, p_their_mons text[]) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  why text := public._trade_check(u);
  m public.trade_sides;
  o public.trade_sides;
  lim int := public._tg_cfg('trades_per_day');
begin
  if why is not null then return public._fail(why); end if;
  perform public._trade_tidy();
  select x.* into m from public.trade_sides x join public.trades t on t.id = x.trade_id
  where x.trade_id = p_trade and x.user_id = u and t.state = 'open' for update of t;
  if not found then return public._fail('no_such_trade'); end if;
  select * into o from public.trade_sides where trade_id = p_trade and user_id <> u;
  if not found or public._trade_pair(u, o.user_id) is not null then return public._fail('partner_gone'); end if;
  if o.items is distinct from coalesce(public._trade_offer(p_theirs), '{}'::jsonb)
     or public._trade_uids(o.mons) is distinct from
       coalesce((select array_agg(x order by x) from unnest(coalesce(p_their_mons, '{}'::text[])) x), '{}'::text[]) then
    return public._fail('changed');
  end if;
  if m.items = '{}'::jsonb and o.items = '{}'::jsonb and m.mons = '[]'::jsonb and o.mons = '[]'::jsonb then
    return public._fail('empty');
  end if;
  if public._trades_today(u) >= lim then return public._fail('day_limit'); end if;
  if o.confirmed and public._trades_today(o.user_id) >= lim then return public._fail('their_day_limit'); end if;
  update public.trade_sides set confirmed = true where trade_id = p_trade and user_id = u;
  if o.confirmed then
    update public.trade_sides x set receive = y.items, receive_mons = y.mons from public.trade_sides y
    where x.trade_id = p_trade and y.trade_id = p_trade and x.user_id <> y.user_id;
    update public.trades set state = 'done', done_at = now() where id = p_trade;
    insert into public.trade_log (user_id, partner, gave, got, gave_mons, got_mons) values
      (u, o.user_id, m.items, o.items, public._tg_mons(m.mons), public._tg_mons(o.mons)),
      (o.user_id, u, o.items, m.items, public._tg_mons(o.mons), public._tg_mons(m.mons));
    return jsonb_build_object('ok', true, 'done', true);
  end if;
  return jsonb_build_object('ok', true, 'done', false);
end $$;

-- The caller's finished trades of the last history_days days, newest first.
create or replace function public.trade_history() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  delete from public.trade_log where user_id = u and done_at < now() - make_interval(days => public._tg_cfg('history_days'));
  return jsonb_build_object('ok', true, 'today', public._trades_today(u), 'per_day', public._tg_cfg('trades_per_day'),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('at', extract(epoch from l.done_at)::bigint,
        'name', case when p.id is not null and not public._blocked(u, p.id) then p.name end,
        'gave', l.gave, 'got', l.got, 'gave_mons', l.gave_mons, 'got_mons', l.got_mons) order by l.done_at desc, l.id desc)
      from public.trade_log l left join public.profiles p on p.id = l.partner
      where l.user_id = u), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------------------
-- 46: wish list

alter table public.profiles add column if not exists wishes jsonb not null default '[]'::jsonb;

-- Items a wish may name: what a gift can hold and what can be traded.
create or replace function public._wishable() returns jsonb
language sql stable as $$
  select coalesce((select jsonb_agg(distinct x) from (
    select e->>'item' as x from jsonb_array_elements(public._config('gift_table', '[]')) e
    union select jsonb_array_elements_text(coalesce(public._config('trade_items', '[]'), '[]'::jsonb))) s
    where x is not null), '[]'::jsonb)
$$;

create or replace function public.wish_set(p_items jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  ok jsonb := public._wishable();
  clean jsonb := '[]'::jsonb;
  x jsonb;
begin
  perform public._ensure_profile(u);
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) > public._tg_cfg('wish_max') then
    return public._fail('bad_wish');
  end if;
  for x in select * from jsonb_array_elements(p_items) loop
    if jsonb_typeof(x) <> 'string' or not ok @> jsonb_build_array(x) or clean @> jsonb_build_array(x) then
      return public._fail('bad_wish');
    end if;
    clean := clean || jsonb_build_array(x);
  end loop;
  update public.profiles set wishes = clean where id = u;
  return jsonb_build_object('ok', true, 'wishes', clean);
end $$;

create or replace function public.wish_get() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._ensure_profile(u);
  return jsonb_build_object('ok', true, 'wishes', (select wishes from public.profiles where id = u),
    'items', public._wishable(), 'max', public._tg_cfg('wish_max'));
end $$;

-- ---------------------------------------------------------------------------------------
-- 47: two gifts a day from friendship level 3

-- Gifts [u] may still send [t] today.
create or replace function public._gifts_left(u uuid, t uuid) returns int
language sql stable as $$
  select greatest(0, (case when public._level(coalesce((select points from public.friendships
      where a = least(u, t) and b = greatest(u, t) and status = 'accepted'), 0)) >= public._tg_cfg('close_level')
    then public._tg_cfg('gifts_per_day_close') else public._tg_cfg('gifts_per_day') end)
    - (select count(*)::int from public.mail where sender = u and recipient = t and kind = 'gift'
      and (created_at at time zone 'utc')::date = public._today()))
$$;

create or replace function public.gift_send(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or not public._friends(u, t) or public._blocked(u, t) or not public._social(u) or not public._social(t) then
    return public._fail('not_friends');
  end if;
  if public._gifts_left(u, t) <= 0 then return public._fail('already_today'); end if;
  insert into public.mail (sender, recipient, kind, place, motif)
    select u, t, 'gift', p.place, p.card->>'motif' from public.profiles p where p.id = u;
  perform public._add_points(u, t, 1);
  return jsonb_build_object('ok', true, 'left', public._gifts_left(u, t));
end $$;

-- friends_list as before, plus each friend's wish list and the gifts left for them today.
create or replace function public.friends_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._ensure_profile(u);
  return jsonb_build_object(
    'friends', coalesce((select jsonb_agg(jsonb_build_object(
        'code', p.code, 'name', p.name, 'color', p.color, 'favorite', p.favorite, 'card', p.card,
        'place', p.place, 'online', p.last_seen > now() - interval '5 minutes',
        'last_seen', extract(epoch from p.last_seen)::bigint,
        'points', f.points, 'level', public._level(f.points),
        'has_team', jsonb_array_length(p.team) > 0,
        'wishes', p.wishes,
        'gifts_left', public._gifts_left(u, p.id),
        'gift_sent', public._gifts_left(u, p.id) = 0)
      order by p.last_seen desc)
      from public.friendships f join public.profiles p on p.id = case when f.a = u then f.b else f.a end
      where (f.a = u or f.b = u) and f.status = 'accepted'), '[]'::jsonb),
    'incoming', coalesce((select jsonb_agg(jsonb_build_object('code', p.code, 'name', p.name))
      from public.friendships f join public.profiles p on p.id = f.requested_by
      where (f.a = u or f.b = u) and f.status = 'pending' and f.requested_by <> u), '[]'::jsonb),
    'outgoing', coalesce((select jsonb_agg(jsonb_build_object('code', p.code, 'name', p.name))
      from public.friendships f join public.profiles p on p.id = case when f.a = u then f.b else f.a end
      where (f.a = u or f.b = u) and f.status = 'pending' and f.requested_by = u), '[]'::jsonb),
    'blocked', coalesce((select jsonb_agg(jsonb_build_object('code', p.code, 'name', p.name))
      from public.blocks bl join public.profiles p on p.id = bl.blocked where bl.blocker = u), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------------------
-- 48, 49: greeting cards with a Spirling motif, thanks for a gift

alter table public.mail drop constraint if exists mail_kind_check;
alter table public.mail add constraint mail_kind_check
  check (kind in ('phrase', 'wave', 'thanks', 'gift', 'echo', 'duel', 'card'));
alter table public.mail add column if not exists species text;
alter table public.mail add column if not exists thanked boolean not null default false;

-- True when a Spirling of [p_species] is in the team or storage of one of [u]'s stored saves.
create or replace function public._has_species(u uuid, p_species text) returns boolean
language sql stable as $$
  select exists (select 1 from public.saves s,
      jsonb_array_elements(case when jsonb_typeof(s.data->'party') = 'array' then s.data->'party' else '[]'::jsonb end
        || case when jsonb_typeof(s.data->'storage') = 'array' then s.data->'storage' else '[]'::jsonb end) x
    where s.user_id = u and x->>'species' = p_species)
$$;

create or replace function public.card_send(p_code text, p_species text, p_phrase int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or not public._friends(u, t) or public._blocked(u, t) or not public._social(u) or not public._social(t) then
    return public._fail('not_friends');
  end if;
  if not public._phrase_ok('post', p_phrase) then return public._fail('bad_phrase'); end if;
  if coalesce(p_species, '') !~ '^[[:alnum:]]{1,20}$' or not public._has_species(u, p_species) then
    return public._fail('no_species');
  end if;
  if (select count(*) from public.mail where sender = u and kind = 'card'
      and (created_at at time zone 'utc')::date = public._today()) >= public._tg_cfg('cards_per_day') then
    return public._fail('cards_today');
  end if;
  if not public._rate_ok(u, 'mail', 30) then return public._fail('slow_down'); end if;
  insert into public.mail (sender, recipient, kind, phrase, species, place)
  values (u, t, 'card', p_phrase, p_species, (select place from public.profiles where id = u));
  return jsonb_build_object('ok', true);
end $$;

-- Thanks for gift [p_id]: once per opened gift; the friend gets a thanks note and the pair
-- thanks_points friendship points.
create or replace function public.gift_thank(p_id bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  m public.mail;
  n int := public._tg_cfg('thanks_points');
begin
  select * into m from public.mail where id = p_id and recipient = u and kind = 'gift' for update;
  if not found then return public._fail('no_such_gift'); end if;
  if not m.opened then return public._fail('open_first'); end if;
  if m.thanked then return public._fail('already'); end if;
  if not public._friends(u, m.sender) or public._blocked(u, m.sender) or not public._social(u) or not public._social(m.sender) then
    return public._fail('not_friends');
  end if;
  update public.mail set thanked = true where id = m.id;
  insert into public.mail (sender, recipient, kind, phrase, place)
  values (u, m.sender, 'thanks', 1, (select place from public.profiles where id = u));
  perform public._add_points(u, m.sender, n);
  return jsonb_build_object('ok', true, 'points', n);
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
          'code', p.code, 'name', p.name, 'motif', coalesce(m.motif, ''),
          'species', coalesce(m.species, ''), 'thanked', m.thanked) as r, m.created_at
      from public.mail m join public.profiles p on p.id = m.sender
      where m.recipient = u
      order by m.created_at desc limit 50) x), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------------------------
-- 45: lend a Spirling for one raid or one live duel

create table if not exists public.spirling_loans (
  id bigserial primary key,
  lender uuid not null references auth.users (id) on delete cascade,
  borrower uuid not null references auth.users (id) on delete cascade,
  -- The copy that travels: no nickname, box, favourite mark or Keepsake.
  mon jsonb not null,
  src_uid text not null,
  state text not null default 'lent' check (state in ('lent', 'used')),
  used_for text,
  created_at timestamptz not null default now(),
  ends_at timestamptz not null
);
create index if not exists spirling_loans_lender on public.spirling_loans (lender, created_at desc);
create index if not exists spirling_loans_borrower on public.spirling_loans (borrower, state);
alter table public.spirling_loans enable row level security;
revoke all on public.spirling_loans from public, anon, authenticated, chimora_referee;
revoke all on sequence public.spirling_loans_id_seq from public, anon, authenticated;

-- Loans end after lend_hours, used or not (a used one still counts for lends_per_day until then).
create or replace function public._lend_tidy() returns void
language sql volatile as $$
  delete from public.spirling_loans where ends_at < now();
$$;

-- Why [x] cannot lend to [y], or null.
create or replace function public._lend_pair(x uuid, y uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare f public.friendships;
begin
  if x is null or y is null or x = y or public._blocked(x, y) or not public._social(y) then return 'not_friends'; end if;
  select * into f from public.friendships where a = least(x, y) and b = greatest(x, y) and status = 'accepted';
  if not found then return 'not_friends'; end if;
  if public._level(f.points) < public._tg_cfg('lend_min_level') then return 'friend_level'; end if;
  return null;
end $$;

create or replace function public.lend_offer(p_code text, p_slot int, p_uid text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  why text;
  s public.saves;
  hit jsonb;
  r bigint;
begin
  if not public._flag_on('lend', 2147483647) then return public._fail('feature_off'); end if;
  if not public._social(u) then return public._fail('social_off'); end if;
  if public._cheat_held(u) then return public._fail('under_review'); end if;
  why := public._lend_pair(u, t);
  if why is not null then return public._fail(why); end if;
  perform public._lend_tidy();
  select * into s from public.saves where user_id = u and slot = p_slot;
  if not found then return public._fail('no_save'); end if;
  select x into hit from jsonb_array_elements(
    case when jsonb_typeof(s.data->'party') = 'array' then s.data->'party' else '[]'::jsonb end
    || case when jsonb_typeof(s.data->'storage') = 'array' then s.data->'storage' else '[]'::jsonb end) x
  where x->>'uid' = p_uid limit 1;
  if hit is null then return public._fail('no_spirling'); end if;
  why := public._trade_mon_why(hit - 'held' - 'favorite');
  if why is not null then return public._fail(why); end if;
  if exists (select 1 from public.spirling_loans where lender = u and src_uid = p_uid and state = 'lent') then
    return public._fail('already_lent');
  end if;
  if (select count(*) from public.spirling_loans where lender = u
      and (created_at at time zone 'utc')::date = public._today()) >= public._tg_cfg('lends_per_day') then
    return public._fail('lends_today');
  end if;
  if (select count(*) from public.spirling_loans where borrower = t and state = 'lent') >= public._tg_cfg('borrow_max') then
    return public._fail('friend_has_one');
  end if;
  insert into public.spirling_loans (lender, borrower, mon, src_uid, ends_at)
  values (u, t, public._trade_mon_clean(hit - 'held') - 'uid' || jsonb_build_object('uid', 'loan_' || p_uid), p_uid,
    now() + make_interval(hours => public._tg_cfg('lend_hours')))
  returning id into r;
  return jsonb_build_object('ok', true, 'loan', r);
end $$;

create or replace function public.lend_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  perform public._lend_tidy();
  return jsonb_build_object('ok', true,
    'lent', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'state', l.state, 'used_for', l.used_for,
        'ends_at', extract(epoch from l.ends_at)::bigint, 'mon', l.mon,
        'name', case when not public._blocked(u, l.borrower) then p.name end) order by l.id desc)
      from public.spirling_loans l join public.profiles p on p.id = l.borrower where l.lender = u), '[]'::jsonb),
    'borrowed', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'state', l.state, 'used_for', l.used_for,
        'ends_at', extract(epoch from l.ends_at)::bigint, 'mon', l.mon,
        'name', case when not public._blocked(u, l.lender) then p.name end) order by l.id desc)
      from public.spirling_loans l join public.profiles p on p.id = l.lender
      where l.borrower = u and not public._blocked(u, l.lender)), '[]'::jsonb));
end $$;

-- The borrower takes the lent Spirling into one raid attempt or one live duel; the answer carries
-- the copy. After that the loan is used up.
create or replace function public.lend_use(p_loan bigint, p_kind text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  l public.spirling_loans;
begin
  if not public._flag_on('lend', 2147483647) then return public._fail('feature_off'); end if;
  if p_kind not in ('raid', 'live_duel') then return public._fail('bad_kind'); end if;
  perform public._lend_tidy();
  select * into l from public.spirling_loans where id = p_loan and borrower = u for update;
  if not found or public._blocked(u, l.lender) then return public._fail('no_such_loan'); end if;
  if l.state <> 'lent' then return public._fail('used'); end if;
  update public.spirling_loans set state = 'used', used_for = p_kind where id = l.id;
  return jsonb_build_object('ok', true, 'mon', l.mon);
end $$;

-- Either side ends a loan that was not used yet.
create or replace function public.lend_end(p_loan bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  delete from public.spirling_loans where id = p_loan and (lender = u or borrower = u) and state = 'lent';
  if not found then return public._fail('no_such_loan'); end if;
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public._tg_cfg(text), public._tg_mons(jsonb), public._trades_today(uuid), public._wishable(),
  public._gifts_left(uuid, uuid), public._has_species(uuid, text), public._lend_tidy(), public._lend_pair(uuid, uuid)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.trade_confirm(bigint, jsonb, text[]), public.trade_history(), public.wish_set(jsonb),
  public.wish_get(), public.gift_send(text), public.friends_list(), public.card_send(text, text, int),
  public.gift_thank(bigint), public.mail_list(), public.lend_offer(text, int, text), public.lend_list(),
  public.lend_use(bigint, text), public.lend_end(bigint)
  from public, anon, chimora_referee;
grant execute on function public.trade_confirm(bigint, jsonb, text[]), public.trade_history(), public.wish_set(jsonb),
  public.wish_get(), public.gift_send(text), public.friends_list(), public.card_send(text, text, int),
  public.gift_thank(bigint), public.mail_list(), public.lend_offer(text, int, text), public.lend_list(),
  public.lend_use(bigint, text), public.lend_end(bigint)
  to authenticated;
