extends GutTest
## Plan area 2, item 685: Warden Spirlings get Spark 10 in their main stat from Veteran on.

func _orrin() -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/cinder_rift.json"))
	for n: Variant in d.npcs:
		if str(n.get("id", "")) == "warden_orrin":
			return n
	return {}

func test_veteran_main_stat_ten() -> void:
	for d: int in [GameState.Difficulty.VETERAN, GameState.Difficulty.RIFT_BORN]:
		for s: Spirling in TrainerData.build_team(_orrin(), "", RandomNumberGenerator.new(), d):
			var main: String = TrainerData.main_stat(s)
			assert_eq(int(s.spark[main]), TrainerData.WARDEN_MAIN_SPARK, "%s %s" % [s.data.species_name, main])
			assert_eq(s.hp, s.max_hp())

func test_tamer_keeps_flat_spark() -> void:
	for s: Spirling in TrainerData.build_team(_orrin(), "", RandomNumberGenerator.new(), GameState.Difficulty.TAMER):
		for key: String in Spirling.STAT_KEYS:
			assert_eq(int(s.spark[key]), GameState.FOE_SPARK[GameState.Difficulty.TAMER])

func test_plain_wayfarer_unchanged() -> void:
	var def: Dictionary = {"team": [{"species": "Kindlop", "level": 10}]}
	var s: Spirling = TrainerData.build_team(def, "", RandomNumberGenerator.new(), GameState.Difficulty.VETERAN)[0]
	assert_eq(int(s.spark.atk), GameState.FOE_SPARK[GameState.Difficulty.VETERAN])

func test_main_stat_follows_arts() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 10, RandomNumberGenerator.new())
	var foc: Array[MoveData] = []
	for mv: MoveData in Database.moves.values():
		if mv.is_damaging() and mv.kind == MoveData.Kind.FOCUS and foc.size() < 2:
			foc.append(mv)
	assert_eq(foc.size(), 2)
	s.moves = foc
	assert_eq(TrainerData.main_stat(s), "foc")

func test_warden_card() -> void:
	var def: Dictionary = _orrin()
	var team: Array[Spirling] = TrainerData.build_team(def, "", RandomNumberGenerator.new(), GameState.Difficulty.VETERAN)
	var t: String = WardenCard.text(def, team, GameState.Difficulty.VETERAN)
	assert_string_contains(t, "Warden Orrin")
	assert_string_contains(t, "Ember Pulse")
	assert_string_contains(t, "Ash Rain")
	assert_string_contains(t, "Spirlings: %d" % team.size())
	assert_true(WardenCard.elements(team).has(Elements.E.EMBER))
	var pic: ImageTexture = WardenCard.picture(team)
	assert_not_null(pic)
	assert_eq(pic.get_height(), ElementIcons.SIZE)
	assert_null(WardenCard.picture([] as Array[Spirling]))
