-- New-player funnel (Chimora 100 plan, item 79; Ali said yes on 2026-11-21): where new players
-- stop. Counts only: no account id, name or friend code ever leaves this function. It reads data
-- the server already keeps (profiles.created_at / last_seen, saves.data) and stores nothing new.
-- Privacy note: AccountMenu.PRIVACY_NOTE, docs/legal/DATENSCHUTZ.md 3.1, VERARBEITUNGEN.md.
--
-- Only the database admin can call it (service_role, or postgres in the console):
--   psql -v from=2026-11-01 -v to=2026-11-20 -f tools/online/funnel_report.sql
-- Not mirrored in LocalBackend: admin functions are not part of the player API.
--
-- One row per sign-up day (profiles.created_at, UTC) from p_from to p_to:
--   accounts, with_save, then per story step the accounts that have the flag in any save slot
--   (data/quests.json order), back_1d / back_7d (last_seen at least 1 / 7 days after sign-up),
--   stopped (not seen for p_stop_days), and for stopped accounts with a save: median play time in
--   minutes and the most common map of their newest save, and the share (percent) with a lost try
--   against a Warden (records.warden_losses, the first one is Orrin) or a lowered difficulty
--   (records.difficulty_lowered).
-- Bot accounts: the only automated account on the live server is the monitor (monitor.yml), which
-- deletes itself in the same run, so it is never counted. CI uses a throwaway server.
-- Re-runnable.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
end $$;

create or replace function public.admin_funnel(p_from date, p_to date, p_stop_days int default 7)
returns table (
  day date,
  accounts bigint,
  with_save bigint,
  got_starter bigint,
  aldo_gift bigint,
  met_kestra bigint,
  beat_story_rival_jinks_1 bigint,
  kestra_spar bigint,
  rift_cinder_sealed bigint,
  rift_tide_sealed bigint,
  aldo_dock_told bigint,
  back_1d bigint,
  back_7d bigint,
  stopped bigint,
  stopped_median_play_min numeric,
  stopped_top_map text,
  stopped_warden_loss_pct numeric,
  stopped_lowered_pct numeric
)
language sql stable security definer set search_path = public as $$
  with acc as (
    select p.id, (p.created_at at time zone 'UTC')::date as d, p.created_at, p.last_seen
    from public.profiles p
    where p.created_at >= p_from::timestamp at time zone 'UTC'
      and p.created_at < (p_to + 1)::timestamp at time zone 'UTC'
  ),
  flags as (
    select s.user_id,
      bool_or(s.data->'flags'->'got_starter' = 'true'::jsonb) as got_starter,
      bool_or(s.data->'flags'->'aldo_gift' = 'true'::jsonb) as aldo_gift,
      bool_or(s.data->'flags'->'met_kestra' = 'true'::jsonb) as met_kestra,
      bool_or(s.data->'flags'->'beat_story_rival_jinks_1' = 'true'::jsonb) as beat_story_rival_jinks_1,
      bool_or(s.data->'flags'->'kestra_spar' = 'true'::jsonb) as kestra_spar,
      bool_or(s.data->'flags'->'rift_cinder_sealed' = 'true'::jsonb) as rift_cinder_sealed,
      bool_or(s.data->'flags'->'rift_tide_sealed' = 'true'::jsonb) as rift_tide_sealed,
      bool_or(s.data->'flags'->'aldo_dock_told' = 'true'::jsonb) as aldo_dock_told,
      bool_or(s.data->'records'->'difficulty_lowered' = 'true'::jsonb) as lowered,
      bool_or(exists (select 1 from jsonb_each(case when jsonb_typeof(s.data->'records'->'warden_losses') = 'object'
        then s.data->'records'->'warden_losses' else '{}'::jsonb end) w
        where jsonb_typeof(w.value) = 'number' and (w.value)::text::numeric > 0)) as warden_loss
    from public.saves s join acc on acc.id = s.user_id
    group by s.user_id
  ),
  newest as (
    select distinct on (s.user_id) s.user_id,
      case when jsonb_typeof(s.data->'play_time') = 'number' then (s.data->>'play_time')::numeric else 0 end as play_time,
      coalesce(s.data->>'map', '') as map
    from public.saves s join acc on acc.id = s.user_id
    order by s.user_id, s.saved_at desc, s.slot
  ),
  rows as (
    select acc.d, acc.last_seen >= acc.created_at + interval '1 day' as back1,
      acc.last_seen >= acc.created_at + interval '7 days' as back7,
      acc.last_seen < now() - make_interval(days => p_stop_days) as stop,
      f.*, n.play_time, n.map
    from acc left join flags f on f.user_id = acc.id left join newest n on n.user_id = acc.id
  )
  select g.d::date,
    count(r.d),
    count(r.user_id),
    count(*) filter (where r.got_starter),
    count(*) filter (where r.aldo_gift),
    count(*) filter (where r.met_kestra),
    count(*) filter (where r.beat_story_rival_jinks_1),
    count(*) filter (where r.kestra_spar),
    count(*) filter (where r.rift_cinder_sealed),
    count(*) filter (where r.rift_tide_sealed),
    count(*) filter (where r.aldo_dock_told),
    count(*) filter (where r.back1),
    count(*) filter (where r.back7),
    count(*) filter (where r.stop),
    round((percentile_cont(0.5) within group (order by r.play_time) filter (where r.stop and r.user_id is not null))::numeric / 60, 1),
    mode() within group (order by r.map) filter (where r.stop and r.user_id is not null),
    round(100.0 * count(*) filter (where r.stop and r.warden_loss)
      / nullif(count(*) filter (where r.stop and r.user_id is not null), 0), 1),
    round(100.0 * count(*) filter (where r.stop and r.lowered)
      / nullif(count(*) filter (where r.stop and r.user_id is not null), 0), 1)
  from generate_series(p_from, p_to, interval '1 day') g(d)
  left join rows r on r.d = g.d::date
  group by g.d
  order by g.d
$$;

revoke all on function public.admin_funnel(date, date, int) from public, anon, authenticated;
grant execute on function public.admin_funnel(date, date, int) to service_role;
