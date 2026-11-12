-- Saves get their own ring limit (save_level_max, up to Spirling.ERA_MAX_LEVEL 96): Halcyra
-- (Era IV) Spirlings grow past 60. level_max stays 60 and keeps driving echo teams (team_set),
-- the open league ring and the duel ring, so nothing online gets stronger than before.
-- Re-runnable like the earlier migrations.

insert into public.server_config (key, value) values ('save_level_max', '96')
on conflict (key) do nothing;

create or replace function public._save_ok(d jsonb) returns boolean
language plpgsql stable as $$
declare
  s jsonb;
  party_max int := public._party_max(auth.uid());
  level_max int := public._config_int('save_level_max', 96);
begin
  if jsonb_typeof(d) <> 'object' then return false; end if;
  if pg_column_size(d) > 400000 then return false; end if;
  if jsonb_typeof(coalesce(d->'party', '[]'::jsonb)) <> 'array' then return false; end if;
  if jsonb_typeof(coalesce(d->'storage', '[]'::jsonb)) <> 'array' then return false; end if;
  if jsonb_array_length(coalesce(d->'party', '[]'::jsonb)) > party_max then return false; end if;
  if coalesce((d->>'money')::numeric, 0) not between 0 and 9999999 then return false; end if;
  for s in select * from jsonb_array_elements(coalesce(d->'party', '[]'::jsonb) || coalesce(d->'storage', '[]'::jsonb)) loop
    if coalesce((s->>'level')::numeric, 1) not between 1 and level_max then return false; end if;
  end loop;
  return true;
exception when others then
  return false;
end $$;

revoke all on function public._save_ok(jsonb) from public, anon, authenticated;
