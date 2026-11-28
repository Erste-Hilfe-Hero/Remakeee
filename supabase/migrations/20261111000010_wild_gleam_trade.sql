-- Wild Gleams (feat/shiny): a Gleam form found in the wild is a colour form only and may be
-- traded. Only the shop's +10 % Gleam (gleam_boost) stays with its owner. Saves from before
-- wild Gleams carry only "gleam", which then always came from the Gleam Prism.
-- Mirrors LocalBackend.gleam_boosted / trade_mon_why.
create or replace function public._gleam_boosted(m jsonb) returns boolean
language sql immutable as $$
  select case when m ? 'gleam_boost' then coalesce(m->>'gleam_boost', 'false') = 'true'
    else coalesce(m->>'gleam', 'false') = 'true' end
$$;

create or replace function public._trade_mon_why(m jsonb) returns text
language sql immutable as $$
  select case
    when jsonb_typeof(m) <> 'object' or coalesce(m->>'uid', '') = '' or coalesce(m->>'species', '') = '' then 'no_spirling'
    when coalesce(m->>'held', '') <> '' then 'holds_item'
    when public._gleam_boosted(m) or coalesce(m->>'core', 'false') = 'true'
      or (jsonb_typeof(m->'crystal') = 'object' and m->'crystal' <> '{}'::jsonb) then 'shop_boosted'
    when coalesce(m->>'favorite', 'false') = 'true' then 'favorite'
  end
$$;

revoke all on function public._gleam_boosted(jsonb), public._trade_mon_why(jsonb)
  from public, anon, authenticated, chimora_referee;
