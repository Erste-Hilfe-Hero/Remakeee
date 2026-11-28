-- The first minutes of a journey (Chimora 1.3.2, Ali): how fast new players reach control, the
-- first wild Spirling, the first bond, the story and the first save. Same path and rules as
-- public.admin_funnel (20261121079000_funnel_view.sql): it reads the saves the server already
-- keeps (records.funnel, whole seconds of play since New Game, written by scripts/core/Funnel.gd
-- and synced with the save, so offline play arrives with the next sync) and only counts come out.
-- No account id, name or friend code ever leaves this function, and it stores nothing new.
--
-- Only the database admin can call it (service_role, or postgres in the console):
--   psql -v from=2026-11-28 -v to=2026-12-05 -f tools/online/funnel_report.sql
--
-- One row per sign-up day (profiles.created_at, UTC) from p_from to p_to: accounts, journeys (save
-- slots with a funnel record, so journeys started in 1.3.2 or later), then per step the journeys
-- that reached it and the median seconds to it. Re-runnable.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
end $$;

create or replace function public.admin_funnel_start(p_from date, p_to date)
returns table (
  day date,
  accounts bigint,
  journeys bigint,
  first_control bigint,
  first_control_median_s numeric,
  first_wild bigint,
  first_wild_median_s numeric,
  first_catch bigint,
  first_catch_median_s numeric,
  story_start bigint,
  story_start_median_s numeric,
  first_save bigint,
  first_save_median_s numeric
)
language sql stable security definer set search_path = public as $$
  with acc as (
    select p.id, (p.created_at at time zone 'UTC')::date as d
    from public.profiles p
    where p.created_at >= p_from::timestamp at time zone 'UTC'
      and p.created_at < (p_to + 1)::timestamp at time zone 'UTC'
  ),
  j as (
    select acc.d, s.data->'records'->'funnel' as f
    from public.saves s join acc on acc.id = s.user_id
    where jsonb_typeof(s.data->'records'->'funnel') = 'object'
  ),
  steps as (
    select j.d,
      case when jsonb_typeof(j.f->'first_control') = 'number' then (j.f->>'first_control')::numeric end as first_control,
      case when jsonb_typeof(j.f->'first_wild') = 'number' then (j.f->>'first_wild')::numeric end as first_wild,
      case when jsonb_typeof(j.f->'first_catch') = 'number' then (j.f->>'first_catch')::numeric end as first_catch,
      case when jsonb_typeof(j.f->'story_start') = 'number' then (j.f->>'story_start')::numeric end as story_start,
      case when jsonb_typeof(j.f->'first_save') = 'number' then (j.f->>'first_save')::numeric end as first_save
    from j
  ),
  per_day as (
    select s.d,
      count(*) as journeys,
      count(s.first_control) as first_control,
      percentile_cont(0.5) within group (order by s.first_control) as first_control_m,
      count(s.first_wild) as first_wild,
      percentile_cont(0.5) within group (order by s.first_wild) as first_wild_m,
      count(s.first_catch) as first_catch,
      percentile_cont(0.5) within group (order by s.first_catch) as first_catch_m,
      count(s.story_start) as story_start,
      percentile_cont(0.5) within group (order by s.story_start) as story_start_m,
      count(s.first_save) as first_save,
      percentile_cont(0.5) within group (order by s.first_save) as first_save_m
    from steps s
    group by s.d
  )
  select g.d::date,
    (select count(*) from acc where acc.d = g.d::date),
    coalesce(p.journeys, 0),
    coalesce(p.first_control, 0), round(p.first_control_m::numeric, 1),
    coalesce(p.first_wild, 0), round(p.first_wild_m::numeric, 1),
    coalesce(p.first_catch, 0), round(p.first_catch_m::numeric, 1),
    coalesce(p.story_start, 0), round(p.story_start_m::numeric, 1),
    coalesce(p.first_save, 0), round(p.first_save_m::numeric, 1)
  from generate_series(p_from, p_to, interval '1 day') g(d)
  left join per_day p on p.d = g.d::date
  order by g.d
$$;

revoke all on function public.admin_funnel_start(date, date) from public, anon, authenticated;
grant execute on function public.admin_funnel_start(date, date) to service_role;
