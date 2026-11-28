-- Plan area 7, item 3009: the server keeps the last 5 versions of each save slot, and Settings,
-- Account shows them with date, place and play time to bring one back. Every change of a stored
-- save (saving, a trade, a restore) puts the version before it into save_history.

insert into public.server_config (key, value) values ('save_history_keep', '5') on conflict (key) do nothing;

create table if not exists public.save_history (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  slot int not null check (slot between 1 and 3),
  rev int not null,
  data jsonb not null,
  summary text not null default '',
  saved_at timestamptz not null
);
create index if not exists save_history_slot on public.save_history (user_id, slot, id desc);
alter table public.save_history enable row level security;
revoke all on public.save_history from public, anon, authenticated, chimora_referee;

create or replace function public._save_history_in() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.data is distinct from new.data then
    insert into public.save_history (user_id, slot, rev, data, summary, saved_at)
    values (old.user_id, old.slot, old.rev, old.data, old.summary, old.saved_at);
    delete from public.save_history h where h.user_id = old.user_id and h.slot = old.slot
      and h.id not in (select x.id from public.save_history x where x.user_id = old.user_id and x.slot = old.slot
        order by x.id desc limit public._config_int('save_history_keep', 5));
  end if;
  return new;
end $$;
drop trigger if exists saves_history on public.saves;
create trigger saves_history after update on public.saves for each row execute function public._save_history_in();

-- The earlier versions of a slot, newest first: when, where and how long played.
create or replace function public.save_history_list(p_slot int) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('ok', true, 'saves', coalesce(jsonb_agg(jsonb_build_object('id', h.id, 'rev', h.rev,
      'summary', h.summary, 'saved_at', extract(epoch from h.saved_at)::bigint,
      'play_time', case when jsonb_typeof(h.data->'play_time') = 'number' then (h.data->>'play_time')::float8 else 0 end)
      order by h.id desc), '[]'::jsonb))
  from public.save_history h where h.user_id = public._uid() and h.slot = p_slot
$$;

-- Brings an earlier version back as the newest one; the version it replaces goes into the history,
-- so a restore can be undone. The game reads the slot again afterwards.
create or replace function public.save_restore(p_slot int, p_id bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  h public.save_history;
  s public.saves;
begin
  select * into h from public.save_history where id = p_id and user_id = u and slot = p_slot;
  if not found then return public._fail('no_such_save'); end if;
  select * into s from public.saves where user_id = u and slot = p_slot for update;
  if not found then return public._fail('no_such_save'); end if;
  update public.saves set data = h.data, summary = h.summary, rev = s.rev + 1, saved_at = now(), request_id = null
  where user_id = u and slot = p_slot;
  return jsonb_build_object('ok', true, 'rev', s.rev + 1);
end $$;

revoke all on function public._save_history_in() from public, anon, authenticated, chimora_referee;
revoke all on function public.save_history_list(int), public.save_restore(int, bigint) from public, anon, chimora_referee;
grant execute on function public.save_history_list(int), public.save_restore(int, bigint) to authenticated;
