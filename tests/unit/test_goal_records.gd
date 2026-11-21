extends GutTest
## Plan area 2, items 749, 766, 767, 769: foe start Energy per difficulty, goal results, the lexicon
## counter and short goal texts.

func _model() -> BattleModel:
	var mine: Array[Spirling] = [BattleFixtures.make("Puddlet", 12, ["Fizz Pop"])]
	var foes: Array[Spirling] = [BattleFixtures.make("Kindlop", 12, ["Cinder Nip"])]
	return BattleFixtures.model(mine, foes, false)

func test_story_foes_start_with_eight() -> void:
	var m: BattleModel = _model()
	m.start_energy_cut = [0, BattleRules.foe_start_cut(GameState.Difficulty.STORY)]
	m.start()
	assert_eq(m.active_spirling(1).energy, 8)
	assert_eq(m.active_spirling(0).energy, 10, "the player keeps 10")
	for d: int in [GameState.Difficulty.TAMER, GameState.Difficulty.VETERAN, GameState.Difficulty.RIFT_BORN]:
		assert_eq(BattleRules.foe_start_cut(d), 0)

func test_rift_born_foes_gain_one_more_in_turn_one() -> void:
	var a: BattleModel = _model()
	a.start()
	var b: BattleModel = _model()
	b.foe_turn1_energy = BattleRules.foe_turn1_energy(GameState.Difficulty.RIFT_BORN)
	b.start()
	for m: BattleModel in [a, b]:
		m.active_spirling(1).energy = 4
		m.submit_turn(BattleAction.make_rest(BattleModel.Side.PLAYER))
	assert_eq(b.active_spirling(1).energy - a.active_spirling(1).energy, 1)
	var e2a: int = a.active_spirling(1).energy
	var e2b: int = b.active_spirling(1).energy
	a.submit_turn(BattleAction.make_rest(BattleModel.Side.PLAYER))
	b.submit_turn(BattleAction.make_rest(BattleModel.Side.PLAYER))
	assert_eq(b.active_spirling(1).energy - e2b, a.active_spirling(1).energy - e2a, "only turn 1")
	assert_eq(int(BattleReplay.snapshot(b, "battle", "").foe_turn1_energy), 1)

func test_goal_results_migrate_and_keep_best_turns() -> void:
	var rec: Dictionary = {"goals_done": {"crowcrest/bram": true}}
	assert_true(bool(BattleGoals.results(rec)["crowcrest/bram"].done))
	var m: BattleModel = _model()
	var t := BattleGoals.Tracker.new(m, {"type": "no_rest"})
	m.outcome = BattleModel.Outcome.WIN
	var e: Dictionary = BattleGoals.note(rec, "crowcrest/lio", t)
	assert_true(bool(e.done))
	assert_eq(int(rec.goals["crowcrest/bram"].best_turns), 0, "old entries start empty")
	assert_true(bool(rec.goals["crowcrest/bram"].done))
	m.outcome = BattleModel.Outcome.LOSS
	BattleGoals.note(rec, "crowcrest/kestra", t)
	assert_false(bool(rec.goals["crowcrest/kestra"].done))

func test_lexicon_counts_per_map() -> void:
	var maps: Array[String] = BattleGoals.maps()
	assert_false(maps.is_empty())
	var m0: String = maps[0]
	var keys: Array[String] = []
	for k: String in BattleGoals.all():
		if k.begins_with(m0 + "/"):
			keys.append(k)
	var rec: Dictionary = {"goals": {keys[0]: {"done": true, "best_turns": 3}}}
	assert_eq(BattleGoals.map_count(rec, m0), [1, keys.size()] as Array[int])
	assert_true(BattleGoals.lexicon_text(rec).contains("1"))

func test_goal_texts_fit_the_card() -> void:
	var before: String = Loc.language()
	for lang: String in ["en", "de"]:
		Loc.set_language(lang)
		for k: String in BattleGoals.all():
			var text: String = BattleGoals.card_text(BattleGoals.all()[k])
			assert_false(text.is_empty(), k)
			assert_lte(text.length(), BattleGoals.CARD_CHARS, "%s %s: %s" % [lang, k, text])
	Loc.set_language(before)
