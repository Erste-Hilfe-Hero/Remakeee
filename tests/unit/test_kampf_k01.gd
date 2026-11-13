extends GutTest
## KAMPF_PLAN_1000, areas "Zugablauf und Grundregeln" and "Energie und Overcharge": coin toss,
## reverb, ambush, boss turn limit, Story softening, High Tide Rest, Overcharge chain,
## Low Tide, Rest Candle, end report, rules book and the rules already in place.

const Side := BattleModel.Side
const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _mk(species: String, moves: Array[String], level: int = 15) -> Spirling:
	return BattleFixtures.make(species, level, moves)

func _has(ev: Array[BattleEvent], t: T) -> bool:
	return BattleFixtures.types_of(ev).has(t)

func _first(ev: Array[BattleEvent], t: T) -> BattleEvent:
	for e: BattleEvent in ev:
		if e.type == t:
			return e
	return null

## Two equal Spirlings with the same art: same class, priority and Pace every turn.
func test_speed_tie_is_announced() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var b := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var m := BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false)
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0))
	var tie: BattleEvent = _first(ev, T.SPEED_TIE)
	assert_not_null(tie)
	var first: BattleEvent = _first(ev, T.MOVE_USED)
	assert_eq(int(tie.data.side), int(first.data.side), "the toss names the one that moved first")
	assert_string_contains(tie.describe(), "Coin toss")

func test_no_tie_with_different_pace_or_in_the_dark() -> void:
	var m := BattleFixtures.model([_mk("Zippit", ["Cinder Nip"] as Array[String])] as Array[Spirling],
		[_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], false)
	assert_false(_has(m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0)), T.SPEED_TIE))
	var d := BattleModel.new([_mk("Kindlop", ["Cinder Nip"] as Array[String])] as Array[Spirling],
		[_mk("Kindlop", ["Cinder Nip"] as Array[String])] as Array[Spirling], false, 7, 0)
	d.foe_rule = "night_dark"
	d.start()
	assert_false(_has(d.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0)), T.SPEED_TIE))

func test_boss_extra_action_is_reverb() -> void:
	var mine: Array[Spirling] = []
	for n: String in ["Kindlop", "Zippit", "Wickit", "Zephlet"]:
		mine.append(_mk(n, ["Cinder Nip"] as Array[String], 20))
	var m := BattleModel.new(mine, [_mk("Mossling", ["Cinder Nip"] as Array[String], 20)] as Array[Spirling], false, 5, 1)
	m.front_size = [4, 1]
	m.foe_boss = "ashen_heart"
	m.start()
	var acts: Array[BattleAction] = []
	for slot: int in 4:
		acts.append(BattleAction.make_rest(Side.PLAYER, slot))
	var ev: Array[BattleEvent] = m.submit_actions(acts)
	assert_true(_has(ev, T.BONUS_ACTION))
	assert_string_contains(_first(ev, T.BONUS_ACTION).describe(), "Reverb")

func test_ambush_lets_the_wild_foe_act_first() -> void:
	# Mossling is far slower than Zippit; only the ambush puts it first.
	var m := BattleModel.new([_mk("Zippit", ["Cinder Nip"] as Array[String])] as Array[Spirling],
		[_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], true, 3, 0)
	m.ambush = true
	assert_true(_has(m.start(), T.AMBUSH))
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0))
	assert_eq(int(_first(ev, T.MOVE_USED).data.side), Side.FOE)
	ev = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0))
	assert_eq(int(_first(ev, T.MOVE_USED).data.side), Side.PLAYER, "only the first turn")

func test_boss_round_limit_closes_the_rift() -> void:
	var m := BattleModel.new([_mk("Kindlop", ["Cinder Nip"] as Array[String])] as Array[Spirling],
		[_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], false, 3, 0)
	m.foe_boss = "ashen_heart"
	m.round_limit = 2
	m.start()
	m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	assert_true(_has(ev, T.ROUND_LIMIT))
	assert_eq(m.outcome, BattleModel.Outcome.FLED)
	assert_eq(BattleModel.BOSS_ROUND_LIMIT, 30)

func test_story_rest_mends_vigor() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var m := BattleFixtures.model([a] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling])
	m.rest_heal_share = BattleModel.STORY_REST_HEAL
	a.hp = a.max_hp() / 2
	var before: int = a.hp
	m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	assert_eq(a.hp, before + maxi(1, roundi(a.max_hp() * BattleModel.STORY_REST_HEAL)))

func test_story_halves_foe_keen_hits() -> void:
	var keen: Array[int] = []
	for mult: float in [1.0, BattleModel.STORY_FOE_CRIT]:
		var count: int = 0
		for seed_value: int in 300:
			var m := BattleModel.new([_mk("Mossling", ["Cinder Nip"] as Array[String], 40)] as Array[Spirling],
				[_mk("Kindlop", ["Cinder Nip"] as Array[String], 5)] as Array[Spirling], false, seed_value, 0)
			m.foe_crit_mult = mult
			m.start()
			var hit: BattleEvent = _first(m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_move(Side.FOE, 0)), T.DAMAGE)
			if hit != null and bool(hit.data.get("crit", false)):
				count += 1
		keen.append(count)
	assert_gt(keen[0], keen[1])

func test_story_values_survive_a_replay() -> void:
	var m := BattleModel.new([_mk("Kindlop", ["Cinder Nip"] as Array[String])] as Array[Spirling],
		[_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling], true, 9, 0)
	m.foe_crit_mult = BattleModel.STORY_FOE_CRIT
	m.rest_heal_share = BattleModel.STORY_REST_HEAL
	m.ambush = true
	var snap: Dictionary = BattleReplay.snapshot(m, "", "")
	var r: BattleModel = BattleReplay.build_model(snap)
	assert_eq(r.foe_crit_mult, BattleModel.STORY_FOE_CRIT)
	assert_eq(r.rest_heal_share, BattleModel.STORY_REST_HEAL)
	assert_true(r.ambush)
	var plain: Dictionary = BattleReplay.snapshot(BattleModel.new([_mk("Kindlop", [] as Array[String])] as Array[Spirling],
		[_mk("Mossling", [] as Array[String])] as Array[Spirling], true, 9, 0), "", "")
	assert_false(plain.has("foe_crit") or plain.has("rest_heal") or plain.has("ambush"), "old replays stay the same")

func test_high_tide_rest_gives_more_energy() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var b := _mk("Mossling", ["Cinder Nip"] as Array[String])
	var m := BattleModel.new([a] as Array[Spirling], [b] as Array[Spirling], true, 7, 0)
	m.field = "high_tide"
	m.start()
	assert_eq(m.rest_gain(), BattleModel.REST_ENERGY + 1)
	a.energy = 2
	m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	assert_eq(a.energy, 2 + BattleModel.REST_ENERGY + 1 + BattleModel.ENERGY_PER_TURN)

func test_overcharge_chain() -> void:
	var z := _mk("Zippit", ["Overcharge"] as Array[String], 20)
	var b := _mk("Mossling", ["Cinder Nip"] as Array[String], 40)
	var m := BattleFixtures.model([z] as Array[Spirling], [b] as Array[Spirling], true, 11)
	assert_false(_has(m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE)), T.OVERCHARGE_CHAIN))
	z.energy = 10
	assert_true(_has(m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE)), T.OVERCHARGE_CHAIN))
	m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	z.energy = 10
	assert_false(_has(m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE)), T.OVERCHARGE_CHAIN), "a rest breaks it")
	assert_almost_eq(BattleRules.overcharge_mult(5, true), 1.0 + 5 * BattleRules.OVERCHARGE_PER_ENERGY + BattleRules.OVERCHARGE_CHAIN_BONUS, 0.001)
	assert_almost_eq(BattleRules.overcharge_mult(9), BattleRules.overcharge_mult(BattleRules.OVERCHARGE_MAX_EXTRA), 0.001, "capped at +5, bosses too")

func test_low_tide_cuts_player_start_energy() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var b := _mk("Mossling", ["Cinder Nip"] as Array[String])
	var m := BattleModel.new([a] as Array[Spirling], [b] as Array[Spirling], false, 7, 0)
	m.foe_rule = "low_tide"
	m.start()
	assert_eq(a.energy, Spirling.START_ENERGY - 1)
	assert_eq(b.energy, Spirling.START_ENERGY)

func test_rest_candle_reaches_the_bench() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var bench := _mk("Zippit", ["Cinder Nip"] as Array[String])
	var m := BattleFixtures.model([a, bench] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling])
	m.inventory = {"rest_candle": 1, "spark_drop": 1}
	bench.energy = 4
	var act := BattleAction.make_item(Side.PLAYER, "rest_candle", 1)
	assert_true(m.is_legal(act))
	m.submit_turn(act, BattleAction.make_rest(Side.FOE))
	assert_eq(bench.energy, 7)
	assert_eq(int(m.inventory.get("rest_candle", 0)), 0)

func test_summary_counts_damage_downs_energy_and_seed() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String], 40)
	var b := _mk("Mossling", ["Cinder Nip"] as Array[String], 3)
	var m := BattleModel.new([a] as Array[Spirling], [b] as Array[Spirling], false, 4242, 0)
	var sum := BattleSummary.new(m)
	m.start()
	var guard: int = 0
	while not m.is_finished() and guard < 30:
		guard += 1
		m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE))
	assert_eq(m.outcome, BattleModel.Outcome.WIN)
	assert_eq(sum.mvp(), a)
	assert_eq(int(sum.downs.get(a, 0)), 1)
	assert_gt(int(sum.dealt.get(a, 0)), 0)
	assert_gt(sum.energy_spent[Side.PLAYER], 0)
	assert_eq(sum.energy_spent[Side.FOE], 0, "the foe only rested")
	var text: String = "\n".join(sum.lines())
	assert_string_contains(text, a.display_name())
	assert_string_contains(text, "%08x" % 4242)

func test_rules_book_pages_follow_the_constants() -> void:
	assert_eq(RulesBook.titles().size(), RulesBook.PAGES.size())
	for i: int in RulesBook.PAGES.size():
		assert_false(RulesBook.page(i).is_empty(), RulesBook.PAGES[i])
	assert_string_contains("\n".join(RulesBook.energy()), str(BattleModel.REST_ENERGY))
	assert_string_contains("\n".join(RulesBook.end_of_turn()), str(BattleRules.WEARY_TURN))
	assert_string_contains("\n".join(RulesBook.fleeing()), str(roundi(BattleModel.FLEE_PER_ATTEMPT * 100.0)))
	assert_string_contains("\n".join(RulesBook.warden_rules()), "Ember Pulse")
	assert_eq(RulesBook.fields().size(), BattleRules.FIELDS.size() + 1)

func test_command_line_shows_never_and_overcharge() -> void:
	var mv: MoveData = Database.move("Cinder Nip")
	assert_eq(CommandMenu.move_line(mv, 10, -1.0, false, -1, 9, 0, 6), "never")
	var oc: MoveData = Database.move("Overcharge")
	assert_eq(CommandMenu.move_line(oc, 10, -1.0, false, -1, oc.energy_cost, 0, 10, 1.6), "%dE x1.6" % oc.energy_cost)

# --- Rules that were already there, now pinned (items 17, 25, 26, 32, 33) -------------------

func test_item_takes_the_whole_turn() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var m := BattleFixtures.model([a] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling])
	m.inventory = {"spark_drop": 1}
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_item(Side.PLAYER, "spark_drop", 0), BattleAction.make_rest(Side.FOE))
	for e: BattleEvent in ev:
		assert_false(e.type == T.MOVE_USED and int(e.data.side) == Side.PLAYER)

func test_missing_player_order_rests() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var m := BattleFixtures.model([a] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling])
	var ev: Array[BattleEvent] = m.submit_actions([BattleAction.make_rest(Side.FOE)] as Array[BattleAction])
	var rest: BattleEvent = null
	for e: BattleEvent in ev:
		if e.type == T.REST and int(e.data.side) == Side.PLAYER:
			rest = e
		assert_false(e.type == T.MOVE_USED and int(e.data.side) == Side.PLAYER)
	assert_not_null(rest)

func test_area_arts_only_reach_foes() -> void:
	var sweep: MoveData = null
	for mv: MoveData in Database.moves.values():
		if mv.is_area() and mv.is_damaging():
			sweep = mv
			break
	assert_not_null(sweep)
	var mine: Array[Spirling] = [_mk("Kindlop", [sweep.move_name] as Array[String]), _mk("Zippit", ["Cinder Nip"] as Array[String])]
	var theirs: Array[Spirling] = [_mk("Mossling", ["Cinder Nip"] as Array[String]), _mk("Zephlet", ["Cinder Nip"] as Array[String])]
	var m := BattleModel.new(mine, theirs, false, 7, 0)
	m.front_size = [2, 2]
	m.start()
	var ev: Array[BattleEvent] = m.submit_actions([BattleAction.make_move(Side.PLAYER, 0, 0), BattleAction.make_rest(Side.PLAYER, 1),
		BattleAction.make_rest(Side.FOE, 0), BattleAction.make_rest(Side.FOE, 1)] as Array[BattleAction])
	for e: BattleEvent in ev:
		if e.type == T.DAMAGE and not e.data.has("weary"):
			assert_eq(int(e.data.side), Side.FOE)

func test_swap_is_free_and_energy_stays_with_the_spirling() -> void:
	var a := _mk("Kindlop", ["Cinder Nip"] as Array[String])
	var bench := _mk("Wickit", ["Cinder Nip"] as Array[String])
	var m := BattleFixtures.model([a, bench] as Array[Spirling], [_mk("Mossling", ["Cinder Nip"] as Array[String])] as Array[Spirling])
	a.energy = 3
	bench.energy = 7
	m.submit_turn(BattleAction.make_swap(Side.PLAYER, 1), BattleAction.make_rest(Side.FOE))
	assert_eq(bench.energy, 7 + BattleModel.ENERGY_PER_TURN, "no swap cost, its own Energy plus the turn's")
	assert_eq(a.energy, 3, "the bench keeps what it had")
