-- Plan area 7, items 2895-2898, 2916: reports get a place, an object, a status and a number;
-- every decision reaches the reported player with a statement of reasons (DSA Art. 17) and the
-- reporter with the outcome; an appeal from the statement goes to Ali (DSA Art. 20). Ali decides
-- with moderation_decide and appeal_answer from the database console (no player can call them).

alter table public.reports add column if not exists context text not null default 'friends';
alter table public.reports add column if not exists object_id text;
alter table public.reports add column if not exists status text not null default 'open';
alter table public.reports add column if not exists decided_at timestamptz;
alter table public.reports add column if not exists action text;
do $$ begin
  alter table public.reports add constraint reports_status check (status in ('open', 'upheld', 'rejected'));
exception when duplicate_object then null;
end $$;
update public.reports set status = 'upheld' where handled and status = 'open';

-- Messages from the team to one player: decisions, report results, appeal answers.
create table if not exists public.notices (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('decision', 'report_result', 'appeal_answer')),
  report_id bigint references public.reports (id) on delete set null,
  body jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists notices_user on public.notices (user_id, created_at desc);

create table if not exists public.appeals (
  id bigserial primary key,
  notice_id bigint not null references public.notices (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  reason int not null,
  created_at timestamptz not null default now(),
  status text not null default 'open' check (status in ('open', 'changed', 'kept')),
  answered_at timestamptz
);
create unique index if not exists appeals_once on public.appeals (notice_id);

alter table public.notices enable row level security;
alter table public.appeals enable row level security;
revoke all on public.notices, public.appeals from public, anon, authenticated;

-- Fixed lists, so no free text reaches players. Every rule is in section 4 of the terms
-- (NUTZUNGSBEDINGUNGEN.md, "Verhaltensregeln"); split it here when the terms get numbered rules.
create or replace function public._mod_reason_rule(p_reason int) returns text
language sql immutable as $$
  select '4'::text
$$;

-- A report from anywhere a player is visible (2894, 2895). Returns its number at once (2916).
create or replace function public.report_in(p_code text, p_reason int, p_context text, p_object text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  t uuid := public._by_code(p_code);
  n bigint;
begin
  if t is null or t = u then return public._fail('no_such_code'); end if;
  if coalesce(p_context, '') not in ('friends', 'card', 'duel', 'trade', 'bund', 'raid', 'board', 'league') then
    return public._fail('bad_context');
  end if;
  if not public._rate_ok(u, 'report', 10) then return public._fail('slow_down'); end if;
  insert into public.reports (reporter, target, target_name, reason, context, object_id)
  values (u, t, (select name from public.profiles where id = t), least(greatest(coalesce(p_reason, 3), 0), 3),
    p_context, left(nullif(p_object, ''), 40))
  returning id into n;
  return jsonb_build_object('ok', true, 'report_id', n);
end $$;

create or replace function public.report(p_code text, p_reason int) returns jsonb
language sql volatile security definer set search_path = public as $$
  -- public._uid() first: fails when signed out, like every player function.
  select public.report_in(p_code, p_reason, 'friends', null) where public._uid() is not null
$$;

-- Ali's decision. p_action: 'name_reset', 'warning', 'league_block' or 'none' (rejected).
create or replace function public.moderation_decide(p_report bigint, p_upheld boolean, p_action text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  r public.reports;
  act text := case when p_upheld then coalesce(p_action, 'warning') else 'none' end;
begin
  if act not in ('name_reset', 'warning', 'league_block', 'none') then return public._fail('bad_action'); end if;
  select * into r from public.reports where id = p_report for update;
  if not found then return public._fail('no_such_report'); end if;
  if r.status <> 'open' then return public._fail('decided'); end if;
  update public.reports set status = case when p_upheld then 'upheld' else 'rejected' end, decided_at = now(),
    action = act, handled = true where id = p_report;
  if p_upheld then
    if act = 'name_reset' then
      update public.profiles set name = 'Wanderer ' || right(code, 4) where id = r.target;
    elsif act = 'league_block' then
      insert into public.cheat_flags (user_id, reason)
      select r.target, 'moderation' from generate_series(1, public._config_int('cheat_flag_limit', 3));
    end if;
    -- Statement of reasons (DSA Art. 17): measure, reason from the list, rule, right to appeal.
    if exists (select 1 from auth.users where id = r.target) then
      insert into public.notices (user_id, kind, report_id, body) values (r.target, 'decision', p_report,
        jsonb_build_object('action', act, 'reason', r.reason, 'rule', public._mod_reason_rule(r.reason),
          'context', r.context, 'automated', false, 'appeal_until', extract(epoch from now() + interval '6 months')::bigint));
    end if;
  end if;
  if r.reporter is not null then
    insert into public.notices (user_id, kind, report_id, body)
    values (r.reporter, 'report_result', p_report, jsonb_build_object('upheld', p_upheld));
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.notices_list() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  return jsonb_build_object('ok', true, 'notices', coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'kind', n.kind, 'report_id', n.report_id,
      'body', n.body, 'at', extract(epoch from n.created_at)::bigint, 'read', n.read_at is not null,
      'appealed', exists (select 1 from public.appeals a where a.notice_id = n.id),
      'appeal', (select a.status from public.appeals a where a.notice_id = n.id)) order by n.created_at desc)
    from public.notices n where n.user_id = u), '[]'::jsonb));
end $$;

create or replace function public.notice_read(p_id bigint) returns jsonb
language sql volatile security definer set search_path = public as $$
  update public.notices set read_at = coalesce(read_at, now()) where id = p_id and user_id = public._uid();
  select jsonb_build_object('ok', true)
$$;

-- Appeal from a decision within 6 months (2897). p_reason: 0 = I did not break the rule,
-- 1 = it was someone else on my phone, 2 = something else.
create or replace function public.appeal(p_notice bigint, p_reason int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  n public.notices;
  a bigint;
begin
  select * into n from public.notices where id = p_notice and user_id = u;
  if not found or n.kind <> 'decision' then return public._fail('no_such_notice'); end if;
  if n.created_at < now() - interval '6 months' then return public._fail('too_late'); end if;
  if exists (select 1 from public.appeals where notice_id = p_notice) then return public._fail('appealed'); end if;
  insert into public.appeals (notice_id, user_id, reason) values (p_notice, u, least(greatest(coalesce(p_reason, 2), 0), 2))
  returning id into a;
  return jsonb_build_object('ok', true, 'appeal_id', a);
end $$;

-- Ali's answer to an appeal: p_changed true lifts the measure.
create or replace function public.appeal_answer(p_appeal bigint, p_changed boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  a public.appeals;
  n public.notices;
begin
  select * into a from public.appeals where id = p_appeal for update;
  if not found then return public._fail('no_such_appeal'); end if;
  update public.appeals set status = case when p_changed then 'changed' else 'kept' end, answered_at = now() where id = p_appeal;
  select * into n from public.notices where id = a.notice_id;
  if p_changed and n.body->>'action' = 'league_block' then
    update public.profiles set cheat_cleared_at = now() where id = a.user_id;
  end if;
  insert into public.notices (user_id, kind, report_id, body)
  values (a.user_id, 'appeal_answer', n.report_id, jsonb_build_object('changed', p_changed));
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public._mod_reason_rule(int), public.moderation_decide(bigint, boolean, text),
  public.appeal_answer(bigint, boolean) from public, anon, authenticated;
revoke all on function public.report_in(text, int, text, text), public.report(text, int), public.notices_list(),
  public.notice_read(bigint), public.appeal(bigint, int) from public, anon;
grant execute on function public.report_in(text, int, text, text), public.report(text, int), public.notices_list(),
  public.notice_read(bigint), public.appeal(bigint, int) to authenticated;
