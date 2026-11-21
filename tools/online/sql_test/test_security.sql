-- Plan item 3872: every security definer function fixes its search_path, helpers (names that
-- start with "_") cannot be called by players, and nothing is callable without signing in.
do $$
declare f record; bad text := ''; players int := 0;
begin
  for f in
    select p.oid, p.proname, p.prosecdef, p.proconfig,
      has_function_privilege('anon', p.oid, 'execute') as anon_x,
      has_function_privilege('authenticated', p.oid, 'execute') as auth_x
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  loop
    if f.prosecdef and not exists (select 1 from unnest(coalesce(f.proconfig, '{}')) c where c like 'search_path=%') then
      bad := bad || format(E'\n  %s: security definer without fixed search_path', f.proname);
    end if;
    -- _pre_request is run by PostgREST for every request, as the caller's role.
    if f.proname like '\_%' and f.proname <> '_pre_request' and (f.anon_x or f.auth_x) then
      bad := bad || format(E'\n  %s: helper callable by players', f.proname);
    end if;
    -- Player functions find the caller only through public._uid(), which fails when signed out.
    if f.auth_x and f.proname not like '\_%' and position('_uid()' in (select prosrc from pg_proc where oid = f.oid)) = 0 then
      bad := bad || format(E'\n  %s: player function does not check public._uid()', f.proname);
    end if;
    if f.auth_x and f.proname not like '\_%' then players := players + 1; end if;
    if f.anon_x and f.proname <> '_pre_request' then
      bad := bad || format(E'\n  %s: callable without signing in', f.proname);
    end if;
  end loop;
  assert players >= 20, 'expected the player API, found ' || players;
  if bad <> '' then
    raise exception 'security check failed:%', bad;
  end if;
end $$;
