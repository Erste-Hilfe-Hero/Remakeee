-- Chimora battle referee (plan area 7, items 2687-2691, 2703).
-- The game uploads a finished battle (seed, teams, inputs = BattleReplay) and what it claims came
-- out of it (winner, Vigor left per Spirling, rounds). _referee_check puts the battle data into
-- battle_queue; the referee service (server/referee/) plays it again with the game's own battle
-- code and writes ok / mismatch / error into battle_results. League points, raid damage and
-- weekly scores only count once a battle is "ok" (public._battle_ok); until then the game shows
-- "being checked".
-- The referee logs in as its own database user chimora_referee, which may only read battle_queue
-- and write battle_results. It never sees who played. Re-runnable.

insert into public.server_config (key, value) values
  ('battle_submit_limit', '60')
on conflict (key) do nothing;

-- Every uploaded battle. Only the owner sees its state, through battle_status.
create table if not exists public.battles (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('echo_duel', 'league_fair', 'league_open', 'raid', 'live_duel')),
  ref text not null default '',
  status text not null default 'pending' check (status in ('pending', 'ok', 'mismatch', 'error')),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create index if not exists battles_user on public.battles (user_id, created_at desc);

-- What the referee reads: battle data only, no account.
create table if not exists public.battle_queue (
  battle_id bigint primary key references public.battles (id) on delete cascade,
  replay jsonb not null,
  claim jsonb not null,
  queued_at timestamptz not null default now()
);

-- What the referee writes.
create table if not exists public.battle_results (
  battle_id bigint primary key references public.battles (id) on delete cascade,
  verdict text not null check (verdict in ('ok', 'mismatch', 'error')),
  detail jsonb not null default '{}'::jsonb,
  decided_at timestamptz not null default now()
);

alter table public.battles enable row level security;
alter table public.battle_queue enable row level security;
alter table public.battle_results enable row level security;
revoke all on public.battles, public.battle_queue, public.battle_results from public, anon, authenticated;
revoke all on sequence public.battles_id_seq from public, anon, authenticated;

-- The referee's own database user (item 2703). setup.sh gives it a password and LOGIN.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'chimora_referee') then
    create role chimora_referee nologin;
  end if;
end $$;
grant usage on schema public to chimora_referee;
revoke all on public.battles, public.battle_queue, public.battle_results from chimora_referee;
grant select on public.battle_queue to chimora_referee;
grant select, insert on public.battle_results to chimora_referee;
drop policy if exists referee_reads on public.battle_queue;
create policy referee_reads on public.battle_queue for select to chimora_referee using (true);
drop policy if exists referee_sees_results on public.battle_results;
create policy referee_sees_results on public.battle_results for select to chimora_referee using (true);
drop policy if exists referee_writes on public.battle_results;
create policy referee_writes on public.battle_results for insert to chimora_referee with check (true);

-- Puts a battle in front of the referee (item 2689).
create or replace function public._referee_check(p_battle_id bigint, p_replay jsonb, p_claim jsonb) returns void
language sql volatile as $$
  insert into public.battle_queue (battle_id, replay, claim) values (p_battle_id, p_replay, p_claim)
  on conflict (battle_id) do nothing
$$;

-- A result arrives: the battle gets its state and leaves the queue.
create or replace function public._battle_result_in() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.battles set status = new.verdict, decided_at = new.decided_at
  where id = new.battle_id and status = 'pending';
  delete from public.battle_queue where battle_id = new.battle_id;
  return new;
end $$;
drop trigger if exists battle_result_in on public.battle_results;
create trigger battle_result_in after insert on public.battle_results
  for each row execute function public._battle_result_in();

-- True once the referee said "ok" (item 2691). Leagues, raids and weekly scores check this.
create or replace function public._battle_ok(p_battle_id bigint) returns boolean
language sql stable as $$
  select coalesce((select status = 'ok' from public.battles where id = p_battle_id), false)
$$;

-- Player API: upload a finished battle. Returns its id; the state starts as "pending".
create or replace function public.battle_submit(p_kind text, p_ref text, p_replay jsonb, p_claim jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  b bigint;
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
  insert into public.battles (user_id, kind, ref) values (u, p_kind, left(coalesce(p_ref, ''), 40))
  returning id into b;
  perform public._referee_check(b, p_replay, p_claim);
  return jsonb_build_object('ok', true, 'battle_id', b, 'status', 'pending');
end $$;

-- Player API: state of one of your own battles ("pending" = being checked).
create or replace function public.battle_status(p_battle_id bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare st text;
begin
  select status into st from public.battles where id = p_battle_id and user_id = public._uid();
  if st is null then return public._fail('no_such_battle'); end if;
  return jsonb_build_object('ok', true, 'status', st);
end $$;

revoke all on function public._referee_check(bigint, jsonb, jsonb), public._battle_result_in(), public._battle_ok(bigint)
  from public, anon, authenticated, chimora_referee;
revoke all on function public.battle_submit(text, text, jsonb, jsonb), public.battle_status(bigint) from public, anon, chimora_referee;
grant execute on function public.battle_submit(text, text, jsonb, jsonb), public.battle_status(bigint) to authenticated;
