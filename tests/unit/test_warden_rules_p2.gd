extends GutTest
## Plan area 2: rematch kits (661) and the Warden field rules Ash Rain and Tide Turn with the
## rule keys "difficulty" and stacking (675-677).

func before_all() -> void:
	Database.load_all()

func _npc(map_id: String, npc_id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func _model(rule: String, field: String) -> BattleModel:
	var me: Spirling = BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String])
	var m := BattleModel.new([me] as Array[Spirling], [foe] as Array[Spirling], false, 7, 1)
	m.field = field
	m.foe_rule = rule
	m.start()
	return m

func _rest(m: BattleModel) -> Array[BattleEvent]:
	return m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))

func test_rules_name_their_difficulties_and_stack() -> void:
	for id: String in BattleRules.RULES:
		assert_true(BattleRules.RULES[id].has("difficulty"), id)
	assert_eq(BattleRules.rule_stack(1), 1)
	assert_eq(BattleRules.rule_stack(2), 2)
	assert_eq(BattleRules.split_rules("ember_pulse+ash_rain+nope"), ["ember_pulse", "ash_rain"] as Array[String])
	assert_eq(TrainerData.rule_for(_npc("cinder_rift", "warden_orrin"), 2), "ember_pulse+ash_rain")
	assert_eq(TrainerData.rule_for(_npc("tide_rift", "warden_maelis"), 3), "undertow+tide_turn")
	assert_eq(TrainerData.rule_for(_npc("cinder_rift", "warden_orrin"), 1), "ember_pulse")
	assert_eq(WorldValidator.validate().size(), 0)

func test_stacked_rules_both_apply() -> void:
	var m: BattleModel = _model("ember_pulse+ash_rain", "ash_storm")
	var rules: int = 0
	for e: BattleEvent in m._events:
		rules += 1 if e.type == BattleEvent.Type.RULE else 0
	assert_eq(rules, 2)
	var foe: Spirling = m.active_spirling(1)
	foe.energy = 0
	m.active_spirling(0).energy = 0
	_rest(m)
	assert_gt(foe.energy, m.active_spirling(0).energy, "Ember Pulse still pays out")

func test_ash_rain_locks_the_storm_for_three_turns() -> void:
	var m: BattleModel = _model("ash_rain", "ash_storm")
	assert_eq(m.field, "ash_storm")
	assert_eq(m.field_lock, 3)
	m.active_spirling(0).moves[0] = Database.move("Tide Call")
	m.active_spirling(0).energy = Spirling.MAX_ENERGY
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.field, "ash_storm", "a Resonance art can't replace it yet")
	var e: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.FIELD_EXTENDED)
	assert_not_null(e)
	assert_eq(e.describe(), "The Ash Storm won't give way yet.")
	_rest(m)
	_rest(m)
	assert_eq(m.field_lock, 0)
	m.active_spirling(0).energy = Spirling.MAX_ENERGY
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.field, "high_tide", "after 3 turns the field can change")

func test_tide_turn_comes_and_goes_and_is_announced() -> void:
	var m: BattleModel = _model("tide_turn", "high_tide")
	var seen: Array[String] = []
	var next_at: Array[int] = []
	for t: int in 10:
		seen.append(m.field)
		for e: BattleEvent in _rest(m):
			if e.type == BattleEvent.Type.FIELD_NEXT:
				next_at.append(t + 1)
	assert_eq(seen, ["high_tide", "high_tide", "", "", "high_tide", "high_tide", "", "", "high_tide", "high_tide"] as Array[String])
	assert_eq(next_at, [3, 7] as Array[int], "announced at the end of turns 3 and 7")

func test_rematch_kits_follow_the_new_ring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var neve: Dictionary = _npc("saltmarsh", "neve")
	var team: Array[Spirling] = TrainerData.rematch_team(neve, "Kindlop", rng, 40, 50, 1)
	var puddlet: Spirling = team[0]
	assert_gt(puddlet.level, 30)
	var names: Array[String] = []
	for mv: MoveData in puddlet.moves:
		names.append(mv.move_name)
	assert_has(names, "Tide Call", "named arts stay")
	var fresh: Array[MoveData] = puddlet.data.default_moves(puddlet.level, 4)
	var from_new_ring: int = 0
	for mv: MoveData in fresh:
		if mv.move_name in names:
			from_new_ring += 1
	assert_gte(from_new_ring, 2, "the rest of the kit comes from the new ring")
