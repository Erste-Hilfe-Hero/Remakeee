-- KAMPF_PLAN_1000 item 107: matchup notes travel by Lantern Mail. A Wayfarer sends a friend what
-- they learned about matchups ("element:species" -> multiplier seen on a hit); the friend opens the
-- mail and keeps the notes they did not have yet. One notes mail per friend and day, and the pair
-- gets friendship points for it (the Lantern Mail bonus). Values in server_config.matchup_notes
-- (data/matchup_notes.json); LocalMatchupNotes.gd does the same for the local stand-in server.

alter table public.mail drop constraint if exists mail_kind_check;
alter table public.mail add constraint mail_kind_check
  check (kind in ('phrase', 'wave', 'thanks', 'gift', 'echo', 'duel', 'card', 'notes'));
alter table public.mail add column if not exists notes jsonb;

create or replace function public._mn_cfg(p_key text) returns int
language sql stable as $$
  select coalesce((public._config('matchup_notes', '{}'::jsonb)->>p_key)::int,
    ('{"max_notes": 30, "per_friend_per_day": 1, "points": 1}'::jsonb->>p_key)::int)
$$;

-- True when [p_notes] is a non-empty object of at most max_notes entries "<element>:<Species>"
-- -> a multiplier between 0.25 and 4.
create or replace function public._mn_valid(p_notes jsonb) returns boolean
language plpgsql immutable as $$
declare k text; v jsonb; n int := 0;
begin
  if p_notes is null or jsonb_typeof(p_notes) <> 'object' then return false; end if;
  for k, v in select * from jsonb_each(p_notes) loop
    n := n + 1;
    if k !~ '^[0-9]{1,2}:[[:alnum:]]{1,20}$' or jsonb_typeof(v) <> 'number'
        or (v #>> '{}')::numeric < 0.25 or (v #>> '{}')::numeric > 4 then
      return false;
    end if;
  end loop;
  return n > 0 and n <= public._mn_cfg('max_notes');
end $$;

create or replace function public.notes_send(p_code text, p_notes jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
begin
  if t is null or not public._friends(u, t) or public._blocked(u, t) or not public._social(u) or not public._social(t) then
    return public._fail('not_friends');
  end if;
  if not public._mn_valid(p_notes) then return public._fail('bad_notes'); end if;
  if (select count(*) from public.mail where sender = u and recipient = t and kind = 'notes'
      and (created_at at time zone 'utc')::date = public._today()) >= public._mn_cfg('per_friend_per_day') then
    return public._fail('already_today');
  end if;
  if not public._rate_ok(u, 'mail', 30) then return public._fail('slow_down'); end if;
  insert into public.mail (sender, recipient, kind, phrase, notes, place)
  values (u, t, 'notes', 0, p_notes, (select place from public.profiles where id = u));
  perform public._add_points(u, t, public._mn_cfg('points'));
  return jsonb_build_object('ok', true, 'points', public._mn_cfg('points'));
end $$;

-- Opens notes mail [p_id] of the caller and returns its notes.
create or replace function public.notes_open(p_id bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  m public.mail;
begin
  select * into m from public.mail where id = p_id and recipient = u and kind = 'notes' for update;
  if not found then return public._fail('no_such_mail'); end if;
  update public.mail set opened = true, opened_at = coalesce(opened_at, now()) where id = p_id;
  return jsonb_build_object('ok', true, 'notes', coalesce(m.notes, '{}'::jsonb));
end $$;

revoke all on function public._mn_cfg(text), public._mn_valid(jsonb) from public, anon, authenticated, chimora_referee;
revoke all on function public.notes_send(text, jsonb), public.notes_open(bigint) from public, anon, chimora_referee;
grant execute on function public.notes_send(text, jsonb), public.notes_open(bigint) to authenticated;
