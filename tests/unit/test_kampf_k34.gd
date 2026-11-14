extends GutTest
## docs/KAMPF_PLAN_1000.md area "Gegner-KI": items 445, 447, 453, 466, 470, 472, 476, 477.

const Side := BattleModel.Side
const E := Elements.E

func before_all() -> void:
	Database.load_all()

## A Testling of [param elements] with base [param base] in every stat and the given arts.
func _ling(elements: Array[int], arts: Array[MoveData], base: int = 80, level: int = 30) -> Spirling:
	var s: Spirling = BattleFixtures.from_species(BattleFixtures.balanced_species(base, elements), level)
	for mv: MoveData in arts:
		s.moves.append(mv)
	return s

func _art(element: int, power: int, cost: int = 2) -> MoveData:
	var mv: MoveData = BattleFixtures.move(element, power)
	mv.energy_cost = cost
	mv.move_name = "Test %d %d %d" % [element, power, cost]
	return mv

func _model(mine: Array[Spirling], theirs: Array[Spirling], ai: int, seed_value: int = 7) -> BattleModel:
	var m := BattleModel.new(mine, theirs, false, seed_value, ai)
	m.start()
	return m

# --- 445: Energy two turns ahead ----------------------------------------------------------

func _saver(ai: int) -> BattleModel:
	var me: Spirling = _ling([E.GALE] as Array[int], [_art(E.STONE, 40)] as Array[MoveData], 120)
	var foe: Spirling = _ling([E.GALE] as Array[int], [_art(E.STONE, 8, 2), _art(E.STONE, 160, 9)] as Array[MoveData])
	var m: BattleModel = _model([me] as Array[Spirling], [foe] as Array[Spirling], ai)
	foe.energy = 3
	return m

func test_master_plans_energy_two_turns_ahead() -> void:
	var m: BattleModel = _saver(3)
	var per_rest: int = m.rest_gain() + BattleAI.energy_gain(m)
	assert_true(3 + per_rest < 9 and 3 + 2 * per_rest >= 9, "the big art is two rests away")
	assert_eq(m.ai.plan_turns(), int(BattleAI.rules_data().plan_turns))
	assert_eq(m.ai.plan_turns(), 2)
	assert_eq(m.ai.choose(m, Side.FOE).kind, BattleAction.Kind.REST, "the Master saves up for two turns")

func test_one_turn_planners_take_the_small_hit() -> void:
	var m: BattleModel = _saver(2)
	assert_eq(m.ai.plan_turns(), 0)
	assert_eq(m.ai.choose(m, Side.FOE).kind, BattleAction.Kind.MOVE, "tier 2 does not plan")
	m.ai.set_profile("tactician")
	assert_eq(m.ai.plan_turns(), 1)
	assert_eq(m.ai.choose(m, Side.FOE).kind, BattleAction.Kind.MOVE, "the Tactician looks one turn ahead only")
	m.active_spirling(Side.FOE).energy = 6
	assert_eq(m.ai.choose(m, Side.FOE).kind, BattleAction.Kind.REST, "one rest away: the Tactician saves up")

# --- 447 + 453: guessing the player's swap ------------------------------------------------

func _guess_model(ai: int) -> BattleModel:
	var front: Spirling = _ling([E.BLOOM] as Array[int], [_art(E.GALE, 30)] as Array[MoveData], 200, 40)
	var bench: Spirling = _ling([E.TIDE] as Array[int], [_art(E.GALE, 30)] as Array[MoveData], 200, 40)
	var foe: Spirling = _ling([E.GALE] as Array[int], [_art(E.EMBER, 60), _art(E.VOLT, 60)] as Array[MoveData], 60, 30)
	return _model([front, bench] as Array[Spirling], [foe] as Array[Spirling], ai)

func test_master_guesses_the_swap_to_a_shown_spirling() -> void:
	assert_eq(Elements.multiplier(E.EMBER, [E.BLOOM]), 2.0)
	assert_lt(Elements.multiplier(E.EMBER, [E.TIDE]), 1.0)
	assert_eq(Elements.multiplier(E.VOLT, [E.TIDE]), 2.0)
	var m: BattleModel = _guess_model(3)
	var bench: Spirling = m.parties[Side.PLAYER][1]
	assert_null(m.ai.predicted_swap(m, Side.FOE), "a Spirling never shown is no guess (item 453)")
	assert_eq(m.ai.choose(m, Side.FOE).move_index, 0, "the Ember art on the Bloom front")
	m.participants.append(bench)
	assert_true(BattleAI.seen(m, Side.PLAYER, bench))
	assert_eq(m.ai.predicted_swap(m, Side.FOE), bench)
	assert_eq(m.ai.choose(m, Side.FOE).move_index, 1, "the Volt art also hurts the Tide it expects")

func test_only_the_master_guesses() -> void:
	var m: BattleModel = _guess_model(2)
	m.participants.append(m.parties[Side.PLAYER][1])
	assert_null(m.ai.predicted_swap(m, Side.FOE))
	assert_eq(m.ai.choose(m, Side.FOE).move_index, 0)

# --- 453: nothing hidden --------------------------------------------------------------------

func _foe_act(events: Array[BattleEvent]) -> String:
	for e: BattleEvent in events:
		if int(e.data.get("side", -1)) != Side.FOE:
			continue
		if e.type in [BattleEvent.Type.MOVE_USED, BattleEvent.Type.REST, BattleEvent.Type.SWAP_OUT, BattleEvent.Type.ITEM_USED]:
			return "%s %s" % [e.type_name(), str(e.data.get("move", ""))]
	return ""

func test_foe_choice_never_depends_on_the_players_order() -> void:
	for ai: int in [1, 2, 3]:
		for seed_value: int in [3, 11, 29]:
			var acts: Array[String] = []
			for order: int in 2:
				var me: Spirling = BattleFixtures.make("Calderox", 30)
				var foe: Spirling = BattleFixtures.make("Zippit", 30)
				var m: BattleModel = _model([me] as Array[Spirling], [foe] as Array[Spirling], ai, seed_value)
				var a: BattleAction = BattleAction.make_rest(Side.PLAYER) if order == 0 else BattleAction.make_move(Side.PLAYER, 0)
				acts.append(_foe_act(m.submit_turn(a)))
			assert_ne(acts[0], "", "the foe acted")
			assert_eq(acts[0], acts[1], "tier %d seed %d" % [ai, seed_value])

func test_hidden_order_hides_pace_from_the_ai_too() -> void:
	var me: Spirling = _ling([E.GALE] as Array[int], [_art(E.STONE, 40)] as Array[MoveData], 80)
	var foe: Spirling = _ling([E.GALE] as Array[int], [_art(E.STONE, 40)] as Array[MoveData], 120)
	var m: BattleModel = _model([me] as Array[Spirling], [foe] as Array[Spirling], 2)
	var mv: MoveData = foe.moves[0]
	assert_true(BattleAI.acts_first(m, foe, me, mv), "the faster foe knows it goes first")
	m.foe_rule = "night_dark"
	assert_eq(BattleInfo.order_hint(m, me, foe, me.moves[0]), "hidden", "the player sees no order")
	assert_false(BattleAI.acts_first(m, foe, me, mv), "and the foe counts on none either")

# --- 466: time per decision -----------------------------------------------------------------

func test_ai_decision_fits_the_phone_budget() -> void:
	var budget_ms: float = float(BattleAI.rules_data().budget_ms) / float(BattleAI.rules_data().desktop_factor)
	var cases: Array[BattleModel] = []
	var single: BattleModel = _model([BattleFixtures.make("Calderox", 40), BattleFixtures.make("Puddlet", 40)] as Array[Spirling],
		[BattleFixtures.make("Smoldrake", 40), BattleFixtures.make("Zippit", 40)] as Array[Spirling], 3)
	single.participants.append(single.parties[Side.PLAYER][1])
	cases.append(single)
	var duo := BattleModel.new([BattleFixtures.make("Calderox", 40), BattleFixtures.make("Puddlet", 40), BattleFixtures.make("Mossling", 40)] as Array[Spirling],
		[BattleFixtures.make("Smoldrake", 40), BattleFixtures.make("Zippit", 40), BattleFixtures.make("Kindlop", 40)] as Array[Spirling], false, 7, 3)
	duo.front_size = [2, 2]
	duo.start()
	cases.append(duo)
	for m: BattleModel in cases:
		for slot: int in m.slot_count(Side.FOE):
			m.ai.choose(m, Side.FOE, slot)
		# The fastest of several batches, so a busy test machine does not count as a slow AI.
		var ms: float = INF
		for batch: int in 8:
			var runs: int = 0
			var t0: int = Time.get_ticks_usec()
			for i: int in 5:
				for slot: int in m.slot_count(Side.FOE):
					m.ai.choose(m, Side.FOE, slot)
					runs += 1
			ms = minf(ms, float(Time.get_ticks_usec() - t0) / 1000.0 / float(runs))
		gut.p("AI decision: %.3f ms (%d foes in front, budget %.2f ms here, %.1f ms on a phone)" % [ms, m.slot_count(Side.FOE), budget_ms, float(BattleAI.rules_data().budget_ms)])
		assert_lt(ms, budget_ms, "one decision takes %.3f ms" % ms)

# --- 470: the field's weakness ------------------------------------------------------------

func _field_model(ai: int, field_turns: int) -> BattleModel:
	var me: Spirling = _ling([E.GALE] as Array[int], [_art(E.GALE, 30)] as Array[MoveData])
	var foe: Spirling = _ling([E.STONE] as Array[int], [_art(E.EMBER, 50)] as Array[MoveData])
	var ally: Spirling = _ling([E.STONE] as Array[int], [_art(E.TIDE, 50)] as Array[MoveData])
	var m: BattleModel = _model([me] as Array[Spirling], [foe, ally] as Array[Spirling], ai)
	m.set_field("high_tide", field_turns)
	return m

func test_ai_swaps_out_of_a_field_that_weakens_all_its_arts() -> void:
	assert_eq(str(BattleRules.FIELDS.high_tide.weaken), "EMBER")
	assert_lt(Elements.multiplier(E.GALE, [E.STONE]), BattleAI.BAD_MATCHUP_EFF, "no bad matchup in play")
	var m: BattleModel = _field_model(3, 0)
	assert_true(m.ai.field_weak(m, m.active_spirling(Side.FOE)))
	var a: BattleAction = m.ai.choose(m, Side.FOE)
	assert_eq(a.kind, BattleAction.Kind.SWAP, "the place's own High Tide drowns its Ember")
	assert_eq(a.swap_index, 1)

func test_field_swap_needs_a_lasting_field_and_the_master() -> void:
	var m: BattleModel = _field_model(3, 1)
	assert_false(m.ai.field_weak(m, m.active_spirling(Side.FOE)), "one turn left: it waits it out")
	assert_eq(m.ai.choose(m, Side.FOE).kind, BattleAction.Kind.MOVE)
	m = _field_model(3, 3)
	assert_eq(m.ai.choose(m, Side.FOE).kind, BattleAction.Kind.SWAP)
	m.ai.set_profile("hothead")
	assert_eq(m.ai.choose(m, Side.FOE).kind, BattleAction.Kind.MOVE, "a hothead never swaps")
	m = _field_model(2, 0)
	assert_eq(m.ai.choose(m, Side.FOE).kind, BattleAction.Kind.MOVE, "tier 2 does not notice")

# --- 472: the lexicon page ------------------------------------------------------------------

func test_lexicon_explains_the_ai_tiers() -> void:
	var i: int = RulesBook.PAGES.find("How foes think")
	assert_gt(i, -1)
	var text: String = "\n".join(RulesBook.page(i))
	for tier: int in 4:
		assert_string_contains(text, "Tier %d " % tier)
	for d: int in GameState.AI_LEVELS.size():
		assert_string_contains(text, "%s: Wayfarers think at tier %d." % [MenuHost.DIFFICULTY_TEXT[d], GameState.AI_LEVELS[d]])
	assert_string_contains(text, "up to %d turns ahead" % int(BattleAI.rules_data().plan_turns))

# --- 476: one damage formula ----------------------------------------------------------------

func test_ai_damage_guess_matches_the_preview() -> void:
	var me: Spirling = _ling([E.GALE] as Array[int], [_art(E.EMBER, 40)] as Array[MoveData], 80)
	var foe: Spirling = _ling([E.GALE] as Array[int], [_art(E.STONE, 40)] as Array[MoveData], 120)
	var m: BattleModel = _model([me] as Array[Spirling], [foe] as Array[Spirling], 3)
	var ai := BattleAI.new(3)
	for f: String in ["", "ash_storm", "high_tide"]:
		m.field = f
		var pct: int = CommandMenu.damage_pct(m, me, foe, me.moves[0])
		var guess: float = ai.score_move(m, Side.PLAYER, 0, 0, 0) * 100.0
		assert_almost_eq(guess, float(pct), 0.5, "field '%s': preview %d%%, AI %.2f%%" % [f, pct, guess])
	m.field = "ash_storm"
	var boosted: float = ai.score_move(m, Side.PLAYER, 0, 0, 0)
	m.field = ""
	assert_gt(boosted, ai.score_move(m, Side.PLAYER, 0, 0, 0), "the AI sees the field's boost like the preview")

# --- 477: seeded tie-breaker ----------------------------------------------------------------

func _twins(seed_value: int) -> BattleModel:
	var me: Spirling = _ling([E.GALE] as Array[int], [_art(E.STONE, 40)] as Array[MoveData], 120)
	var foe: Spirling = _ling([E.GALE] as Array[int], [_art(E.STONE, 40), _art(E.STONE, 40)] as Array[MoveData])
	return _model([me] as Array[Spirling], [foe] as Array[Spirling], 3, seed_value)

func test_equal_arts_are_settled_by_the_seed() -> void:
	var picks: Dictionary = {}
	for seed_value: int in range(1, 41):
		var m: BattleModel = _twins(seed_value)
		var state: int = m.rng.state
		var first: int = m.ai.choose(m, Side.FOE).move_index
		assert_eq(m.rng.state, state, "the tie-break draws nothing from the battle dice")
		var again: BattleModel = _twins(seed_value)
		assert_eq(again.ai.choose(again, Side.FOE).move_index, first, "same seed, same pick")
		picks[first] = true
	assert_eq(picks.size(), 2, "the seed, not the art order, decides")
