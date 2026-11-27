-- Gleam kinds (1.3.2): a Gleam carries its kind ("gleam_kind") through trades and loans.
-- The kinds are data/gleam.json "kinds" (tests/unit/test_gleam_kinds.gd keeps this list equal).
-- A Gleam with no or an unknown kind travels as the classic kind (saves from before the kinds);
-- a Spirling that does not gleam carries no kind. Mirrors LocalBackend.trade_mon_clean.
-- Internal helpers only: no client may call them.
create or replace function public._gleam_kinds() returns text[]
language sql immutable as $$
  select array['classic', 'rime', 'inkwash', 'duskgold', 'opaline']::text[]
$$;

create or replace function public._gleam_kind(m jsonb) returns text
language sql immutable as $$
  select case when jsonb_typeof(m) <> 'object' or m->'gleam' is distinct from 'true'::jsonb then null
    when m->>'gleam_kind' = any(public._gleam_kinds()) then m->>'gleam_kind'
    else 'classic' end
$$;

create or replace function public._trade_mon_clean(m jsonb) returns jsonb
language sql immutable as $$
  select (m - 'nickname' - 'box' - 'favorite' - 'gleam_kind') || jsonb_build_object('origin_era',
    case when coalesce(m->>'origin_era', '') ~ '^[1-5]$' then (m->>'origin_era')::int else 1 end)
    || case when public._gleam_kind(m) is null then '{}'::jsonb
      else jsonb_build_object('gleam_kind', public._gleam_kind(m)) end
$$;

revoke all on function public._gleam_kinds(), public._gleam_kind(jsonb), public._trade_mon_clean(jsonb)
  from public, anon, authenticated, chimora_referee;
