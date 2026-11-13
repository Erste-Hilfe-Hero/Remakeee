-- KAMPF_PLAN_1000 (Online-Kämpfe): a friend's echo keeps the keepsake its Spirling holds. team_set
-- keeps "held" only when it is an item id the game knows (known_ids kind 'item', loaded at every
-- deploy); anything else is dropped, so no free text gets in. The game itself only sends and uses
-- keepsakes that are not sold in the shop (EchoTeam.gd). Same rule in LocalBackend (_fn_team_set).

create or replace function public.team_set(p_team jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  clean jsonb := '[]'::jsonb;
  s jsonb;
  row jsonb;
  moves jsonb;
  mv jsonb;
  party_max int := public._config_int('party_max', 5);
  level_max int := public._config_int('level_max', 60);
begin
  perform public._ensure_profile(u);
  if jsonb_typeof(p_team) <> 'array' then return public._fail('bad_team'); end if;
  for s in select * from jsonb_array_elements(p_team) limit party_max loop
    moves := '[]'::jsonb;
    for mv in select * from jsonb_array_elements(case when jsonb_typeof(s->'moves') = 'array' then s->'moves' else '[]'::jsonb end) limit 4 loop
      moves := moves || to_jsonb(left(regexp_replace(mv #>> '{}', '[^[:alnum:] ''-]', '', 'g'), 24));
    end loop;
    row := jsonb_build_object(
      'species', left(regexp_replace(coalesce(s->>'species', ''), '[^[:alnum:]]', '', 'g'), 20),
      'level', least(greatest(coalesce((s->>'level')::numeric, 1), 1), level_max)::int,
      'moves', moves);
    if jsonb_typeof(s->'held') = 'string'
        and exists (select 1 from public.known_ids k where k.kind = 'item' and k.id = s->>'held') then
      row := row || jsonb_build_object('held', s->>'held');
    end if;
    clean := clean || row;
  end loop;
  update public.profiles set team = clean where id = u;
  return jsonb_build_object('ok', true, 'size', jsonb_array_length(clean));
end $$;
