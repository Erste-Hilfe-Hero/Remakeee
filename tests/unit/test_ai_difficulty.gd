extends GutTest
## Plan area 2, items 741, 742, 746: no heal block on the last Spirling (Story, Tamer), no double
## rest on Veteran, and a lowered difficulty stays on record.

func _model(foe_moves: Array[String], player_count: int = 1) -> BattleModel:
	var rng := RandomNumberGenerator.new()
	var mine: Array[Spirling] = []
	for i: int in player_count:
		mine.append(Spirling.new(Database.species("Mossling"), 12, rng))
	var foe := Spirling.new(Database.species("Shalebat"), 12, rng)
	foe.moves.clear()
	for n: String in foe_moves:
		foe.moves.append(Database.move(n))
	var m := BattleModel.new(mine, [foe] as Array[Spirling], false, 3, 2)
	m.start()
	return m

func test_blocks_heal_detects_the_art() -> void:
	assert_true(BattleAI.blocks_heal(Database.move("Night Toll")))
	assert_false(BattleAI.blocks_heal(Database.move("Mirk Nip")))

func test_no_heal_block_on_the_last_spirling() -> void:
	var m: BattleModel = _model(["Night Toll", "Mirk Nip"])
	m.ai.set_difficulty(GameState.Difficulty.STORY)
	for i: int in 10:
		var a: BattleAction = m.ai.choose(m, BattleModel.Side.FOE)
		if a.kind == BattleAction.Kind.MOVE:
			assert_ne(m.active_spirling(1).moves[a.move_index].move_name, "Night Toll")
	# Only the heal block left: it may still be used rather than nothing.
	m = _model(["Night Toll"])
	m.ai.set_difficulty(GameState.Difficulty.TAMER)
	var only: BattleAction = m.ai.choose(m, BattleModel.Side.FOE)
	assert_true(only.kind == BattleAction.Kind.MOVE or only.kind == BattleAction.Kind.REST)

func test_flags_per_difficulty() -> void:
	var ai := BattleAI.new(2)
	for d: int in 4:
		ai.set_difficulty(d)
		assert_eq(ai.spare_last, d <= GameState.Difficulty.TAMER, "spare_last %d" % d)
		assert_eq(ai.no_double_rest, d == GameState.Difficulty.VETERAN, "no_double_rest %d" % d)

func test_no_double_rest_on_veteran() -> void:
	var m: BattleModel = _model(["Mirk Nip", "Hunker Down"])
	m.ai.set_difficulty(GameState.Difficulty.VETERAN)
	m.ai._rested[0] = true
	# Force the inner pick to a rest by a profile that rests early.
	m.ai.set_profile(m.ai.profile_id, {"rest_below": 99})
	var a: BattleAction = m.ai.choose(m, BattleModel.Side.FOE)
	assert_eq(a.kind, BattleAction.Kind.MOVE, "a second rest in a row becomes an art")
	assert_false(bool(m.ai._rested[0]))
	var b: BattleAction = m.ai.choose(m, BattleModel.Side.FOE)
	assert_eq(b.kind, BattleAction.Kind.REST, "one rest is still fine")

func test_replay_keeps_the_flags() -> void:
	var m: BattleModel = _model(["Mirk Nip"])
	m.ai.set_difficulty(GameState.Difficulty.STORY)
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "")
	assert_true(bool(snap.ai_spare_last))
	assert_false(bool(snap.ai_no_double_rest))

func test_lowering_difficulty_is_recorded() -> void:
	var keep_d: GameState.Difficulty = GameState.difficulty
	var keep_r: Dictionary = GameState.records.duplicate(true)
	GameState.records.erase("difficulty_lowered")
	GameState.difficulty = GameState.Difficulty.VETERAN
	GameState.set_difficulty(GameState.Difficulty.RIFT_BORN)
	assert_false(GameState.difficulty_lowered(), "a step up is not lowering")
	GameState.set_difficulty(GameState.Difficulty.STORY)
	assert_true(GameState.difficulty_lowered())
	assert_eq(GameState.difficulty, GameState.Difficulty.STORY)
	GameState.set_difficulty(GameState.Difficulty.VETERAN)
	assert_true(GameState.difficulty_lowered(), "the mark stays")
	GameState.difficulty = keep_d
	GameState.records = keep_r
