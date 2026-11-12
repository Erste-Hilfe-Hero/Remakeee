-- Bug plan 1373: a traded Era V Spirling keeps its origin era; unknown eras still count as Era I.
do $$
begin
  assert public._trade_mon_clean('{"uid": "x", "origin_era": 5}'::jsonb)->>'origin_era' = '5', 'era V kept';
  assert public._trade_mon_clean('{"uid": "x", "origin_era": 4}'::jsonb)->>'origin_era' = '4', 'era IV kept';
  assert public._trade_mon_clean('{"uid": "x", "origin_era": 6}'::jsonb)->>'origin_era' = '1', 'unknown era is I';
  assert public._trade_mon_clean('{"uid": "x"}'::jsonb)->>'origin_era' = '1', 'older saves count as era I';
end $$;
