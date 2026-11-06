-- Plan area 7, item 3011: small actions (set phrases, waves, thanks, world goal) wait in a queue
-- of up to 50 in the game while the connection is weak, each with its own id. action_once runs
-- one of them and remembers the id for 2 days, so an action sent twice (the answer to the first
-- one got lost) counts once.

create table if not exists public.action_done (
  user_id uuid not null references auth.users (id) on delete cascade,
  id text not null,
  at timestamptz not null default now(),
  primary key (user_id, id)
);
alter table public.action_done enable row level security;
revoke all on public.action_done from public, anon, authenticated, chimora_referee;

create or replace function public.action_once(p_id text, p_fn text, p_args jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  rid text := left(coalesce(p_id, ''), 40);
  a jsonb := coalesce(p_args, '{}'::jsonb);
  r jsonb;
begin
  if length(rid) < 8 then
    return public._fail('bad_id');
  end if;
  delete from public.action_done where user_id = u and at < now() - interval '2 days';
  if exists (select 1 from public.action_done where user_id = u and id = rid) then
    return jsonb_build_object('ok', true, 'repeat', true);
  end if;
  if p_fn = 'mail_send' and a->>'p_kind' in ('phrase', 'wave', 'thanks') then
    r := public.mail_send(a->>'p_code', a->>'p_kind', coalesce((a->>'p_phrase')::int, 0));
  elsif p_fn = 'community_add' then
    r := public.community_add(a->>'p_kind', coalesce((a->>'p_amount')::int, 0));
  else
    return public._fail('bad_action');
  end if;
  -- Refused for going too fast: the game may send the same action again later.
  if coalesce(r->>'error', '') <> 'slow_down' then
    insert into public.action_done (user_id, id) values (u, rid) on conflict do nothing;
  end if;
  return r;
end $$;
revoke all on function public.action_once(text, text, jsonb) from public, anon, chimora_referee;
grant execute on function public.action_once(text, text, jsonb) to authenticated;
