extends GutTest
## Battle UX helpers: matchup knowledge, move button lines, battle speed settings.

const BF = preload("res://tests/helpers/BattleFixtures.gd")

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_matchup_unknown_until_learned() -> void:
	var foe: Spirling = Spirling.new(Database.species("Mossling"), 5)
	assert_eq(GameState.known_multiplier(Elements.E.EMBER, foe), -1.0)
	GameState.learn_matchup(Elements.E.EMBER, "Mossling", 2.0)
	assert_eq(GameState.known_multiplier(Elements.E.EMBER, foe), 2.0)

func test_story_difficulty_knows_every_matchup() -> void:
	GameState.difficulty = GameState.Difficulty.STORY
	var foe: Spirling = Spirling.new(Database.species("Mossling"), 5)
	assert_eq(GameState.known_multiplier(Elements.E.EMBER, foe), Elements.multiplier(Elements.E.EMBER, foe.elements()))

func test_matchups_survive_save_round_trip() -> void:
	GameState.learn_matchup(Elements.E.TIDE, "Kindlop", 2.0)
	var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.reset()
	GameState.from_dict(d)
	assert_eq(float(GameState.known_matchups.get("%d:Kindlop" % Elements.E.TIDE, -1.0)), 2.0)

func test_matchup_tags() -> void:
	assert_eq(CommandMenu.matchup_tag(-1.0), "")
	assert_eq(CommandMenu.matchup_tag(1.0), "")
	assert_eq(CommandMenu.matchup_tag(2.0), "x2")
	assert_eq(CommandMenu.matchup_tag(4.0), "x4")
	assert_eq(CommandMenu.matchup_tag(0.5), "x.5")
	assert_eq(CommandMenu.matchup_tag(0.25), "x.25")

func test_move_line_shows_cost_tag_and_missing_energy() -> void:
	var mv: MoveData = BF.move(Elements.E.EMBER, 40)
	mv.energy_cost = 3
	assert_eq(CommandMenu.move_line(mv, 10, 2.0), "3E x2")
	assert_eq(CommandMenu.move_line(mv, 10, -1.0), "3E")
	assert_eq(CommandMenu.move_line(mv, 2, 2.0), "need 3E")

func test_battle_speed_cycles_and_old_setting_migrates() -> void:
	GameState.battle_speed = 0
	GameState.cycle_battle_speed()
	assert_eq(GameState.battle_speed_scale(), 2.0)
	GameState.cycle_battle_speed()
	assert_eq(GameState.battle_speed_scale(), 4.0)
	GameState.cycle_battle_speed()
	assert_eq(GameState.battle_speed_scale(), 1.0)
	GameState.settings_from_dict({"fast_forward": true})
	assert_eq(GameState.battle_speed, 1)
	GameState.settings_from_dict({"battle_speed": 2, "auto_battle": true})
	assert_eq(GameState.battle_speed, 2)
	assert_true(GameState.auto_battle)
	GameState.settings_from_dict({})
	assert_eq(GameState.battle_speed, 0)
	assert_false(GameState.auto_battle)

func test_auto_battle_ai_returns_legal_player_action() -> void:
	var m: BattleModel = BF.model([BF.make("Kindlop", 8)], [BF.make("Mossling", 6)])
	m.start()
	var a: BattleAction = BattleAI.new(1).choose(m, BattleModel.Side.PLAYER)
	assert_true(m.is_legal(a))
