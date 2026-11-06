-- Plan area 7, items 2876-2878: set phrases per context and safer Wanderer names.
-- There is still no free text anywhere. Each place that shows set phrases has its own list of
-- allowed phrase numbers (phrases_allowed: post, duel, bund, raid; the same lists as
-- scripts/online/Phrases.gd CONTEXTS), so a menu phrase never turns up in a duel.
-- Names may hold at most 3 digits and nothing that looks like a web address, so nobody can pass on
-- a phone number or an account ("@" and dots were never allowed).

insert into public.server_config (key, value) values
  ('phrases_allowed', '{"post": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], "duel": [0, 1, 2, 3, 5, 12], "bund": [0, 1, 2, 4, 5, 6, 9, 10, 13, 14, 15], "raid": [0, 1, 2, 3, 14]}')
on conflict (key) do nothing;

-- True when phrase number [p_n] may be used in [p_context] (item 2877).
create or replace function public._phrase_ok(p_context text, p_n int) returns boolean
language sql stable security definer set search_path = public as $$
  select p_n is not null and coalesce(public._config('phrases_allowed', '{}')->p_context, '[]'::jsonb) @> to_jsonb(p_n)
$$;

-- A clean Wanderer name: 1-10 letters, digits or spaces, at most 3 digits, no web address and no
-- banned word (item 2878). Falls back to "Wanderer XXXX".
create or replace function public._clean_name(p_name text, p_code text) returns text
language plpgsql stable as $$
declare
  n text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  folded text;
begin
  if n = '' or length(n) > 10 or n !~ '^[[:alnum:] ]+$' then
    return 'Wanderer ' || right(p_code, 4);
  end if;
  if length(regexp_replace(n, '[^0-9]', '', 'g')) > 3 or lower(replace(n, ' ', '')) ~ '(www|http)' then
    return 'Wanderer ' || right(p_code, 4);
  end if;
  folded := lower(translate(n, '013457@$ ', 'oieastas'));
  if exists (select 1 from public.banned_words b where position(b.word in folded) > 0) then
    return 'Wanderer ' || right(p_code, 4);
  end if;
  return n;
end $$;

create or replace function public.mail_send(p_code text, p_kind text, p_phrase int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
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
  insert into public.mail (sender, recipient, kind, phrase, place)
  values (u, t, p_kind, p_phrase, (select place from public.profiles where id = u));
  return jsonb_build_object('ok', true);
end $$;

-- Names stored before these rules follow them now.
update public.profiles set name = public._clean_name(name, code) where name <> public._clean_name(name, code);

revoke all on function public._phrase_ok(text, int), public._clean_name(text, text) from public, anon, authenticated, chimora_referee;
revoke all on function public.mail_send(text, text, int) from public, anon;
grant execute on function public.mail_send(text, text, int) to authenticated;
