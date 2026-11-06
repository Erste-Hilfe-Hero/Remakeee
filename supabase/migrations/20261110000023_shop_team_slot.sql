-- Chimora shop (plan area 10): the bought sixth team slot (offer rg_team_slot_6, unlock
-- team_slot_6). The save check allows one more Spirling in the team for accounts that own it.
-- Echo teams (team_set) stay at the base party_max: bought slots do not count in duels.

create or replace function public._party_max(u uuid) returns int
language sql stable security definer set search_path = public as $$
  select public._config_int('party_max', 5)
    + case when u is not null and exists (select 1 from public.entitlements e where e.user_id = u and e.key = 'team_slot_6')
      then 1 else 0 end
$$;

create or replace function public._save_ok(d jsonb) returns boolean
language plpgsql stable as $$
declare
  s jsonb;
  party_max int := public._party_max(auth.uid());
  level_max int := public._config_int('level_max', 60);
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

revoke all on function public._party_max(uuid) from public, anon, authenticated;
revoke all on function public._save_ok(jsonb) from public, anon, authenticated;
