extends GutTest
## Own ideas 200, batch 2: fine training (1114), challenge rules (1112), New Game Plus (1111),
## weekly tower rules (1103) and the Gravers' Hall NPCs for bounties and training.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _mon() -> Spirling:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return Spirling.new(Database.spirlings["Kindlop"], 10, rng)

func test_fine_training_costs_rise_and_caps() -> void:
	var s: Spirling = _mon()
	s.spark["atk"] = 0
	GameState.money = 100000
	var c0: int = FineTraining.cost(s, "atk")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var raised: int = 0
	for i: int in 40:
		var r: Dictionary = FineTraining.train(s, "atk", rng)
		if bool(r.ok) and not bool(r.scammed):
			raised += 1
	assert_eq(int(s.spark.atk), Spirling.SPARK_MAX)
	assert_eq(raised, Spirling.SPARK_MAX)
	assert_gt(FineTraining.cost(s, "atk"), c0)
	assert_false(FineTraining.can_train(s, "atk"), "maxed")
	assert_false(FineTraining.can_train(s, "luck"), "unknown stat")

func test_fine_training_scam_takes_money_only() -> void:
	var s: Spirling = _mon()
	s.spark["def"] = 0
	GameState.money = 100000
	var scams: int = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in 60:
		s.spark["def"] = 0
		var before: int = GameState.money
		var r: Dictionary = FineTraining.train(s, "def", rng)
		assert_eq(GameState.money, before - FineTraining.data().base_cost)
		if bool(r.scammed):
			scams += 1
			assert_eq(int(s.spark.def), 0)
	assert_gt(scams, 0)
	assert_lt(scams, 60)

func test_fine_training_needs_money() -> void:
	GameState.money = 0
	assert_false(FineTraining.can_train(_mon(), "hp"))
	assert_false(bool(FineTraining.train(_mon(), "hp", GameState.rng).ok))

func test_challenge_rules() -> void:
	assert_eq(ChallengeRules.ids().size(), 4)
	assert_true(ChallengeRules.items_allowed())
	ChallengeRules.toggle("no_items")
	assert_false(ChallengeRules.items_allowed())
	ChallengeRules.toggle("no_items")
	assert_true(ChallengeRules.items_allowed())
	ChallengeRules.toggle("bogus")
	assert_eq(GameState.records.get(ChallengeRules.KEY, []), [])
	var starter: SpirlingData = Database.spirlings["Kindlop"]
	var other: SpirlingData = Database.spirlings["Puddlet"]
	assert_true(ChallengeRules.may_join(other, starter))
	ChallengeRules.toggle("one_element")
	assert_true(ChallengeRules.may_join(Database.spirlings["Smoldrake"], starter))
	assert_false(ChallengeRules.may_join(other, starter))
	assert_eq(ChallengeRules.walkout(3, GameState.rng), -1)
	ChallengeRules.toggle("trust_no_one")
	var w: int = ChallengeRules.walkout(3, GameState.rng)
	assert_between(w, 0, 2)
	assert_eq(ChallengeRules.walkout(1, GameState.rng), -1, "never the last one")

func test_new_game_plus() -> void:
	assert_eq(NewGamePlus.cycle(), 0)
	assert_eq(NewGamePlus.foe_ring(20), 20)
	assert_false(NewGamePlus.can_start(false))
	assert_true(NewGamePlus.can_start(true))
	NewGamePlus.advance()
	assert_eq(NewGamePlus.foe_ring(20), 20 + int(NewGamePlus.data().ring_bonus))
	assert_eq(NewGamePlus.foe_ring(59), Spirling.MAX_LEVEL)
	for i: int in 10:
		if NewGamePlus.can_start(true):
			NewGamePlus.advance()
	assert_eq(NewGamePlus.cycle(), int(NewGamePlus.data().max_cycles))
	assert_true("spirlog" in NewGamePlus.kept())

func test_tower_week_rules() -> void:
	assert_eq(TowerWeek.rule("2026-W46"), TowerWeek.rule("2026-W46"))
	var seen: Dictionary = {}
	for w: int in range(1, 53):
		var id: String = TowerWeek.rule("2026-W%02d" % w)
		assert_true(BattleRules.RULES.has(id), id)
		assert_false(bool(BattleRules.RULES[id].get("warden_only", false)), id)
		seen[id] = true
	assert_gt(seen.size(), 2)
	assert_ne(TowerWeek.label("2026-W46"), "")

func test_gravers_hall_npcs_are_wired() -> void:
	var d: Dictionary = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/gravers_hall.json")))
	assert_eq(str(d.fixer.action), "bounty")
	assert_eq(str(d.coach.action), "fine_training")
