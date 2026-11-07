extends GutTest
## Plan area 2, items 743, 745, 747, 748: Rift-Born team sizes, the difficulty table and bosses
## per difficulty.

func _boss_model(difficulty: int, fielded: int) -> BattleModel:
	var mine: Array[Spirling] = []
	for i: int in fielded:
		mine.append(BattleFixtures.make("Puddlet", 14, ["Fizz Pop"]))
	var boss: Spirling = BattleFixtures.make("Smoldrake", 14, ["Cinder Nip"])
	var m: BattleModel = BattleFixtures.model(mine, [boss] as Array[Spirling], false)
	m.front_size = [fielded, 1]
	m.foe_boss = "ashen_heart"
	m.boss_difficulty = difficulty
	m.start()
	return m

func test_story_boss_acts_once() -> void:
	assert_eq(BattleRules.boss_actions_for("ashen_heart", 4, GameState.Difficulty.STORY), 1)
	assert_eq(BattleRules.boss_actions_for("ashen_heart", 4, GameState.Difficulty.TAMER), BattleRules.boss_actions("ashen_heart", 4))
	assert_eq(BattleRules.boss_actions_for("ashen_heart", 4, -1), BattleRules.boss_actions("ashen_heart", 4))

func test_rift_born_phase_at_sixty_percent_and_one_more_action() -> void:
	assert_almost_eq(BattleRules.boss_phase_at("ashen_heart", GameState.Difficulty.RIFT_BORN), 0.6, 0.001)
	assert_almost_eq(BattleRules.boss_phase_at("ashen_heart", GameState.Difficulty.VETERAN), 0.5, 0.001)
	var m: BattleModel = _boss_model(GameState.Difficulty.RIFT_BORN, 1)
	var boss: Spirling = m.active_spirling(1)
	var before: int = m._boss_actions
	m.deal_damage(1, int(boss.max_hp() * 0.45))
	assert_true(m.boss_phase_done, "awake below 60 %")
	assert_eq(m._boss_actions, before + 1)
	var v: BattleModel = _boss_model(GameState.Difficulty.VETERAN, 1)
	v.deal_damage(1, int(v.active_spirling(1).max_hp() * 0.45))
	assert_false(v.boss_phase_done, "Veteran still waits for half")

func test_replay_keeps_boss_difficulty() -> void:
	var m: BattleModel = _boss_model(GameState.Difficulty.STORY, 1)
	assert_eq(int(BattleReplay.snapshot(m, "battle", "").boss_difficulty), GameState.Difficulty.STORY)

func test_rift_born_teams_one_larger() -> void:
	var rb: int = GameState.Difficulty.RIFT_BORN
	var tamer: int = GameState.Difficulty.TAMER
	for f: String in DirAccess.get_files_at("res://data/maps"):
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		if not d is Dictionary:
			continue
		for n: Variant in (d as Dictionary).get("npcs", []):
			var def: Dictionary = n
			if def.has("boss") or TrainerData.is_wild_horde(def) or TrainerData.team_entries(def, "Kindlop", tamer).is_empty():
				continue
			var base: int = TrainerData.build_team(def, "Kindlop", RandomNumberGenerator.new(), tamer).size()
			var hard: int = TrainerData.build_team(def, "Kindlop", RandomNumberGenerator.new(), rb).size()
			assert_eq(hard, mini(base + 1, TrainerData.RIFT_BORN_MAX_TEAM), "%s/%s" % [f, def.get("id", "")])

func test_shared_team_copy_has_no_keepsake() -> void:
	var def: Dictionary = {"team": [{"species": "Kindlop", "level": 10, "held": "spark_coil"}, {"species": "Zippit", "level": 8, "held": "spark_coil"}]}
	var team: Array[Spirling] = TrainerData.build_team(def, "", RandomNumberGenerator.new(), GameState.Difficulty.RIFT_BORN)
	assert_eq(team.size(), 3)
	assert_eq(team[2].data.species_name, "Zippit", "the lowest ring is copied")
	assert_eq(team[2].held, "")

func test_difficulty_table_has_six_lines() -> void:
	for d: int in 4:
		var lines: Array[String] = DifficultyTable.lines(d)
		assert_eq(lines.size(), 6)
		assert_true(DifficultyTable.hint(d, "x").contains(lines[5]))
	assert_true(DifficultyTable.lines(GameState.Difficulty.TAMER)[2].contains("2"), "Tamer Wardens play tier 2")
	assert_true(DifficultyTable.lines(GameState.Difficulty.RIFT_BORN)[4].contains("no"))
