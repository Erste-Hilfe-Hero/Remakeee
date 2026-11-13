extends GutTest
## docs/KAMPF_PLAN_1000.md, "Mehrfachkämpfe" (items 361 to 400): support arts (team heal, ally
## heal, team guard, decoy, cover), the formation bonus, aim lines, remembered and automatic
## targets, slot lines for screen readers, the stair's double floors and the old rules kept.

const Side := BattleModel.Side
const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _mk(name: String, moves: Array[String] = [], level: int = 30) -> Spirling:
	return BattleFixtures.make(name, level, moves)

func _model(mine: Array[Spirling], theirs: Array[Spirling], front: Array[int], wild: bool = false, seed_value: int = 11) -> BattleModel:
	var m := BattleModel.new(mine, theirs, wild, seed_value, 0)
	m.front_size = front
	return m

func _rests(m: BattleModel, side: int) -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	for s: int in m.slot_count(side):
		out.append(BattleAction.make_rest(side, s))
	return out

func _turn(m: BattleModel, mine: Array[BattleAction], theirs: Array[BattleAction]) -> Array[BattleEvent]:
	var all: Array[BattleAction] = []
	all.append_array(mine)
	all.append_array(theirs)
	return m.submit_actions(all)

func test_support_arts_exist_and_are_learned() -> void:
	for pair: Array in [["Mending Chorus", &"heal_team", "Haloon"], ["Kindred Balm", &"heal_ally", "Vitrill"],
			["Shell Ring", &"team_guard", "Plinthlet"], ["Lure Dance", &"decoy", "Cloudmop"], ["Breakwater Stand", &"cover", "Covepup"]]:
		var mv: MoveData = Database.move(str(pair[0]))
		assert_not_null(mv, str(pair[0]))
		assert_true(mv.has_effect(pair[1]), str(pair[0]))
		assert_true(EffectRegistry.has_effect(pair[1]))
		var learned: bool = false
		for m2: MoveData in Database.species(str(pair[2])).learnset_moves:
			learned = learned or m2.move_name == str(pair[0])
		assert_true(learned, "%s learns %s" % [pair[2], pair[0]])

func test_mending_chorus_heals_the_whole_side() -> void:
	var a: Spirling = _mk("Haloon", ["Mending Chorus"])
	var b: Spirling = _mk("Kindlop", ["Cinder Nip"])
	var m := _model([a, b] as Array[Spirling], [_mk("Mossling"), _mk("Puddlet")] as Array[Spirling], [2, 2])
	m.start()
	a.hp = a.max_hp() / 2
	b.hp = b.max_hp() / 2
	var before: Array[int] = [a.hp, b.hp]
	_turn(m, [BattleAction.make_move(Side.PLAYER, 0, 0, 0), BattleAction.make_rest(Side.PLAYER, 1)], _rests(m, Side.FOE))
	assert_gt(a.hp, before[0])
	assert_gt(b.hp, before[1])

func test_kindred_balm_tends_the_weakest_ally() -> void:
	var a: Spirling = _mk("Vitrill", ["Kindred Balm"])
	var b: Spirling = _mk("Kindlop", ["Cinder Nip"])
	var c: Spirling = _mk("Puddlet", ["Fizz Pop"])
	var m := _model([a, b, c] as Array[Spirling], [_mk("Mossling")] as Array[Spirling], [3, 1])
	m.start()
	b.hp = b.max_hp() / 4
	c.hp = c.max_hp() / 2
	a.hp = a.max_hp() / 5
	assert_eq(MultiRules.weakest_ally(m, Side.PLAYER, 0), 1, "the user itself does not count")
	var hb: int = b.hp
	var hc: int = c.hp
	_turn(m, [BattleAction.make_move(Side.PLAYER, 0, 0, 0), BattleAction.make_rest(Side.PLAYER, 1), BattleAction.make_rest(Side.PLAYER, 2)], _rests(m, Side.FOE))
	assert_gt(b.hp, hb)
	assert_eq(c.hp, hc)

func test_shell_ring_guards_the_side_then_fades() -> void:
	var plain: int = 0
	var guarded: int = 0
	for g: bool in [false, true]:
		var arts: Array[String] = []
		arts.append("Shell Ring" if g else "Pebble Toss")
		var p: Spirling = _mk("Plinthlet", arts)
		var k: Spirling = _mk("Kindlop", ["Cinder Nip"])
		var foe: Spirling = _mk("Smoldrake", ["Cinder Nip"])
		var m := _model([p, k] as Array[Spirling], [foe, _mk("Mossling")] as Array[Spirling], [2, 2], false, 3)
		m.start()
		if g:
			MultiRules.raise(m, Side.PLAYER, 0, "team_guard", 3)
		assert_eq(MultiRules.guard_mult(m, Side.PLAYER), 0.75 if g else 1.0)
		var est: float = DamageCalc.estimate(foe, k, foe.moves[0]) * BattleRules.damage_mult(foe, k, foe.moves[0], m.field) * MultiRules.guard_mult(m, Side.PLAYER)
		if g:
			guarded = roundi(est)
		else:
			plain = roundi(est)
	assert_lt(guarded, plain)
	var m2 := _model([_mk("Plinthlet", ["Shell Ring"]), _mk("Kindlop")] as Array[Spirling], [_mk("Mossling"), _mk("Puddlet")] as Array[Spirling], [2, 2])
	m2.start()
	var ev: Array[BattleEvent] = _turn(m2, [BattleAction.make_move(Side.PLAYER, 0, 0, 0), BattleAction.make_rest(Side.PLAYER, 1)], _rests(m2, Side.FOE))
	var up: BattleEvent = BattleFixtures.first_of(ev, T.SUPPORT)
	assert_not_null(up)
	assert_string_contains(up.describe(), "guard over its whole side for 3 turns")
	var ended: bool = false
	for i: int in 3:
		for e: BattleEvent in _turn(m2, _rests(m2, Side.PLAYER), _rests(m2, Side.FOE)):
			ended = ended or (e.type == T.SUPPORT and bool(e.data.get("ended", false)))
	assert_true(ended, "the guard fades after its turns")
	assert_eq(MultiRules.guard_mult(m2, Side.PLAYER), 1.0)

func test_decoy_draws_aimed_arts_but_not_sweeps() -> void:
	var m := _model([_mk("Cloudmop", ["Lure Dance"]), _mk("Kindlop")] as Array[Spirling], [_mk("Mossling"), _mk("Puddlet")] as Array[Spirling], [2, 2])
	m.start()
	MultiRules.raise(m, Side.PLAYER, 0, "decoy", 2)
	var single := MoveData.new()
	single.target = "single"
	var sweep := MoveData.new()
	sweep.target = "foes"
	assert_eq(m.move_targets(Side.FOE, single, 1), [0] as Array[int], "an art aimed at slot 1 goes to the decoy")
	assert_eq(m.move_targets(Side.FOE, sweep), [0, 1] as Array[int], "a sweep still reaches everyone")
	assert_eq(m.move_targets(Side.PLAYER, single, 1), [1] as Array[int], "the player's own aim is untouched")

func test_cover_takes_hits_meant_for_the_weakest_ally() -> void:
	var c: Spirling = _mk("Covepup", ["Breakwater Stand"])
	var k: Spirling = _mk("Kindlop")
	var z: Spirling = _mk("Zippit")
	var m := _model([c, k, z] as Array[Spirling], [_mk("Mossling")] as Array[Spirling], [3, 1])
	m.start()
	z.hp = z.max_hp() / 4
	var ev: Array[BattleEvent] = _turn(m, [BattleAction.make_move(Side.PLAYER, 0, 0, 0), BattleAction.make_rest(Side.PLAYER, 1), BattleAction.make_rest(Side.PLAYER, 2)], _rests(m, Side.FOE))
	var up: BattleEvent = BattleFixtures.first_of(ev, T.SUPPORT)
	assert_not_null(up)
	assert_eq(up.describe(), "%s steps in front of %s!" % [c.display_name(), z.display_name()])
	var single := MoveData.new()
	assert_eq(m.move_targets(Side.FOE, single, 2), [0] as Array[int], "the ward is covered")
	assert_eq(m.move_targets(Side.FOE, single, 1), [1] as Array[int], "others are not")

func test_cover_alone_has_nobody_to_cover() -> void:
	var c: Spirling = _mk("Covepup", ["Breakwater Stand"])
	var m := BattleFixtures.model([c] as Array[Spirling], [_mk("Mossling")] as Array[Spirling])
	m.start()
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(BattleFixtures.first_of(ev, T.SUPPORT).describe(), "%s has nobody to cover." % c.display_name())

func test_ai_uses_a_team_heal_when_the_side_is_hurt() -> void:
	var a: Spirling = _mk("Haloon", ["Mending Chorus", "Cinder Nip"])
	var b: Spirling = _mk("Kindlop")
	var m := _model([_mk("Mossling"), _mk("Puddlet")] as Array[Spirling], [a, b] as Array[Spirling], [2, 2])
	m.start()
	var fx: Dictionary = Database.move("Mending Chorus").effects[0]
	assert_eq(MultiRules.ai_score(m, Side.FOE, 0, fx), 0.0, "nothing to mend at full Vigor")
	a.hp = a.max_hp() / 3
	b.hp = b.max_hp() / 3
	assert_gt(MultiRules.ai_score(m, Side.FOE, 0, fx), 10.0)

func test_formation_bonus_for_two_stone_spirlings() -> void:
	var m := _model([_mk("Plinthlet"), _mk("Shalebat"), _mk("Kindlop")] as Array[Spirling], [_mk("Mossling"), _mk("Puddlet")] as Array[Spirling], [3, 2])
	var ev: Array[BattleEvent] = m.start()
	assert_eq(m.active_spirling(Side.PLAYER, 0).stage("def"), 1)
	assert_eq(m.active_spirling(Side.PLAYER, 1).stage("def"), 1)
	assert_eq(m.active_spirling(Side.PLAYER, 2).stage("def"), 0, "the Ember Spirling is not in the wall")
	var line: BattleEvent = BattleFixtures.first_of(ev, T.SUPPORT)
	assert_not_null(line)
	assert_string_contains(line.describe(), "Stone Wall")

func test_no_formation_bonus_in_one_on_one_or_for_foes() -> void:
	var m := BattleFixtures.model([_mk("Plinthlet")] as Array[Spirling], [_mk("Shalebat"), _mk("Talusk")] as Array[Spirling])
	m.start()
	assert_eq(m.active_spirling(Side.PLAYER).stage("def"), 0)
	var m2 := _model([_mk("Kindlop"), _mk("Puddlet")] as Array[Spirling], [_mk("Plinthlet"), _mk("Shalebat")] as Array[Spirling], [2, 2])
	m2.start()
	assert_eq(m2.active_spirling(Side.FOE, 0).stage("def"), 0, "only the Wayfarer's formation counts")

func test_aim_line_and_targets() -> void:
	assert_eq(MultiRules.aim_line("Kelpup", 35, 2.0), "Kelpup ~35% x2")
	assert_eq(MultiRules.aim_line("Kelpup", -1, -1.0), "Kelpup")
	assert_eq(MultiRules.default_target(2, [0, 2] as Array[int]), 2, "the last aim is kept")
	assert_eq(MultiRules.default_target(1, [0, 2] as Array[int]), 0, "a fallen target falls back")
	assert_eq(MultiRules.default_target(1, [] as Array[int]), -1)
	var me: Spirling = _mk("Puddlet", ["Fizz Pop"])
	var m := _model([me] as Array[Spirling], [_mk("Mossling"), _mk("Kindlop")] as Array[Spirling], [1, 2])
	m.start()
	assert_eq(MultiRules.best_target(m, me, me.moves[0]), 1, "Tide aims at the Ember foe")

func test_slot_lines_for_screen_readers() -> void:
	var m := _model([_mk("Kindlop"), _mk("Puddlet")] as Array[Spirling], [_mk("Mossling"), _mk("Zippit")] as Array[Spirling], [2, 2])
	m.start()
	var z: Spirling = m.active_spirling(Side.FOE, 1)
	assert_eq(MultiRules.slot_spoken(m, Side.FOE, 1), "Foe, slot 2 of 2: %s, Vigor %d of %d" % [z.display_name(), z.hp, z.max_hp()])
	assert_string_contains(MultiRules.slot_spoken(m, Side.PLAYER, 0), "Yours, slot 1 of 2")

func test_stair_has_double_floors() -> void:
	assert_eq(MultiRules.tower_front(5, false), [2, 2])
	assert_eq(MultiRules.tower_front(10, true), [1, 1], "Warden floors stay as they are")
	assert_eq(MultiRules.tower_front(7, false), [1, 1])

func test_sweeps_never_hit_allies() -> void:
	var m := _model([_mk("Kindlop"), _mk("Puddlet")] as Array[Spirling], [_mk("Mossling"), _mk("Zippit")] as Array[Spirling], [2, 2])
	m.start()
	var sweep := MoveData.new()
	sweep.target = "foes"
	for t: int in m.move_targets(Side.PLAYER, sweep):
		assert_true(t < m.slot_count(Side.FOE))
	assert_eq(m.move_targets(Side.PLAYER, sweep).size(), 2)

func test_running_only_from_wild_hordes() -> void:
	var wild := _model([_mk("Kindlop"), _mk("Puddlet")] as Array[Spirling], [_mk("Mossling"), _mk("Zippit")] as Array[Spirling], [2, 2], true)
	wild.start()
	var tamer := _model([_mk("Kindlop"), _mk("Puddlet")] as Array[Spirling], [_mk("Mossling"), _mk("Zippit")] as Array[Spirling], [2, 2], false)
	tamer.start()
	assert_true(wild.is_legal(BattleAction.make_run(Side.PLAYER, 0)))
	assert_false(tamer.is_legal(BattleAction.make_run(Side.PLAYER, 0)))

func test_supports_survive_a_full_auto_battle() -> void:
	for sd: int in 6:
		var mine: Array[Spirling] = [_mk("Haloon", ["Mending Chorus", "Cinder Nip"]), _mk("Covepup", ["Breakwater Stand", "Fizz Pop"]), _mk("Cloudmop", ["Lure Dance", "Kite Cut"])]
		var theirs: Array[Spirling] = [_mk("Plinthlet", ["Shell Ring", "Pebble Toss"]), _mk("Vitrill", ["Kindred Balm", "Cinder Nip"]), _mk("Kindlop")]
		var m := BattleModel.new(mine, theirs, false, sd, 2)
		m.front_size = [3, 3]
		m.start()
		var brain := BattleAI.new(2)
		var guard: int = 0
		while not m.is_finished() and guard < 200:
			guard += 1
			if m.needs_player_switch():
				m.submit_switch(m.swap_candidates(Side.PLAYER, m.switch_slot())[0])
				continue
			var acts: Array[BattleAction] = []
			for slot: int in m.player_slots():
				acts.append(brain.choose(m, Side.PLAYER, slot))
			m.submit_actions(acts)
		assert_true(m.is_finished(), "seed %d ends" % sd)

func test_log_filter_keeps_one_side_and_shared_lines() -> void:
	var lines: Array[String] = ["a mine", "b foe", "c both", "d mine"]
	var sides: Array[int] = [Side.PLAYER, Side.FOE, -1, Side.PLAYER]
	assert_eq(MultiRules.filter_log(lines, sides, 0), lines)
	assert_eq(MultiRules.filter_log(lines, sides, 1), ["a mine", "c both", "d mine"] as Array[String])
	assert_eq(MultiRules.filter_log(lines, sides, 2), ["b foe", "c both"] as Array[String])

func test_partner_uses_the_master_ai_from_veteran_on() -> void:
	assert_eq(MultiRules.partner_ai(1, GameState.Difficulty.STORY), 1)
	assert_eq(MultiRules.partner_ai(1, GameState.Difficulty.VETERAN), 3)
	assert_eq(MultiRules.partner_ai(1, GameState.Difficulty.RIFT_BORN), 3)

func test_wild_swarm_has_a_leader_and_falters_without_it() -> void:
	var lead: Spirling = _mk("Mossling", [], 20)
	var a: Spirling = _mk("Zippit", [], 12)
	var b: Spirling = _mk("Kelpup", [], 12)
	var m := _model([_mk("Kindlop", ["Cinder Nip"], 30), _mk("Puddlet", [], 30)] as Array[Spirling], [a, lead, b] as Array[Spirling], [2, 3], true)
	var ev: Array[BattleEvent] = m.start()
	assert_eq(MultiRules.swarm_leader(m), 1)
	assert_eq(lead.stage("atk"), 1)
	assert_eq(BattleFixtures.first_of(ev, T.SUPPORT).describe(), "%s leads the swarm!" % lead.display_name())
	lead.hp = 0
	var ev2: Array[BattleEvent] = _turn(m, _rests(m, Side.PLAYER), [BattleAction.make_rest(Side.FOE, 0), BattleAction.make_rest(Side.FOE, 2)])
	var falter: bool = false
	for e: BattleEvent in ev2:
		falter = falter or (e.type == T.SUPPORT and str(e.data.get("kind", "")) == "leader_down")
	assert_true(falter)
	assert_eq(a.stage("spd"), -1)
	var tamer := _model([_mk("Kindlop")] as Array[Spirling], [_mk("Mossling"), _mk("Zippit")] as Array[Spirling], [1, 2], false)
	tamer.start()
	assert_eq(MultiRules.swarm_leader(tamer), -1, "only wild swarms have a leader")

func test_allies_set_off_a_combo_on_the_same_foe() -> void:
	var m := _model([_mk("Kindlop"), _mk("Zephlet")] as Array[Spirling], [_mk("Mossling"), _mk("Puddlet")] as Array[Spirling], [2, 2])
	m.start()
	m.turn = 3
	assert_true(MultiRules.combo(m, Side.PLAYER, 0, Side.FOE, 0, Elements.E.EMBER).is_empty(), "the first hit sets it up")
	assert_true(MultiRules.combo(m, Side.PLAYER, 1, Side.FOE, 1, Elements.E.GALE).is_empty(), "another foe does not count")
	assert_eq(str(MultiRules.combo(m, Side.PLAYER, 1, Side.FOE, 0, Elements.E.GALE).get("id", "")), "firestorm")
	m.turn = 4
	assert_true(MultiRules.combo(m, Side.PLAYER, 1, Side.FOE, 0, Elements.E.GALE).is_empty(), "a new turn starts fresh")
	assert_true(MultiRules.combo(m, Side.PLAYER, 0, Side.FOE, 1, Elements.E.EMBER).is_empty())
	assert_true(MultiRules.combo(m, Side.PLAYER, 0, Side.FOE, 1, Elements.E.GALE).is_empty(), "one Spirling alone makes no combo")

func test_combo_shows_in_a_played_turn() -> void:
	var k: Spirling = _mk("Kindlop", ["Cinder Nip"], 40)
	var z: Spirling = _mk("Zephlet", ["Kite Cut"], 40)
	var big: Spirling = _mk("Shalebat", [], 60)
	var m := _model([k, z] as Array[Spirling], [big, _mk("Puddlet", [], 60)] as Array[Spirling], [2, 2])
	m.start()
	var ev: Array[BattleEvent] = _turn(m, [BattleAction.make_move(Side.PLAYER, 0, 0, 0), BattleAction.make_move(Side.PLAYER, 0, 1, 0)], _rests(m, Side.FOE))
	var hit_both: int = 0
	for e: BattleEvent in ev:
		if e.type == T.DAMAGE and int(e.data.get("slot", -1)) == 0 and int(e.data.get("side", -1)) == Side.FOE:
			hit_both += 1
	var c: BattleEvent = null
	for e: BattleEvent in ev:
		if e.type == T.SUPPORT and str(e.data.get("kind", "")) == "combo":
			c = e
	if hit_both >= 2:
		assert_not_null(c, "two hits of Ember and Gale on one foe make a combo")
		assert_string_contains(c.describe(), "Firestorm")
	else:
		pass_test("a miss left no combo to show")

func test_back_row_softens_physical_hits() -> void:
	var m := _model([_mk("Kindlop"), _mk("Puddlet"), _mk("Mossling")] as Array[Spirling], [_mk("Zippit"), _mk("Kelpup"), _mk("Shalebat")] as Array[Spirling], [3, 3])
	m.start()
	assert_false(MultiRules.in_back_row(m, Side.FOE, 1))
	assert_true(MultiRules.in_back_row(m, Side.FOE, 2))
	var phys := MoveData.new()
	phys.kind = MoveData.Kind.PHYSICAL
	var focus := MoveData.new()
	focus.kind = MoveData.Kind.FOCUS
	assert_eq(MultiRules.row_mult(m, Side.PLAYER, 0, Side.FOE, 0, phys), 1.0)
	assert_almost_eq(MultiRules.row_mult(m, Side.PLAYER, 0, Side.FOE, 2, phys), 0.9, 0.0001)
	assert_almost_eq(MultiRules.row_mult(m, Side.PLAYER, 2, Side.FOE, 2, phys), 0.81, 0.0001)
	assert_eq(MultiRules.row_mult(m, Side.PLAYER, 2, Side.FOE, 2, focus), 1.0, "Focus arts reach every row")
	var duo := _model([_mk("Kindlop"), _mk("Puddlet")] as Array[Spirling], [_mk("Zippit"), _mk("Kelpup")] as Array[Spirling], [2, 2])
	duo.start()
	assert_false(MultiRules.in_back_row(duo, Side.FOE, 1), "two slots are all front")
