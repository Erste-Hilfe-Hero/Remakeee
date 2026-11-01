extends GutTest
## Battle model: ordering, Energy, statuses, faint/swap, victory, bonding, fleeing, determinism.

const Side := BattleModel.Side
const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _p(names: Array[String], level: int = 15) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for n: String in names:
		out.append(BattleFixtures.make(n, level))
	return out

func _event_log(events: Array[BattleEvent]) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: BattleEvent in events:
		out.append("%s %s" % [e.type_name(), JSON.stringify(e.data)])
	return out

func _play_auto(seed_value: int) -> PackedStringArray:
	var m := BattleModel.new(_p(["Kindlop", "Zippit"]), _p(["Mossling", "Zephlet"]), false, seed_value, 1)
	var player_ai := BattleAI.new(1)
	var log: PackedStringArray = _event_log(m.start())
	var guard: int = 0
	while not m.is_finished() and guard < 200:
		guard += 1
		if m.needs_player_switch():
			log.append_array(_event_log(m.submit_switch(m.swap_candidates(Side.PLAYER)[0])))
		else:
			log.append_array(_event_log(m.submit_turn(player_ai.choose(m, Side.PLAYER))))
	return log

func test_same_seed_same_battle() -> void:
	var a: PackedStringArray = _play_auto(4242)
	var b: PackedStringArray = _play_auto(4242)
	assert_gt(a.size(), 5)
	assert_eq(a, b, "a fixed seed must reproduce the battle exactly")

func test_battle_reaches_an_outcome() -> void:
	var log: PackedStringArray = _play_auto(1)
	assert_string_contains(log[log.size() - 1], "BATTLE_END")

func test_swap_acts_before_moves() -> void:
	var m: BattleModel = BattleFixtures.model(_p(["Kindlop", "Puddlet"]), _p(["Zippit"]))
	var events: Array[BattleEvent] = m.submit_turn(BattleAction.make_swap(Side.PLAYER, 1), BattleAction.make_move(Side.FOE, 0))
	var types: Array[int] = BattleFixtures.types_of(events)
	assert_lt(types.find(T.SWAP_IN), types.find(T.MOVE_USED))

func test_priority_beats_speed() -> void:
	# Zephlet's Breeze Slice has priority 1; the foe Zippit is faster but uses a priority-0 move.
	var mine: Array[Spirling] = [BattleFixtures.make("Zephlet", 15, ["Breeze Slice"])]
	var theirs: Array[Spirling] = [BattleFixtures.make("Zippit", 40, ["Crackle Bite"])]
	var m: BattleModel = BattleFixtures.model(mine, theirs)
	assert_gt(theirs[0].effective_spd(), mine[0].effective_spd())
	var first: BattleEvent = BattleFixtures.first_of(m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0)), T.MOVE_USED)
	assert_eq(int(first.data.side), Side.PLAYER)

func test_faster_moves_first_at_equal_priority() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Mossling", 15, ["Lichen Lash"])]
	var theirs: Array[Spirling] = [BattleFixtures.make("Zippit", 15, ["Crackle Bite"])]
	var m: BattleModel = BattleFixtures.model(mine, theirs)
	var first: BattleEvent = BattleFixtures.first_of(m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0)), T.MOVE_USED)
	assert_eq(int(first.data.side), Side.FOE)

func test_energy_starts_at_10_costs_and_regenerates() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 30, ["Cinder Breath"])]
	var theirs: Array[Spirling] = [BattleFixtures.make("Calderox", 50, ["Headlong Charge"])]
	var m: BattleModel = BattleFixtures.model(mine, theirs)
	assert_eq(mine[0].energy, 10)
	m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	assert_eq(mine[0].energy, 10 - 4 + 1, "Cinder Breath costs 4, +1 at end of turn")

func test_unaffordable_move_is_illegal_and_rest_is_always_legal() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 30, ["Cinder Breath"])]
	var m: BattleModel = BattleFixtures.model(mine, _p(["Calderox"], 50))
	mine[0].energy = 3
	assert_false(m.is_legal(BattleAction.make_move(Side.PLAYER, 0)))
	assert_true(m.is_legal(BattleAction.make_rest(Side.PLAYER)))
	var kinds: Array[int] = []
	for a: BattleAction in m.legal_actions(Side.PLAYER):
		kinds.append(a.kind)
	assert_false(BattleAction.Kind.MOVE in kinds)
	assert_true(BattleAction.Kind.REST in kinds)

func test_rest_restores_energy() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 30)]
	var m: BattleModel = BattleFixtures.model(mine, _p(["Calderox"], 50))
	mine[0].energy = 2
	m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	assert_eq(mine[0].energy, 2 + BattleModel.REST_ENERGY + BattleModel.ENERGY_PER_TURN)

func test_scorch_ticks_one_sixteenth() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Calderox", 50)]
	var m: BattleModel = BattleFixtures.model(mine, _p(["Kindlop"], 5))
	m.apply_status(Side.PLAYER, "scorch")
	var before: int = mine[0].hp
	m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	assert_eq(before - mine[0].hp, mine[0].max_hp() / 16)

func test_root_ticks_and_blocks_swap() -> void:
	var mine: Array[Spirling] = _p(["Calderox", "Kindlop"], 50)
	var m: BattleModel = BattleFixtures.model(mine, _p(["Kindlop"], 5))
	m.apply_status(Side.PLAYER, "root")
	assert_false(m.is_legal(BattleAction.make_swap(Side.PLAYER, 1)))
	var before: int = mine[0].hp
	m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	assert_eq(before - mine[0].hp, mine[0].max_hp() / 16)

func test_soak_halves_speed_and_wears_off_after_3_turns() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Zippit", 30)]
	var m: BattleModel = BattleFixtures.model(mine, _p(["Calderox"], 50))
	var spd: int = mine[0].effective_spd()
	m.apply_status(Side.PLAYER, "soak")
	assert_eq(mine[0].effective_spd(), int(spd * 0.5))
	for i: int in 3:
		m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	assert_eq(mine[0].status, "")

func test_daze_lowers_accuracy_for_3_turns() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Zippit", 30)]
	var m: BattleModel = BattleFixtures.model(mine, _p(["Calderox"], 50))
	m.apply_status(Side.PLAYER, "daze")
	assert_eq(StatusRules.acc_mult(mine[0].status), 0.7)
	assert_eq(mine[0].status_turns, 3)

func test_drowse_skips_turns_then_wakes() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 30, ["Cinder Nip"])]
	var m: BattleModel = BattleFixtures.model(mine, _p(["Calderox"], 50))
	m.apply_status(Side.PLAYER, "drowse")
	var turns: int = mine[0].status_turns
	assert_between(turns, 1, 3)
	for i: int in turns:
		var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
		assert_not_null(BattleFixtures.first_of(ev, T.STATUS_PREVENTED), "asleep on turn %d" % i)
	var woke: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	assert_not_null(BattleFixtures.first_of(woke, T.MOVE_USED))

func test_jolt_skips_about_a_quarter_of_turns() -> void:
	var skipped: int = 0
	var n: int = 400
	for i: int in n:
		var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 30, ["Headlong Charge"])]
		var m: BattleModel = BattleFixtures.model(mine, _p(["Calderox"], 60), true, i)
		m.apply_status(Side.PLAYER, "jolt")
		if BattleFixtures.first_of(m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE)), T.STATUS_PREVENTED) != null:
			skipped += 1
	assert_between(float(skipped) / n, 0.18, 0.32)

func test_only_one_status_at_a_time() -> void:
	var m: BattleModel = BattleFixtures.model(_p(["Kindlop"]), _p(["Mossling"]))
	assert_true(m.apply_status(Side.FOE, "scorch"))
	assert_false(m.apply_status(Side.FOE, "soak"))

func test_faint_forces_player_switch_then_continues() -> void:
	var mine: Array[Spirling] = _p(["Mossling", "Puddlet"], 5)
	var theirs: Array[Spirling] = [BattleFixtures.make("Calderox", 60, ["Cinder Nip"])]
	var m: BattleModel = BattleFixtures.model(mine, theirs, false)
	m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_move(Side.FOE, 0))
	assert_true(mine[0].is_fainted())
	assert_true(m.needs_player_switch())
	var ev: Array[BattleEvent] = m.submit_switch(1)
	assert_not_null(BattleFixtures.first_of(ev, T.SWAP_IN))
	assert_eq(m.phase, BattleModel.Phase.CHOOSE_ACTIONS)

func test_victory_awards_xp_and_ends() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Calderox", 60, ["Headlong Charge"])]
	var theirs: Array[Spirling] = [BattleFixtures.make("Zippit", 3)]
	var m: BattleModel = BattleFixtures.model(mine, theirs)
	var xp_before: int = mine[0].xp
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	assert_eq(m.outcome, BattleModel.Outcome.WIN)
	assert_true(m.is_finished())
	assert_gt(mine[0].xp, xp_before)
	assert_eq(ev[ev.size() - 1].type, T.BATTLE_END)

func test_trainer_switches_in_next_spirling() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Calderox", 60, ["Headlong Charge"])]
	var theirs: Array[Spirling] = _p(["Zippit", "Zephlet"], 3)
	var m: BattleModel = BattleFixtures.model(mine, theirs, false)
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	assert_not_null(BattleFixtures.first_of(ev, T.SWAP_IN))
	assert_eq(m.active[Side.FOE], 1)
	assert_false(m.is_finished())

func test_level_cap_stops_xp() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Calderox", 12, ["Headlong Charge"])]
	var m := BattleModel.new(mine, [BattleFixtures.make("Zippit", 3)] as Array[Spirling], true, 3)
	m.level_cap = 12
	m.start()
	var xp_before: int = mine[0].xp
	m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	assert_eq(mine[0].level, 12)
	assert_eq(mine[0].xp, xp_before)

func test_loss_when_party_wiped() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Mossling", 3)]
	var theirs: Array[Spirling] = [BattleFixtures.make("Calderox", 60, ["Cinder Nip"])]
	var m: BattleModel = BattleFixtures.model(mine, theirs)
	m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_move(Side.FOE, 0))
	assert_eq(m.outcome, BattleModel.Outcome.LOSS)

func test_bond_success_ends_battle() -> void:
	var theirs: Array[Spirling] = [BattleFixtures.make("Zephlet", 5)]
	theirs[0].hp = 1
	var m: BattleModel = BattleFixtures.model(_p(["Kindlop"]), theirs, true, 11)
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_bond(Side.PLAYER, 1.0, ""), BattleAction.make_rest(Side.FOE))
	var res: BattleEvent = BattleFixtures.first_of(ev, T.BOND_RESULT)
	assert_not_null(res)
	if res.data.success:
		assert_eq(m.outcome, BattleModel.Outcome.BONDED)
		assert_eq(m.bonded, theirs[0])
		assert_true(m.is_finished())

func test_failed_bond_gives_free_action() -> void:
	var theirs: Array[Spirling] = [BattleFixtures.make("Zephlet", 5, ["Headlong Charge"])]
	var m: BattleModel = BattleFixtures.model(_p(["Kindlop"], 30), theirs, true, 5)
	# Timing score 0 => chance 0 => guaranteed failure.
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_bond(Side.PLAYER, 0.0), BattleAction.make_rest(Side.FOE))
	assert_false(BattleFixtures.first_of(ev, T.BOND_RESULT).data.success)
	assert_not_null(BattleFixtures.first_of(ev, T.FREE_ACTION))

func test_bond_and_run_not_allowed_vs_tamers() -> void:
	var m: BattleModel = BattleFixtures.model(_p(["Kindlop"]), _p(["Mossling"]), false)
	assert_false(m.is_legal(BattleAction.make_bond(Side.PLAYER, 1.0)))
	assert_false(m.is_legal(BattleAction.make_run(Side.PLAYER)))

func test_bond_chance_formula() -> void:
	var s: Spirling = BattleFixtures.make("Zippit", 10)
	s.hp = s.max_hp() / 2
	var expected: float = s.data.bond_rate * (1.0 - s.hp_fraction()) * 0.8
	assert_almost_eq(BondCalc.chance(s, 0.8), expected, 0.0001)
	s.status = "jolt"
	assert_almost_eq(BondCalc.chance(s, 0.8), expected * 1.5, 0.0001)
	assert_almost_eq(BondCalc.chance(s, 0.8, 0.1), expected * 1.5 + 0.1, 0.0001)
	s.hp = 1
	assert_lte(BondCalc.chance(s, 1.0, 5.0), 0.95)
	s.hp = s.max_hp()
	s.status = ""
	assert_almost_eq(BondCalc.chance(s, 1.0), s.data.bond_rate * 0.1, 0.0001, "HP factor floors at 0.1")

func test_items_heal_and_are_consumed_and_banned_in_rift_born() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 20)]
	var m: BattleModel = BattleFixtures.model(mine, _p(["Mossling"], 3))
	m.inventory = {"tonic": 1}
	mine[0].hp = 5
	m.submit_turn(BattleAction.make_item(Side.PLAYER, "tonic", 0), BattleAction.make_rest(Side.FOE))
	assert_eq(mine[0].hp, 25)
	assert_eq(int(m.inventory.tonic), 0)
	m.inventory = {"tonic": 3}
	m.items_allowed = false
	assert_false(m.is_legal(BattleAction.make_item(Side.PLAYER, "tonic", 0)))

func test_flee_eventually_succeeds_in_wild() -> void:
	var m: BattleModel = BattleFixtures.model(_p(["Mossling"], 5), _p(["Zippit"], 5))
	var guard: int = 0
	while not m.is_finished() and guard < 10:
		guard += 1
		m.submit_turn(BattleAction.make_run(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	assert_eq(m.outcome, BattleModel.Outcome.FLED)

func test_drain_heals_user() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Mossling", 30, ["Sap Draw"])]
	var m: BattleModel = BattleFixtures.model(mine, _p(["Puddlet"], 30), true, 2)
	mine[0].hp = 10
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	assert_not_null(BattleFixtures.first_of(ev, T.HEAL))
	assert_gt(mine[0].hp, 10)
