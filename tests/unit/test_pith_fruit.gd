extends GutTest
## Pith Fruit (era function "pith_fruit", Era II): held fruit eaten once, by itself.

func _mon(lvl: int, held: String = "") -> Spirling:
	var s := Spirling.new(Database.species("Mossling"), lvl)
	s.held = held
	return s

func _model(me: Spirling) -> BattleModel:
	var m := BattleModel.new([me] as Array[Spirling], [_mon(20)] as Array[Spirling], true, 3)
	m.start()
	return m

func test_items_exist_and_are_held() -> void:
	assert_eq(float(BattleRules.held_info("pith_mend").get("pith_heal", 0.0)), 0.25)
	assert_true(bool(BattleRules.held_info("pith_clear").get("pith_cure", false)))
	assert_true(BattleRules.is_holdable("pith_mend"))
	assert_true(BattleRules.is_holdable("pith_clear"))

func test_mending_pith_heals_at_half_once() -> void:
	var me: Spirling = _mon(20, "pith_mend")
	var m: BattleModel = _model(me)
	var full: int = me.max_hp()
	m.deal_damage(0, full / 4)
	assert_eq(me.held, "pith_mend", "not hungry above half")
	var hp_before: int = full - full / 4
	m.deal_damage(0, hp_before - full / 3)
	assert_eq(me.held, "", "eaten at half or less")
	assert_eq(me.hp, full / 3 + roundi(full * 0.25))
	var after: int = me.hp
	m.deal_damage(0, after - 1)
	assert_eq(me.hp, 1, "only once")

func test_clearing_pith_washes_off_a_condition() -> void:
	var me: Spirling = _mon(20, "pith_clear")
	var m: BattleModel = _model(me)
	var types: Array[int] = []
	m.event_emitted.connect(func(ev: BattleEvent) -> void: types.append(ev.type))
	assert_true(m.apply_status(0, "scorch"))
	assert_eq(me.status, "", "the condition is gone")
	assert_eq(me.held, "")
	assert_true(BattleEvent.Type.HELD_FRUIT in types)
	assert_true(BattleEvent.Type.STATUS_CURED in types)
	m.apply_status(0, "scorch")
	assert_eq(me.status, "scorch", "no fruit left")

func test_fruit_line_has_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	assert_true(de.has("%s eats its %s!"))
	for id: String in ["pith_mend", "pith_clear"]:
		assert_true(de.has(str(Database.item(id).name)))
		assert_true(de.has(str(Database.item(id).description)))

func test_sold_in_later_era_shops_only() -> void:
	for f: String in ["vellmarch", "quivermoor"]:
		assert_string_contains(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % f), "pith_mend pith_clear")
	for f: String in ["brindlewick", "copperfold", "madderby"]:
		assert_false(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % f).contains("pith_"), "%s is Era I" % f)
