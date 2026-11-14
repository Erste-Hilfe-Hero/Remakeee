extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 780 to 787, 789, 790, 793): rule variants.

func before_all() -> void:
	Database.load_all()

func _model(ids: Array[String], foe_moves: Array[String] = ["Bowl Over"]) -> BattleModel:
	var a: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Dash", "Glow Knuckle"] as Array[String])
	var b: Spirling = BattleFixtures.make("Puddlet", 20, ["Fizz Pop"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Mossling", 20, foe_moves)
	var m := BattleModel.new([a, b] as Array[Spirling], [foe] as Array[Spirling], false, 7, 0)
	m.variants = ids
	m.start()
	return m

func test_file_is_clean_and_only_uses_known_keys() -> void:
	assert_gte(BattleRules.variants().size(), 9)
	assert_eq(BattleRules.validate_variants(), [] as Array[String])

func test_combining_is_limited_and_excludes_are_refused() -> void:
	assert_eq(BattleRules.variant_conflict(["swap_toll", "late_end", "no_home_edge"] as Array[String]), "")
	assert_ne(BattleRules.variant_conflict(["swap_toll", "late_end", "no_home_edge", "short_breath"] as Array[String]), "", "at most 3")
	assert_ne(BattleRules.variant_conflict(["glass_blades", "tough_round"] as Array[String]), "")
	assert_ne(BattleRules.variant_conflict(["spark_poor", "full_charge"] as Array[String]), "")
	assert_ne(BattleRules.variant_conflict(["nope"] as Array[String]), "")
	assert_eq(BattleRules.variant_values(["glass_blades", "tough_round"] as Array[String]), {})
	var m: BattleModel = _model(["glass_blades", "tough_round"] as Array[String])
	assert_eq(m.variants, [] as Array[String], "a refused set plays normal rules")

func test_normal_rules_are_the_old_numbers() -> void:
	var v: Dictionary = BattleRules.variant_values([] as Array[String])
	assert_eq(int(v.start_energy), Spirling.START_ENERGY)
	assert_eq(int(v.max_energy), Spirling.MAX_ENERGY)
	assert_eq(int(v.energy_per_turn), BattleModel.ENERGY_PER_TURN)
	assert_eq(int(v.rest_energy), BattleModel.REST_ENERGY)
	assert_eq(float(v.stab), DamageCalc.STAB)

func test_spark_poor_caps_energy_at_six() -> void:
	var m: BattleModel = _model(["spark_poor"] as Array[String])
	var me: Spirling = m.active_spirling(0)
	assert_eq(me.energy, 6)
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(me.energy, 6)

func test_full_charge_gives_no_energy_per_turn_and_three_per_rest() -> void:
	var m: BattleModel = _model(["full_charge"] as Array[String])
	var me: Spirling = m.active_spirling(0)
	me.energy = 4
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(me.energy, 7, "rest +3, no gain at the end of the turn")

func test_swap_toll_costs_the_newcomer_two_energy() -> void:
	var m: BattleModel = _model(["swap_toll"] as Array[String])
	m.submit_turn(BattleAction.make_swap(0, 1), BattleAction.make_rest(1))
	var b: Spirling = m.active_spirling(0)
	assert_eq(b.data.species_name, "Puddlet")
	assert_eq(b.energy, Spirling.START_ENERGY - 2 + BattleModel.ENERGY_PER_TURN, "minus 2, then the end-of-turn gain")

func test_glass_blades_halve_vigor_for_the_battle_only() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Dash"] as Array[String])
	var full: int = a.max_hp()
	var foe: Spirling = BattleFixtures.make("Mossling", 5, ["Bowl Over"] as Array[String])
	var m := BattleModel.new([a] as Array[Spirling], [foe] as Array[Spirling], false, 7, 0)
	m.variants = ["glass_blades"] as Array[String]
	m.start()
	assert_eq(a.max_hp(), int(full * 0.5))
	assert_eq(foe.hp, foe.max_hp())
	while not m.is_finished():
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(a.max_hp(), full, "back to normal after the battle")
	assert_eq(a.hp_mult, 1.0)

func test_home_edge_changes_damage_only() -> void:
	var dealt: Array[int] = []
	for ids: Array in [[], ["no_home_edge"], ["strong_reactions"]]:
		var typed: Array[String] = []
		typed.assign(ids)
		var m: BattleModel = _model(typed)
		var foe: Spirling = m.active_spirling(1)
		var before: int = foe.hp
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
		dealt.append(before - foe.hp)
	assert_lt(dealt[1], dealt[0], "no own-element bonus")
	assert_eq(dealt[2], dealt[0], "no reaction here, no change")

func test_strong_reactions_stretch_the_factor() -> void:
	var dealt: Array[int] = []
	for ids: Array in [[], ["strong_reactions"]]:
		var me: Spirling = BattleFixtures.make("Zippit", 20, ["Static Tag"] as Array[String])
		var foe: Spirling = BattleFixtures.make("Riptail", 30, ["Bowl Over"] as Array[String])
		var m := BattleModel.new([me] as Array[Spirling], [foe] as Array[Spirling], false, 7, 0)
		m.variants.assign(ids)
		m.start()
		foe.status = "soak"
		foe.status_turns = 3
		var before: int = foe.hp
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
		dealt.append(before - foe.hp)
	assert_gt(dealt[1], dealt[0])

func test_short_breath_ends_every_status_within_two_turns() -> void:
	var m: BattleModel = _model(["short_breath"] as Array[String])
	m.apply_status(1, "scorch")
	assert_between(m.active_spirling(1).status_turns, 1, 2)
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(m.active_spirling(1).status, "")

func test_late_end_chips_from_turn_fifteen() -> void:
	var m: BattleModel = _model(["late_end"] as Array[String])
	m.turn = 15
	var me: Spirling = m.active_spirling(0)
	var before: int = me.hp
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_lt(me.hp, before)

func test_variants_survive_a_replay() -> void:
	var m: BattleModel = BattleModel.new([BattleFixtures.make("Kindlop", 20)] as Array[Spirling], [BattleFixtures.make("Mossling", 20)] as Array[Spirling], false, 7, 1)
	m.variants = ["swap_toll", "late_end"] as Array[String]
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "lake")
	assert_eq(BattleReplay.build_model(JSON.parse_string(JSON.stringify(snap))).variants, ["swap_toll", "late_end"] as Array[String])

func test_stage_still_locks_stage_changes_and_stage_only_arts() -> void:
	var me: Spirling = BattleFixtures.make("Kindlop", 20, ["Kindle Up", "Cinder Dash"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"] as Array[String])
	var m := BattleModel.new([me] as Array[Spirling], [foe] as Array[Spirling], false, 7, 0)
	m.variants = ["stage_still"] as Array[String]
	m.start()
	assert_true(BattleRules.stage_only(me.moves[0]), "Kindle Up only raises a stage")
	assert_true(m.move_locked(me.moves[0]))
	assert_false(m.move_locked(me.moves[1]))
	for a: BattleAction in m.legal_actions(0):
		assert_false(a.kind == BattleAction.Kind.MOVE and a.move_index == 0, "locked art is not offered")
	assert_false(m.is_legal(BattleAction.make_move(0, 0)))
	m.change_stage(0, "atk", 1)
	assert_eq(me.stage("atk"), 0)

func test_no_rest_only_offers_rest_as_a_pass_and_feeds_three_energy() -> void:
	var m: BattleModel = _model(["no_rest"] as Array[String])
	var me: Spirling = m.active_spirling(0)
	for a: BattleAction in m.legal_actions(0):
		assert_ne(a.kind, BattleAction.Kind.REST, "an art can be paid, so no Rest")
	me.energy = 0
	var kinds: Array[int] = []
	for a: BattleAction in m.legal_actions(0):
		kinds.append(a.kind)
	assert_true(BattleAction.Kind.REST in kinds, "with nothing to pay, Rest stays as a pass")
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(me.energy, 3)
	# The AI never rests by choice while it can pay an art.
	var ai := BattleAI.new(2, "wall")
	for i: int in 5:
		assert_ne(ai.choose(m, 1).kind, BattleAction.Kind.REST)
		m.submit_turn(BattleAction.make_swap(0, 1) if i == 0 else BattleAction.make_move(0, 0), ai.choose(m, 1))
		if m.is_finished():
			break

func test_field_swirl_announces_then_lays_a_field_every_three_turns() -> void:
	var m: BattleModel = _model(["field_swirl"] as Array[String])
	var seen: Array[int] = []
	m.event_emitted.connect(func(e: BattleEvent) -> void:
		if e.type in [BattleEvent.Type.FIELD_NEXT, BattleEvent.Type.FIELD]:
			seen.append(e.type))
	var next: Dictionary = {}
	m.event_emitted.connect(func(e: BattleEvent) -> void:
		if e.type == BattleEvent.Type.FIELD_NEXT:
			next["field"] = str(e.data.field))
	for i: int in 4:
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(seen.slice(0, 2), [BattleEvent.Type.FIELD_NEXT, BattleEvent.Type.FIELD] as Array[int], "announced, then laid a turn later")
	assert_eq(m.field, str(next.get("field", "?")), "the announced field is the one that comes")
	assert_true(BattleEvent.new(BattleEvent.Type.FIELD_NEXT, {"label": "Ash Storm"}).describe().contains("Ash Storm"))
