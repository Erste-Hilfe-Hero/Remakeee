extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 828, 829): keepsake value and field
## value modes of the simulator.

func before_all() -> void:
	Database.load_all()

func test_every_holdable_item_is_a_keepsake_row() -> void:
	var ks: Array[String] = BalanceSim.keepsakes()
	assert_gt(ks.size(), 3)
	for id: String in ks:
		assert_true(BattleRules.is_holdable(id), id)
	var r: Dictionary = BalanceSim.run_keepsakes(30, 4, 7, ["iron_burr", "keen_lens"] as Array[String])
	assert_eq(r.keepsakes.keys(), ["iron_burr", "keen_lens"])
	for id: String in r.keepsakes:
		var row: Dictionary = r.keepsakes[id]
		assert_almost_eq(float(row.gain), float(row.with) - float(row.without), 0.002)
		assert_eq(bool(row.ok), float(row.gain) <= BalanceSim.KEEPSAKE_MAX_GAIN)
	assert_string_contains(BalanceSim.keepsakes_report(r), "| iron_burr |")

func test_every_boosting_field_is_measured_with_its_element() -> void:
	var r: Dictionary = BalanceSim.run_fields(30, 4, 7)
	var boosting: int = 0
	for fid: String in BattleRules.FIELDS:
		if not str(BattleRules.FIELDS[fid].get("boost", "")).is_empty():
			boosting += 1
	assert_eq(r.fields.size(), boosting)
	for fid: String in r.fields:
		var row: Dictionary = r.fields[fid]
		assert_eq(row.element, Elements.element_name(int(Elements.E[str(BattleRules.FIELDS[fid].boost)])))
		var g: float = float(row.gain)
		assert_eq(bool(row.ok), g >= BalanceSim.FIELD_GAIN_BAND.x and g <= BalanceSim.FIELD_GAIN_BAND.y)
	assert_string_contains(BalanceSim.fields_report(r), "| high_tide | Tide |")

func test_pairs_are_seeded() -> void:
	assert_eq(BalanceSim.run_fields(30, 3, 9, ["high_tide"] as Array[String]), BalanceSim.run_fields(30, 3, 9, ["high_tide"] as Array[String]))
