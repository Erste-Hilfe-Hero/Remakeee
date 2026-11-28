-- Catalog v43 (20261128150000_shop_offers_v043.sql, First Catch Pack) is the newest catalog and
-- replaces the whole offer list: the bond charms of v42 (PR #662) must survive it, and charms stay
-- story only (blocked in fair leagues), next to the new pack.
do $$
declare
  ids text[] := array['rg_charm_swiftleaf', 'rg_charm_hush', 'rg_charm_lantern', 'rg_charm_firstlight',
    'rg_charm_swiftleaf_x3', 'rg_charm_lantern_x3', 'rg_charm_satchel', 'rg_first_catch'];
  i text;
  blocked jsonb;
begin
  foreach i in array ids loop
    if not exists (select 1 from public.shop_offers where id = i) then
      raise exception 'offer % is missing after catalog v43', i;
    end if;
  end loop;
  if (select product_id from public.shop_offers where id = 'rg_first_catch') is distinct from 'de.chimora.game.consumable.firstcatch' then
    raise exception 'rg_first_catch is not the firstcatch store product';
  end if;
  select value::jsonb into blocked from public.server_config where key = 'league_fair_blocked_sources';
  foreach i in array ids[1:7] loop
    if not blocked ? i then
      raise exception 'charm % is not blocked in fair leagues after v43', i;
    end if;
  end loop;
end $$;
