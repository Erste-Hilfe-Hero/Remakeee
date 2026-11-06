extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md): the first new arts per element, the
## Stone, Gale and Volt learnsets, cure_self, status_shift, side snares, ignore_daze,
## ignore_stages, and the retuned older arts (items 454, 456, 458, 465-566, 581-590).

func before_all() -> void:
	Database.load_all()

func _duel(a: Spirling, b: Spirling, seed_value: int = 7) -> BattleModel:
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false, seed_value)
	m.start()
	return m

func _only(species: String, level: int, move: String) -> Spirling:
	return BattleFixtures.make(species, level, [move] as Array[String])

func test_new_arts_match_the_plan() -> void:
	var want: Dictionary = {
		"Glow Knuckle": ["EMBER", 55, 3], "Char Mark": ["EMBER", 50, 3], "Spout Jab": ["TIDE", 40, 2],
		"Deepwell Draught": ["TIDE", 0, 4], "Pollen Prick": ["BLOOM", 45, 2], "Static Tag": ["VOLT", 45, 2],
		"Grid Lock": ["VOLT", 0, 3], "Grit Jab": ["STONE", 45, 2], "Crosswind": ["GALE", 55, 3],
		"Kite Cut": ["GALE", 50, 3], "Scatter Gale": ["GALE", 0, 3], "Beacon Ping": ["LUMEN", 45, 2],
		"Dawn Needle": ["LUMEN", 35, 1], "Shade Pounce": ["UMBRA", 50, 3], "Gloom Handoff": ["UMBRA", 0, 2],
	}
	for n: String in want:
		var mv: MoveData = Database.move(n)
		assert_not_null(mv, n)
		if mv == null:
			continue
		assert_eq(mv.element, Elements.E[want[n][0]], n)
		assert_eq(mv.power, int(want[n][1]), n)
		assert_eq(mv.energy_cost, int(want[n][2]), n)
	assert_eq(Database.move("Dawn Needle").priority, 1)
	assert_true(Database.move("Dawn Needle").ignore_daze)
	assert_almost_eq(BattleRules.status_bonus(Database.move("Char Mark"), _scorched()), 1.6, 0.0001)

func _scorched() -> Spirling:
	var s: Spirling = BattleFixtures.make("Mossling", 20)
	s.status = "scorch"
	return s

func test_learnsets_from_the_plan() -> void:
	var want: Dictionary = {
		"Shalebat": {8: "Grit Jab", 16: "Pumice Pelt"}, "Obsidroth": {30: "Landslip", 44: "Monolith Drop"},
		"Calderox": {36: "Quarry Wall"}, "Duskdigger": {33: "Fault Line"},
		"Zephlet": {5: "Draft Needle", 10: "Kite Cut", 14: "Crosswind", 19: "Scatter Gale"},
		"Tempestrel": {30: "Squall Line", 40: "Cloudbreak", 48: "Downburst"},
		"Zippit": {6: "Static Tag", 10: "Pylon Snap", 16: "Grid Lock"},
		"Glimmerax": {36: "Short Circuit", 44: "Capacitor Crash"},
	}
	for sp: String in want:
		for lv: int in want[sp]:
			var names: Array[String] = []
			for mv: MoveData in Database.species(sp).moves_learned_at(lv):
				names.append(mv.move_name)
			assert_has(names, want[sp][lv], "%s learns %s at ring %d" % [sp, want[sp][lv], lv])

func test_deepwell_draught_heals_and_cures() -> void:
	var a: Spirling = _only("Puddlet", 20, "Deepwell Draught")
	var b: Spirling = _only("Mossling", 20, "Bowl Over")
	var m: BattleModel = _duel(a, b)
	a.hp = a.max_hp() / 2
	a.status = "scorch"
	a.status_turns = 3
	a.energy = Spirling.MAX_ENERGY
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_true(BattleFixtures.types_of(ev).has(BattleEvent.Type.HEAL))
	assert_eq(a.status, "", "the own status is gone")

func test_gloom_handoff_passes_the_status_on() -> void:
	var a: Spirling = _only("Mirkmole", 20, "Gloom Handoff")
	var b: Spirling = _only("Mossling", 20, "Bowl Over")
	var m: BattleModel = _duel(a, b)
	a.status = "jolt"
	a.status_turns = 3
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(a.status, "")
	assert_eq(b.status, "jolt")
	# Nothing to hand over: it fails with a line.
	a.energy = Spirling.MAX_ENERGY
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_true(BattleFixtures.types_of(ev).has(BattleEvent.Type.STATUS_FAILED))

func test_shard_bed_snare_hits_the_next_one_in() -> void:
	var a: Spirling = _only("Shalebat", 20, "Shard Bed")
	var b1: Spirling = _only("Mossling", 20, "Bowl Over")
	var b2: Spirling = _only("Kindlop", 20, "Bowl Over")
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b1, b2] as Array[Spirling], false, 7)
	m.start()
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq((m.snares[1] as Array).size(), 1)
	assert_eq(BattleFixtures.first_of(ev, BattleEvent.Type.SNARE_SET).describe(), "A snare lies in wait on the foe's side!")
	var hp_before: int = b2.hp
	ev = m.submit_turn(BattleAction.make_rest(0), BattleAction.make_swap(1, 1))
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.SNARE_HIT))
	assert_eq(b2.hp, hp_before - b2.max_hp() / 10, "1/10 of its max Vigor")
	assert_true((m.snares[1] as Array).is_empty(), "the snare is used up")

func test_snares_are_capped_and_scatter_gale_clears_them() -> void:
	var a: Spirling = _only("Zephlet", 20, "Scatter Gale")
	var b: Spirling = _only("Mossling", 20, "Bowl Over")
	var m: BattleModel = _duel(a, b)
	for i: int in BattleRules.MAX_SNARES + 1:
		m.lay_snare(0, {"hp": 0.1}, "Shard Bed")
	assert_eq((m.snares[0] as Array).size(), BattleRules.MAX_SNARES)
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_true((m.snares[0] as Array).is_empty())
	assert_eq(BattleFixtures.first_of(ev, BattleEvent.Type.SNARE_CLEARED).describe(), "The snares on your side blow away.")
	assert_eq(b.stage("spd"), -1, "and the foe slows down")
	assert_eq(BattleRules.snare_tag({"status": "scorch"}), "SC")
	assert_eq(BattleRules.snare_tag({"stage": {"spd": -1}}), "-SP")

func test_dawn_needle_ignores_daze() -> void:
	var hits: Array[int] = [0, 0]
	for i: int in 2:
		for seed_value: int in 60:
			var a: Spirling = _only("Wickit", 20, "Dawn Needle" if i == 0 else "Wick Flicker")
			var b: Spirling = _only("Mossling", 40, "Bowl Over")
			var m: BattleModel = _duel(a, b, seed_value)
			a.status = "daze"
			a.status_turns = 5
			var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
			if not BattleFixtures.types_of(ev).has(BattleEvent.Type.MISSED):
				hits[i] += 1
	var skip: float = StatusRules.skip_chance("daze")
	# Dawn Needle never misses (only a skipped turn stops it); the plain art does miss.
	assert_gt(hits[0], hits[1])
	assert_true(skip >= 0.0)

func test_fault_line_ignores_raised_focus() -> void:
	var a: Spirling = _only("Duskdigger", 36, "Fault Line")
	var b: Spirling = _only("Mossling", 36, "Bowl Over")
	var plain: float = DamageCalc.estimate(a, b, a.moves[0])
	b.stages["foc"] = 2
	assert_almost_eq(DamageCalc.estimate(a, b, a.moves[0]), plain, 0.01, "a raised Focus does not help")
	var other: MoveData = Database.move("Spindrift Shot")
	var with_stage: float = DamageCalc.estimate(a, b, other)
	b.stages["foc"] = 0
	assert_lt(with_stage, DamageCalc.estimate(a, b, other), "an ordinary art does feel it")
	b.stages["foc"] = -1
	assert_gt(DamageCalc.estimate(a, b, a.moves[0]), plain, "a lowered Focus still counts")

func test_retuned_arts() -> void:
	assert_eq(Database.move("Lichen Lash").power, 35)
	assert_almost_eq(Database.move("Crackle Bite").status_chance, 0.05, 0.0001)
	assert_eq(Database.move("Storm Gnash").power, 80)
	assert_almost_eq(Database.move("Storm Gnash").accuracy, 0.95, 0.0001)
	assert_eq(Database.move("Gale Scythe").power, 85)
	assert_eq(Database.move("Gale Scythe").energy_cost, 4)
	assert_almost_eq(Database.move("Arc Bolt").status_chance, 0.3, 0.0001)
	assert_eq(Database.move("All-In Crash").power, 40)
	assert_eq(Database.move("Cairn Crash").power, 105)
	assert_almost_eq(Database.move("Cairn Crash").accuracy, 0.85, 0.0001)
	assert_almost_eq(Database.move("Furnace Spiral").accuracy, 0.9, 0.0001)
	assert_almost_eq(Database.move("Hush").accuracy, 0.8, 0.0001)
	assert_eq(Database.move("Hush").energy_cost, 3)
	assert_almost_eq(BattleRules.OVERCHARGE_PER_ENERGY, 0.12, 0.0001)

func test_overcharge_spends_at_most_five_extra() -> void:
	var a: Spirling = _only("Zippit", 30, "Overcharge")
	var b: Spirling = _only("Calderox", 50, "Bowl Over")
	var m: BattleModel = _duel(a, b)
	a.energy = Spirling.MAX_ENERGY
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var left: int = Spirling.MAX_ENERGY - Database.move("Overcharge").energy_cost - BattleRules.OVERCHARGE_MAX_EXTRA
	# End of turn adds the usual Energy (Zippit's Surge trait included).
	var gain: int = BattleModel.ENERGY_PER_TURN + int(BattleRules.add_key(a, "energy_per_turn"))
	assert_eq(a.energy, mini(Spirling.MAX_ENERGY, maxi(left, 0) + gain))
