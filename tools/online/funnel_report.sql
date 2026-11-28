-- Where new players stop (20261121079000_funnel_view.sql). Counts only, no account data.
-- Run as the database owner on the server, for example:
--   docker compose exec -T db psql -U postgres -h localhost -v from=2026-11-01 -v to=2026-11-14 < tools/online/funnel_report.sql
-- from/to: sign-up days (UTC). Leave 7 days after "to" so back_7d and stopped mean something.
-- Columns: accounts, with_save, story steps in game order, back_1d/back_7d (seen again 1 / 7 days
-- after sign-up), stopped (not seen for 7 days) and, for stopped players with a save: median play
-- minutes, most common map, % with a lost Warden try, % that lowered the difficulty.
\pset footer off
select * from public.admin_funnel(:'from'::date, :'to'::date);

-- The whole range in one line, as share of accounts with a save.
select sum(accounts) as accounts, sum(with_save) as with_save,
  round(100.0 * sum(got_starter) / nullif(sum(with_save), 0), 1) as got_starter_pct,
  round(100.0 * sum(aldo_gift) / nullif(sum(with_save), 0), 1) as aldo_gift_pct,
  round(100.0 * sum(met_kestra) / nullif(sum(with_save), 0), 1) as met_kestra_pct,
  round(100.0 * sum(beat_story_rival_jinks_1) / nullif(sum(with_save), 0), 1) as jinks_1_pct,
  round(100.0 * sum(kestra_spar) / nullif(sum(with_save), 0), 1) as kestra_spar_pct,
  round(100.0 * sum(rift_cinder_sealed) / nullif(sum(with_save), 0), 1) as cinder_pct,
  round(100.0 * sum(rift_tide_sealed) / nullif(sum(with_save), 0), 1) as tide_pct,
  round(100.0 * sum(aldo_dock_told) / nullif(sum(with_save), 0), 1) as dock_told_pct,
  round(100.0 * sum(back_1d) / nullif(sum(accounts), 0), 1) as back_1d_pct,
  round(100.0 * sum(back_7d) / nullif(sum(accounts), 0), 1) as back_7d_pct,
  sum(stopped) as stopped
from public.admin_funnel(:'from'::date, :'to'::date);

-- The first minutes of journeys started in 1.3.2 or later (20261128160000_funnel_start.sql):
-- per sign-up day the journeys that reached control, the first wild Spirling, the first bond,
-- the story in Brindlewick and the first save, with the median seconds of play to each.
select * from public.admin_funnel_start(:'from'::date, :'to'::date);
