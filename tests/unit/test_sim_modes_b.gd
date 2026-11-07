extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 816, 819, 822): baseline comparison,
## puzzle mode and the --difficulty switch of the simulator.

const SimTool: GDScript = preload("res://tools/balance_sim.gd")

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	BalanceSim.sim_field = ""
	BalanceSim.sim_variants = []
	BalanceSim.sim_difficulty = -1

func test_baseline_file_is_a_level_36_team_result() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(BalanceSim.BASELINE_PATH))
	assert_true(raw is Dictionary)
	assert_eq(str(raw.mode), "team")
	assert_eq(int(raw.level), 36)
	assert_gt((raw.species as Dictionary).size(), 20)
	var some: Dictionary = (raw.moves as Dictionary).values()[0]
	assert_true(some.has("win_uses"), "arts carry their win uses")

func test_compare_flags_only_shifts_beyond_eight_points() -> void:
	var base: Dictionary = {"mode": "team", "level": 36,
		"species": {"A": {"wins": 50, "losses": 50, "draws": 0}, "B": {"wins": 50, "losses": 50, "draws": 0}},
		"moves": {"Zap": {"used": 40, "kos": 0, "win_uses": 20}, "Nip": {"used": 40, "kos": 0, "win_uses": 20}, "Rare": {"used": 4, "kos": 0, "win_uses": 2}}}
	var now: Dictionary = base.duplicate(true)
	now.species.A = {"wins": 60, "losses": 40, "draws": 0}
	now.species.B = {"wins": 57, "losses": 43, "draws": 0}
	now.moves.Zap = {"used": 40, "kos": 0, "win_uses": 10}
	now.moves.Rare = {"used": 4, "kos": 0, "win_uses": 0}
	var cmp: Dictionary = BalanceSim.compare(now, base)
	assert_eq((cmp.species as Array).map(func(r: Dictionary) -> String: return r.name), ["A"])
	assert_eq((cmp.moves as Array).map(func(r: Dictionary) -> String: return r.name), ["Zap"])
	assert_string_contains(BalanceSim.compare_report(cmp), "| Species | A | 50% | 60% | +10 |")
	assert_string_contains(BalanceSim.compare_report(BalanceSim.compare(base, base)), "No species or art moved")
	now.level = 20
	assert_false(str(BalanceSim.compare(now, base).mismatch).is_empty())

func test_team_mode_books_win_uses_per_art() -> void:
	var r: Dictionary = BalanceSim.run_team(20, 6, 3)
	var used: int = 0
	var won: int = 0
	for n: String in r.moves:
		used += int(r.moves[n].used)
		won += int(r.moves[n].win_uses)
		assert_between(BalanceSim.move_win_rate(r.moves[n]), 0.0, 1.0)
	assert_gt(won, 0)
	assert_lt(won, used)

func test_puzzle_mode_solves_a_puzzle_and_checks_its_lantern_target() -> void:
	var r: Dictionary = BalanceSim.run_puzzles("current_trial_1")
	assert_eq(r.puzzles.keys(), ["current_trial_1"])
	var row: Dictionary = r.puzzles.current_trial_1
	assert_true(bool(row.solvable))
	assert_gt(int(row.lines), int(row.wins))
	assert_true(bool(row.target_reachable))
	assert_string_contains(BalanceSim.puzzle_report(r), "current_trial_1")

func test_difficulty_names_and_numbers_parse() -> void:
	assert_eq(SimTool.difficulty_index("story"), 0)
	assert_eq(SimTool.difficulty_index("Rift-Born"), 3)
	assert_eq(SimTool.difficulty_index("2"), 2)
	assert_eq(SimTool.difficulty_index("hard"), -1)
	assert_false(SimTool.apply_switches(BalanceSim, {"difficulty": "hard"}).is_empty())
	assert_eq(SimTool.apply_switches(BalanceSim, {"difficulty": "veteran"}), "")
	assert_eq(BalanceSim.sim_difficulty, 2)

func _model() -> BattleModel:
	return BattleModel.new([BattleFixtures.make("Kindlop", 20)] as Array[Spirling], [BattleFixtures.make("Mossling", 20)] as Array[Spirling], false, 1, 1)

func test_difficulty_tunes_the_foe_side_like_a_wayfarer() -> void:
	for d: int in GameState.AI_LEVELS.size():
		var m: BattleModel = _model()
		BalanceSim.tune_foes(m, d)
		var foe: Spirling = m.parties[BattleModel.Side.FOE][0]
		var mine: Spirling = m.parties[BattleModel.Side.PLAYER][0]
		assert_eq(foe.level, 20 + GameState.FOE_LEVEL_SHIFT[d])
		assert_eq(mine.level, 20, "the player side stays as built")
		assert_eq(int(foe.spark.get("atk", 0)), GameState.FOE_SPARK[d])
		assert_eq(foe.hp, foe.max_hp())
		assert_eq(m.ai.level, TrainerData.ai_tier({}, GameState.AI_LEVELS[d], d))
		assert_eq(m.foe_damage_mult, GameState.FOE_DAMAGE[d])
		assert_eq(m.start_energy_cut, [0, BattleRules.foe_start_cut(d)])
		assert_eq(m.foe_turn1_energy, BattleRules.foe_turn1_energy(d))

func test_ladder_keeps_its_own_tiers_under_a_difficulty() -> void:
	var m: BattleModel = _model()
	m.ai.level = 0
	BalanceSim.tune_foes(m, 3, false)
	assert_eq(m.ai.level, 0)
