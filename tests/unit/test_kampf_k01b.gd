extends GutTest
## KAMPF_PLAN_1000, areas "Zugablauf und Grundregeln" and "Energie und Overcharge", batch 2:
## guard priority +2, fair rolls, miss chance and Energy marks on the art card, Energy Crystal,
## Low Flame and Overflow, Energy lock, Energy hand-over and mirror, Long Breath, a free art,
## and the Static Veil cost cut on its home ground.

const Side := BattleModel.Side
const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _mk(species: String, moves: Array[String], level: int = 20) -> Spirling:
	return BattleFixtures.make(species, level, moves)

func _with_gift(s: Spirling, gift: String) -> Spirling:
	var sd: SpirlingData = s.data.duplicate()
	sd.trait_id = gift
	s.data = sd
	return s

# --- Item 3: priority +2 only for rare guard arts ---

func test_only_guard_arts_reach_priority_two() -> void:
	assert_eq(RulesBook.max_priority(), 2)
	for mv: MoveData in Database.moves.values():
		if mv.priority > 1:
			assert_eq(mv.kind, MoveData.Kind.STATUS, "%s: +2 is for guard arts" % mv.move_name)
			assert_true(mv.has_effect(&"status_veil"), "%s guards its side" % mv.move_name)
	assert_eq(Database.move("Calm Veil").priority, 2)

func test_calm_veil_goes_before_a_quick_art() -> void:
	var a := _mk("Mossling", ["Calm Veil"] as Array[String])
	var b := _mk("Zippit", ["Cinder Dash"] as Array[String])
	var m := BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false)
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0))
	assert_eq(int(BattleFixtures.first_of(ev, T.MOVE_USED).data.side), Side.PLAYER)

# --- Item 35: the foe never gets kinder rolls ---

func test_hit_chance_and_damage_rolls_ignore_the_side() -> void:
	var a := _mk("Kindlop", ["Cinder Breath"] as Array[String])
	var b := _mk("Kindlop", ["Cinder Breath"] as Array[String])
	var m := BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false)
	var mv: MoveData = a.moves[0]
	assert_eq(m.hit_chance(a, mv, b), m.hit_chance(b, mv, a))
	assert_eq(m.foe_crit_mult, 1.0, "no crit edge for the foe outside Story")
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	assert_eq(DamageCalc.compute(a, b, mv, r1), DamageCalc.compute(b, a, mv, r2))

# --- Items 14, 46: miss chance and the Energy thief mark ---

func test_card_shows_the_miss_chance() -> void:
	var me := _mk("Kindlop", ["Cinder Breath"] as Array[String])
	var m := BattleFixtures.model([me] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], false)
	var mv: MoveData = me.moves[0]
	var miss: int = roundi((1.0 - mv.accuracy) * 100.0)
	assert_gt(miss, 0)
	assert_eq(BattleInfo.miss_pct(m, me, mv), miss)
	assert_true(BattleInfo.card_lines(m, 0, mv).has("Misses %d%% of the time." % miss))
	me.status = "daze"
	assert_gt(BattleInfo.miss_pct(m, me, mv), miss, "Daze spoils the aim")

func test_energy_thieves_carry_a_mark() -> void:
	assert_eq(CommandMenu.art_marks(Database.move("Charge Mirror")), CommandMenu.ENERGY_THIEF_MARK)
	assert_eq(CommandMenu.art_marks(Database.move("Fuse Snap")), CommandMenu.ENERGY_THIEF_MARK)
	assert_eq(CommandMenu.art_marks(Database.move("Cinder Dash")), "^")
	assert_eq(CommandMenu.art_marks(Database.move("Cinder Nip")), "")

# --- Item 43: Energy Crystal ---

func test_energy_crystal_adds_start_energy() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	a.held = "energy_crystal"
	var m := BattleModel.new([a] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], false, 3, 0)
	m.start_energy_cut = [5, 0]
	m.start()
	assert_eq(a.energy, Spirling.START_ENERGY - 5 + int(BattleRules.held_info("energy_crystal").start_energy))
	assert_true(BattleRules.is_holdable("energy_crystal"))

# --- Items 48, 49: Low Flame and Overflow ---

func test_low_flame_cuts_dear_arts_only() -> void:
	var s := _with_gift(_mk("Kindlop", ["Cinder Nip"] as Array[String]), "low_flame")
	var dear := BattleFixtures.move(Elements.E.EMBER, 90)
	dear.energy_cost = 5
	var cheap := BattleFixtures.move(Elements.E.EMBER, 40)
	cheap.energy_cost = 4
	assert_eq(s.move_cost(dear), 4)
	assert_eq(s.move_cost(cheap), 4)

func test_overflow_hits_harder_with_a_full_bar() -> void:
	var dealt: Array[int] = []
	for full: bool in [false, true]:
		var a := _with_gift(_mk("Kindlop", ["Cinder Nip"] as Array[String]), "overflow")
		var b := _mk("Mossling", ["Cinder Nip"] as Array[String])
		var m := BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false, 11)
		a.energy = m.max_energy_of(Side.PLAYER) if full else 5
		var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
		for e: BattleEvent in ev:
			if e.type == T.DAMAGE and int(e.data.side) == Side.FOE:
				dealt.append(int(e.data.amount))
	assert_eq(dealt.size(), 2)
	assert_gt(dealt[1], dealt[0])

# --- Item 47: Energy lock ---

func test_energy_lock_holds_back_one_turn_of_gain() -> void:
	var a := _mk("Zippit", ["Fuse Snap"] as Array[String])
	var b := _mk("Mossling", ["Cinder Nip"] as Array[String], 30)
	var m := BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false)
	b.energy = 3
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	if not BattleFixtures.types_of(ev).has(T.MOVE_USED):
		return
	assert_true(BattleFixtures.types_of(ev).has(T.ENERGY_LOCKED))
	assert_eq(b.energy, 3 + m.rest_gain(), "Rest still works, the turn's own gain does not")
	assert_eq(b.energy_lock, 0, "only one turn")

# --- Items 56-58: Long Breath, Spark Share, Charge Mirror ---

func test_long_breath_gives_energy_and_costs_pace() -> void:
	var a := _mk("Zephlet", ["Long Breath"] as Array[String])
	var m := BattleFixtures.model([a] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], false)
	a.energy = 2
	m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	assert_eq(a.energy, 2 + 3 + BattleModel.ENERGY_PER_TURN)
	assert_eq(a.stage("spd"), -1)

func test_spark_share_hands_energy_to_the_ally() -> void:
	var a := _mk("Zippit", ["Spark Share"] as Array[String])
	var b := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var m := BattleModel.new([a, b] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], false, 5, 0)
	m.front_size = [2, 1]
	m.start()
	a.energy = 8
	b.energy = 2
	var ev: Array[BattleEvent] = m.submit_actions([BattleAction.make_move(Side.PLAYER, 0, 0), BattleAction.make_rest(Side.PLAYER, 1)] as Array[BattleAction])
	assert_true(BattleFixtures.types_of(ev).has(T.ENERGY_SHARED))
	assert_string_contains(BattleFixtures.first_of(ev, T.ENERGY_SHARED).describe(), "hands 3 Energy")

func test_spark_share_alone_does_nothing() -> void:
	var a := _mk("Zippit", ["Spark Share"] as Array[String])
	var m := BattleFixtures.model([a] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], false)
	assert_false(BattleFixtures.types_of(m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))).has(T.ENERGY_SHARED))

func test_charge_mirror_trades_energy() -> void:
	var a := _mk("Wickit", ["Charge Mirror"] as Array[String])
	var b := _mk("Mossling", ["Cinder Nip"] as Array[String])
	var m := BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false)
	a.energy = 2
	b.energy = 9
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	assert_true(BattleFixtures.types_of(ev).has(T.ENERGY_SWAPPED))
	var me_after: int = a.energy
	assert_gt(me_after, b.energy - m.rest_gain(), "the full bar went over")

func test_new_arts_read_on_the_card_and_can_be_taught() -> void:
	for n: String in ["Long Breath", "Spark Share", "Charge Mirror", "Fuse Snap", "Scrap Swipe"]:
		var mv: MoveData = Database.move(n)
		assert_not_null(mv, n)
		assert_eq(CommandMenu.move_info(mv).split("\n").size(), 4 + int(mv.priority > 0) + mv.effects.size(), n)
		assert_false(Database.item("echo_" + n.to_snake_case()).is_empty(), "%s has an Echo Crystal" % n)

# --- Item 44: a free art at half strength ---

func test_scrap_swipe_is_free_and_half_strength() -> void:
	var mv: MoveData = Database.move("Scrap Swipe")
	assert_eq(mv.energy_cost, 0)
	assert_eq(mv.power * 2, Database.move("Cinder Nip").power, "half a 2-Energy hit")
	var s := _mk("Kindlop", ["Scrap Swipe"] as Array[String])
	s.energy = 0
	assert_true(s.can_afford(mv))
	s.energy_tax = 2
	assert_eq(s.move_cost(mv), BattleRules.ENERGY_TAX_COST, "a tax still bites")

# --- Item 75: Static Veil on its home ground ---

func test_static_veil_cuts_volt_costs_only_as_the_home_field() -> void:
	var mv: MoveData = Database.move("Fuse Snap")
	var a := _mk("Zippit", ["Fuse Snap"] as Array[String])
	var home := BattleModel.new([a] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], false, 3, 0)
	home.field = "static_veil"
	home.start()
	assert_eq(a.move_cost(mv), mv.energy_cost - BattleRules.FIELD_COST_CUT)
	assert_eq(a.move_cost(Database.move("Cinder Nip")), Database.move("Cinder Nip").energy_cost, "other elements pay in full")
	var b := _mk("Zippit", ["Fuse Snap"] as Array[String])
	var called := BattleFixtures.model([b] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], false)
	called.set_field("static_veil")
	assert_eq(b.move_cost(mv), mv.energy_cost, "a called veil brings Energy, not cheaper arts")
	assert_true(KampfChecks.field_errors().is_empty())

# --- Items 61, 80: Energy in the balance report ---

func test_team_report_carries_the_energy_per_art() -> void:
	var r: Dictionary = BalanceSim.run_team(20, 4, 9)
	assert_true(r.has("energy_per_art"))
	assert_gt(float(r.energy_per_art), 0.0)
	assert_string_contains(BalanceSim.report(r), "Energy per art picked:")
	assert_false(BalanceSim.energy_line(2.5).contains("outside"))
	assert_true(BalanceSim.energy_line(6.0).contains("outside"))
