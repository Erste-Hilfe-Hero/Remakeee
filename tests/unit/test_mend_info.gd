extends GutTest
## Plan area 2: Root Mend (492, 511), move key check (577) and live info lines (578).

func before_all() -> void:
	Database.load_all()

func test_root_mend_heals_now_and_then_three_turns() -> void:
	var mv: MoveData = Database.move("Root Mend")
	assert_not_null(mv)
	assert_true(mv.has_effect(&"mend"))
	# Zippit has no regenerating gift, so only the art heals here.
	var me: Spirling = BattleFixtures.make("Zippit", 40, ["Root Mend"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Kindlop", 5, ["Cinder Nip"] as Array[String])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling])
	me.hp = me.max_hp() / 4
	var start: int = me.hp
	me.energy = Spirling.MAX_ENERGY
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var tick: int = maxi(1, me.max_hp() / BattleRules.MEND_DIV)
	assert_eq(me.hp, start + maxi(1, int(me.max_hp() * 0.2)) + tick, "20% now, the first mend at this turn's end")
	for i: int in 3:
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(me.hp, start + maxi(1, int(me.max_hp() * 0.2)) + 3 * tick, "three mends in all")
	assert_eq(me.mend_turns, 0)

func test_heal_block_stops_mending() -> void:
	var me: Spirling = BattleFixtures.make("Kelphound", 40, ["Root Mend"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Kindlop", 5, ["Cinder Nip"] as Array[String])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling])
	me.hp = me.max_hp() / 4
	me.mend_turns = 3
	m.apply_heal_block(0, 3)
	var before: int = me.hp
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(me.hp, before)

func test_kelphound_learns_root_mend_at_35() -> void:
	var names: Array[String] = []
	for mv: MoveData in Database.species("Kelphound").moves_learned_at(35):
		names.append(mv.move_name)
	assert_has(names, "Root Mend")

func test_unknown_move_keys_are_reported() -> void:
	assert_eq(DataValidator.validate().size(), 0)
	var path: String = "user://moves_typo.json"
	var raw: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/moves.json"))
	(raw[0] as Dictionary)["powr"] = 40
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	var errors: PackedStringArray = DataValidator.validate("res://data/spirlings.json", path)
	var hit: bool = false
	for e: String in errors:
		hit = hit or e.contains("unknown key 'powr'")
	assert_true(hit, "the typo is reported")

func test_info_names_the_live_element_and_landing_turn() -> void:
	var me: Spirling = BattleFixtures.make("Lumenewt", 36, ["Omen Bell"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Nip"] as Array[String])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling])
	assert_string_contains(CommandMenu.move_info(Database.move("Omen Bell"), m), "it lands on turn %d." % (m.turn + 3))
	var fe: MoveData = null
	for mv: MoveData in Database.moves.values():
		if mv.has_effect(&"field_element"):
			fe = mv
	assert_not_null(fe)
	assert_false(CommandMenu.move_info(fe, m).contains("Right now"), "no field, no live element")
	m.set_field("static_veil")
	assert_string_contains(CommandMenu.move_info(fe, m), "Right now: Volt.")
	assert_string_contains(CommandMenu.move_info(Database.move("Kindle Up")), "By 2 at full Vigor.")
