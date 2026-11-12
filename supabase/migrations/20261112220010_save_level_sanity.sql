-- No top ring for Spirlings (owner decision 2026-11-12): save_level_max is no longer a game cap,
-- only a sanity bound against garbage (9999, Spirling.LEVEL_SANITY). level_max stays 60 and
-- keeps driving echo teams (team_set), the open league ring and the duel ring (PvP fairness).
-- Re-runnable like the earlier migrations; it raises a lower value left by 20261112200010.

insert into public.server_config (key, value) values ('save_level_max', '9999')
on conflict (key) do update set value = '9999'
where (public.server_config.value #>> '{}') !~ '^[0-9]+$' or (public.server_config.value #>> '{}')::numeric < 9999;

create or replace function public._save_ok(d jsonb) returns boolean
language plpgsql stable as $$
declare
  s jsonb;
  party_max int := public._party_max(auth.uid());
  level_max int := public._config_int('save_level_max', 9999);
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
