extends GutTest
## Battle depth (items 5–7, 9, 10, 12): stat stages, traits, held items, Rift fields,
## Overcharge and Warden rules.

const E := Elements.E

func before_all() -> void:
	Database.load_all()

func test_stage_multipliers_are_symmetric() -> void:
	assert_eq(BattleRules.stage_mult(0), 1.0)
	assert_eq(BattleRules.stage_mult(1), 1.5)
	assert_eq(BattleRules.stage_mult(-1), 1.0 / 1.5)
	assert_eq(BattleRules.stage_mult(9), BattleRules.stage_mult(BattleRules.STAGE_MAX), "clamped")

func test_stat_move_raises_and_clamps() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 20, ["Kindle Up"] as Array[String])
	var b: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"] as Array[String])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling])
	m.start()
	var atk_before: int = a.effective_atk()
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.STAT_CHANGED))
	assert_eq(a.stage("atk"), 1)
	assert_gt(a.effective_atk(), atk_before)
	for i: int in 4:
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(a.stage("atk"), BattleRules.STAGE_MAX)
	a.end_battle()
	assert_eq(a.stage("atk"), 0, "stages reset after battle")

func test_kindling_turns_scorch_into_a_boost() -> void:
	var k: Spirling = BattleFixtures.make("Kindlop", 20)
	var plain: int = k.effective_atk()
	k.status = "scorch"
	assert_gt(k.effective_atk(), plain)
	var m: Spirling = BattleFixtures.make("Mossling", 20)
	var m_plain: int = m.effective_atk()
	m.status = "scorch"
	assert_lt(m.effective_atk(), m_plain)

func test_trait_immunity_blocks_status() -> void:
	var w: Spirling = BattleFixtures.make("Wickit", 15)
	var b: Spirling = BattleFixtures.make("Mossling", 15)
	var m: BattleModel = BattleFixtures.model([w] as Array[Spirling], [b] as Array[Spirling])
	m.start()
	assert_false(m.apply_status(0, "drowse"), "Light Sleeper")
	assert_true(m.apply_status(0, "soak"))

func test_surge_and_spark_coil_add_energy() -> void:
	var z: Spirling = BattleFixtures.make("Zippit", 15, ["Arc Bolt"] as Array[String])
	z.held = "spark_coil"
	var b: Spirling = BattleFixtures.make("Mossling", 15, ["Bowl Over"] as Array[String])
	var m: BattleModel = BattleFixtures.model([z] as Array[Spirling], [b] as Array[Spirling])
	m.start()
	z.energy = 2
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	# 2 + REST 2 + per turn 1 + Surge 1 + Spark Coil 1
	assert_eq(z.energy, 7)

func test_deep_roots_heals_each_turn() -> void:
	var mo: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"] as Array[String])
	var b: Spirling = BattleFixtures.make("Zippit", 20, ["Bowl Over"] as Array[String])
	var m: BattleModel = BattleFixtures.model([mo] as Array[Spirling], [b] as Array[Spirling])
	m.start()
	mo.hp = mo.max_hp() / 2
	var before: int = mo.hp
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_gt(mo.hp, before)

func test_field_boosts_and_weakens() -> void:
	assert_eq(BattleRules.field_mult("ash_storm", E.EMBER), BattleRules.FIELD_BOOST)
	assert_eq(BattleRules.field_mult("ash_storm", E.TIDE), BattleRules.FIELD_WEAKEN)
	assert_eq(BattleRules.field_mult("ash_storm", E.VOLT), 1.0)
	assert_eq(BattleRules.field_mult("", E.EMBER), 1.0)

func test_overcharge_spends_all_energy_and_hits_harder() -> void:
	var dmg: Array[int] = []
	for spare: int in [0, 8]:
		var z: Spirling = BattleFixtures.make("Zippit", 20, ["Overcharge"] as Array[String])
		var b: Spirling = BattleFixtures.make("Mossling", 40, ["Bowl Over"] as Array[String])
		var m: BattleModel = BattleFixtures.model([z] as Array[Spirling], [b] as Array[Spirling], true, 11)
		m.start()
		z.energy = 2 + spare
		var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
		var hit: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.DAMAGE)
		dmg.append(int(hit.data.amount))
		# Overcharge spends at most OVERCHARGE_MAX_EXTRA of the spare Energy (plan area 2, item 583).
		var kept: int = maxi(0, spare - BattleRules.OVERCHARGE_MAX_EXTRA)
		assert_eq(z.energy, kept + 1 + 1, "spent up to the cap, then +1 per turn and +1 Surge")
	assert_gt(dmg[1], dmg[0])

func test_warden_rules_apply() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 15, ["Bowl Over"] as Array[String])
	var b: Spirling = BattleFixtures.make("Mossling", 15, ["Bowl Over"] as Array[String])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false)
	m.foe_rule = "undertow"
	var ev: Array[BattleEvent] = m.start()
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.RULE))
	assert_eq(a.stage("spd"), -1)
	var m2: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 15, ["Bowl Over"] as Array[String])] as Array[Spirling], [b] as Array[Spirling], false)
	m2.foe_rule = "ember_pulse"
	m2.start()
	b.energy = 5
	m2.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(b.energy, 5 + 2 + 1 + 1, "rest 2, per turn 1, Ember Pulse 1")

func test_held_items_round_trip_through_save() -> void:
	var s: Spirling = BattleFixtures.make("Zippit", 10)
	s.held = "keen_lens"
	var back: Spirling = Spirling.from_dict(s.to_dict())
	assert_eq(back.held, "keen_lens")

func test_set_held_moves_items_between_bag_and_spirling() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	assert_false(GameState.set_held(s, "iron_burr"), "not in the bag yet")
	GameState.add_item("iron_burr")
	GameState.add_item("swift_feather")
	assert_true(GameState.set_held(s, "iron_burr"))
	assert_eq(GameState.item_count("iron_burr"), 0)
	assert_true(GameState.set_held(s, "swift_feather"))
	assert_eq(GameState.item_count("iron_burr"), 1, "the old one goes back")
	assert_false(GameState.set_held(s, "tonic"), "tonics can't be held")
	assert_true(GameState.set_held(s, ""))
	assert_eq(s.held, "")
	assert_eq(GameState.item_count("swift_feather"), 1)

func test_every_species_has_a_known_trait() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		assert_true(BattleRules.TRAITS.has(sd.trait_id), "%s trait '%s'" % [sd.species_name, sd.trait_id])
