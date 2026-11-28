extends GutTest
## Chimora 100, items 1-14 (Ali 2026-11-21: "make the game somewhat easier"): Act I is the tutorial
## act on the default difficulty Tamer. Later acts keep their own hard teams (test_act_difficulty.gd).

func before_all() -> void:
	Database.load_all()

func _npc(map_id: String, id: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	for n: Dictionary in (raw as Dictionary).get("npcs", []):
		if str(n.get("id", "")) == id:
			return n
	return {}

func _levels(def: Dictionary, difficulty: int) -> Array[int]:
	var out: Array[int] = []
	for e: Dictionary in TrainerData.team_entries(def, "", difficulty):
		out.append(int(e.level))
	return out

func test_act_one_wardens_on_tamer_sit_just_above_the_base_team() -> void:
	var tamer: int = GameState.Difficulty.TAMER
	assert_eq(_levels(_npc("cinder_rift", "warden_orrin"), tamer), [11, 11, 12] as Array[int])
	assert_eq(_levels(_npc("mist_rift", "warden_brisa"), tamer), [16, 16, 17] as Array[int])
	assert_eq(_levels(_npc("tide_rift", "warden_maelis"), tamer), [16, 17, 18] as Array[int])
	# Mother Crowle closes Act I: a few rings over her base team, not nine (she was a wall at R26-27).
	assert_eq(_levels(ActSim.resolve("pawn_vault:sallow").def, tamer), [22, 23, 22] as Array[int])

func test_rival_jinks_fights_with_his_base_team_on_tamer() -> void:
	var tamer: int = GameState.Difficulty.TAMER
	var one: Dictionary = StoryBattles.get_def("rival_jinks_1")
	assert_eq(_levels(one, tamer), [5, 4] as Array[int])
	for id: String in ["rival_jinks_2", "rival_jinks_3"]:
		var def: Dictionary = StoryBattles.get_def(id)
		assert_false(TrainerData.has_block(def, tamer), "%s has no harder Tamer team" % id)
	assert_eq(TrainerData.team_entries(StoryBattles.get_def("rival_jinks_2"), "", tamer).size(), 3)

func test_newcomers_take_less_damage_on_tamer() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	assert_almost_eq(GameState.foe_damage_mult(), GameState.NEWCOMER_FOE_DAMAGE, 0.001)
	assert_almost_eq(GameState.NEWCOMER_FOE_DAMAGE, 0.9, 0.001)
	while GameState.is_newcomer():
		GameState.receive_spirling(BattleFixtures.make("Mossling", 5))
	assert_almost_eq(GameState.foe_damage_mult(), GameState.FOE_DAMAGE[GameState.Difficulty.TAMER], 0.001)
	assert_almost_eq(GameState.foe_damage_for(GameState.Difficulty.VETERAN, 1), GameState.FOE_DAMAGE[GameState.Difficulty.VETERAN], 0.001,
		"Veteran keeps its full damage")
	assert_almost_eq(GameState.foe_damage_for(GameState.Difficulty.STORY, 1), GameState.FOE_DAMAGE[GameState.Difficulty.STORY], 0.001)

func test_tamer_grows_faster_in_act_one_only() -> void:
	var tamer: int = GameState.Difficulty.TAMER
	assert_almost_eq(GrowthRules.battle_mult(tamer, {}, {}, true), 1.15, 0.001)
	assert_almost_eq(GrowthRules.battle_mult(tamer, {}, {}, false), 1.0, 0.001, "later acts keep their growth")
	assert_almost_eq(GrowthRules.battle_mult(GameState.Difficulty.VETERAN, {}, {}, true), 1.0, 0.001)

## One mode (owner decision 2026-11-27): the settings no longer list difficulties or their hints.
func test_settings_offer_no_difficulty() -> void:
	var consts: Dictionary = load("res://scripts/ui/MenuHost.gd").get_script_constant_map()
	assert_false(consts.has("DIFFICULTY_HINTS") or consts.has("DIFFICULTY_TEXT"), "no difficulty list in the settings")
	assert_false(MenuHost.SETTING_HINTS.has("difficulty"))

## Item 13: Kestra sends the player to Fernstair first, and two lookouts stand at the rough exits
## of Brindlewick until Kestra's spar is done.
func test_kestra_and_the_lookouts_point_to_fernstair_first() -> void:
	var house: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/map_house.json"))
	assert_string_contains("\n".join(PackedStringArray(house.kestra.lines)), "start north in Fernstair")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/brindlewick.json"))
	var exits: Dictionary = {}
	for w: Dictionary in raw.warps:
		exits[str(w.to)] = Vector2i(int(w.x), int(w.y))
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/brindlewick.json"))
	for pair: Array in [["warn_saltmarsh", "saltmarsh"], ["warn_quillbrook", "quillbrook"]]:
		var n: Dictionary = _npc("brindlewick", pair[0])
		assert_false(n.is_empty(), pair[0])
		if n.is_empty():
			continue
		assert_eq(str(n.get("hide_flag", "")), "kestra_spar", "%s leaves once Kestra's spar is done" % pair[0])
		var at := Vector2i(int(n.x), int(n.y))
		assert_lte(absi(at.x - exits[pair[1]].x) + absi(at.y - exits[pair[1]].y), 5, "%s stands on the way to the %s exit" % [pair[0], pair[1]])
		var said: String = "\n".join(PackedStringArray((lines[pair[0]] as Dictionary).lines))
		assert_string_contains(said, "Fernstair")
		assert_string_contains(said, "Kestra")
