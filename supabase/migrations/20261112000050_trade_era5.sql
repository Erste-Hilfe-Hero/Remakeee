-- Era V (Living) Spirlings keep their origin era when traded (bug plan 1373). The first version
-- only knew eras 1-4 and set an Era V Spirling back to Era I. Mirrors LocalBackend.trade_mon_clean.
create or replace function public._trade_mon_clean(m jsonb) returns jsonb
language sql immutable as $$
  select (m - 'nickname' - 'box' - 'favorite') || jsonb_build_object('origin_era',
    case when coalesce(m->>'origin_era', '') ~ '^[1-5]$' then (m->>'origin_era')::int else 1 end)
$$;

revoke all on function public._trade_mon_clean(jsonb) from public, anon, authenticated, chimora_referee;
