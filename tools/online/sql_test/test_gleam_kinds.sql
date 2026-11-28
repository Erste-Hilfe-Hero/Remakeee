-- Gleam kinds (1.3.2): the kind travels with a traded or lent Gleam and is checked on the way.
do $$
declare
  m jsonb;
begin
  m := public._trade_mon_clean('{"uid": "x", "species": "Kindlop", "gleam": true, "gleam_kind": "opaline"}'::jsonb);
  assert m->>'gleam_kind' = 'opaline', 'a known kind round-trips';
  foreach m in array array[
    '{"uid": "x", "gleam": true, "gleam_kind": "rime"}'::jsonb,
    '{"uid": "x", "gleam": true, "gleam_kind": "inkwash"}'::jsonb,
    '{"uid": "x", "gleam": true, "gleam_kind": "duskgold"}'::jsonb,
    '{"uid": "x", "gleam": true, "gleam_kind": "classic"}'::jsonb] loop
    assert public._trade_mon_clean(m)->>'gleam_kind' = m->>'gleam_kind', 'every kind round-trips: ' || (m->>'gleam_kind');
  end loop;
  assert public._trade_mon_clean('{"uid": "x", "gleam": true}'::jsonb)->>'gleam_kind' = 'classic',
    'a Gleam from before the kinds travels as the classic kind';
  assert public._trade_mon_clean('{"uid": "x", "gleam": true, "gleam_kind": "golden_ticket"}'::jsonb)->>'gleam_kind' = 'classic',
    'an unknown kind is not passed on';
  assert public._trade_mon_clean('{"uid": "x", "gleam": true, "gleam_kind": 7}'::jsonb)->>'gleam_kind' = 'classic',
    'a kind of the wrong type is not passed on';
  assert not public._trade_mon_clean('{"uid": "x", "gleam": false, "gleam_kind": "opaline"}'::jsonb) ? 'gleam_kind',
    'no kind without a Gleam';
  assert not public._trade_mon_clean('{"uid": "x", "gleam": "true", "gleam_kind": "opaline"}'::jsonb) ? 'gleam_kind',
    'gleam must be a real boolean';
  assert not public._trade_mon_clean('{"uid": "x"}'::jsonb) ? 'gleam_kind', 'plain Spirling stays plain';
  -- The earlier rules still hold.
  m := public._trade_mon_clean('{"uid": "x", "nickname": "Bo", "box": 2, "favorite": true, "origin_era": 5, "gleam": true, "gleam_kind": "rime"}'::jsonb);
  assert not (m ? 'nickname' or m ? 'box' or m ? 'favorite'), 'nickname, box and mark stay behind';
  assert m->>'origin_era' = '5', 'origin era kept';
  assert public._trade_mon_why('{"uid": "x", "species": "Kindlop", "gleam": true, "gleam_boost": false, "gleam_kind": "opaline"}'::jsonb) is null,
    'a wild Gleam of any kind may be traded';
  assert public._trade_mon_why('{"uid": "x", "species": "Kindlop", "gleam": true, "gleam_boost": true, "gleam_kind": "classic"}'::jsonb) = 'shop_boosted',
    'the shop Gleam still stays';
end $$;

-- No client role may call the helpers.
do $$
declare
  r text;
  f text;
begin
  foreach r in array array['anon', 'authenticated'] loop
    foreach f in array array['public._gleam_kinds()', 'public._gleam_kind(jsonb)', 'public._trade_mon_clean(jsonb)'] loop
      assert not has_function_privilege(r, f, 'execute'), r || ' must not execute ' || f;
    end loop;
  end loop;
end $$;
