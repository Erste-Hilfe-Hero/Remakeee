extends GutTest
## Tamers, Rift Wardens, the rival and the vertical-slice progression (M5).

var _rng := RandomNumberGenerator.new()

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_rng.seed = 11
	GameState.reset()

func _npc(map_id: String, npc_id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func test_kestra_has_her_own_team_not_a_counter_pick() -> void:
	var kestra: Dictionary = _npc("crowcrest", "kestra")
	assert_true(TrainerData.is_trainer(kestra))
	assert_false(kestra.has("team_by_starter"), "Kestra is a counterpart, not a starter rival")
	var a: Array[Spirling] = TrainerData.build_team(kestra, "Kindlop", _rng)
	var b: Array[Spirling] = TrainerData.build_team(kestra, "Mossling", _rng)
	assert_eq(a.size(), b.size())
	for i: int in a.size():
		assert_eq(a[i].data.species_name, b[i].data.species_name)

func test_tamers_only_duel_when_talked_to() -> void:
	for map_id: String in ["crowcrest", "saltmarsh", "cinder_rift", "tide_rift"]:
		for n: Dictionary in MapData.load_map(map_id).npcs:
			assert_eq(int(n.get("sight", 0)), 0, "%s/%s should not ambush" % [map_id, n.get("id", "")])

func test_trainer_battle_info() -> void:
	var bram: Dictionary = _npc("crowcrest", "bram")
	var team: Array[Spirling] = TrainerData.build_team(bram, "Kindlop", _rng)
	assert_eq(team.size(), 2)
	var info: Dictionary = TrainerData.battle_info(bram, team, 0)
	assert_eq(info.name, "Ridgewalker Bram")
	assert_eq(info.money, 8 * TrainerData.MONEY_PER_LEVEL, "default money from top level")
	assert_eq(info.ai, 0)

func test_wardens_use_at_least_greedy_ai() -> void:
	var orrin: Dictionary = _npc("cinder_rift", "warden_orrin")
	assert_eq(TrainerData.ai_tier(orrin, 0), TrainerData.WARDEN_MIN_AI)
	assert_eq(TrainerData.ai_tier(orrin, 2), 2)

func test_line_of_sight() -> void:
	var open: Callable = func(_c: Vector2i) -> bool: return false
	var wall_at_2: Callable = func(c: Vector2i) -> bool: return c == Vector2i(2, 0)
	assert_true(TrainerData.sees(Vector2i.ZERO, Vector2i.RIGHT, 4, Vector2i(3, 0), open))
	assert_false(TrainerData.sees(Vector2i.ZERO, Vector2i.RIGHT, 2, Vector2i(3, 0), open), "out of range")
	assert_false(TrainerData.sees(Vector2i.ZERO, Vector2i.RIGHT, 4, Vector2i(3, 0), wall_at_2), "blocked")
	assert_false(TrainerData.sees(Vector2i.ZERO, Vector2i.LEFT, 4, Vector2i(3, 0), open), "wrong way")
	assert_false(TrainerData.sees(Vector2i.ZERO, Vector2i.RIGHT, 0, Vector2i(1, 0), open), "talk-only")

func test_beaten_flag() -> void:
	var lio: Dictionary = _npc("crowcrest", "lio")
	assert_false(TrainerData.is_beaten(lio, "crowcrest", GameState.flags))
	GameState.set_flag(TrainerData.beaten_flag(lio, "crowcrest"))
	assert_true(TrainerData.is_beaten(lio, "crowcrest", GameState.flags))
	var kestra: Dictionary = _npc("crowcrest", "kestra")
	assert_eq(TrainerData.beaten_flag(kestra, "crowcrest"), "kestra_spar")

func test_sealing_rifts_raises_veteran_cap_and_unlocks_pc() -> void:
	GameState.difficulty = GameState.Difficulty.VETERAN
	var cap0: int = GameState.level_cap()
	assert_true(GameState.seal_rift("cinder"))
	assert_false(GameState.seal_rift("cinder"), "only once")
	assert_gt(GameState.level_cap(), cap0)
	assert_true(GameState.has_flag("rift_cinder_sealed"))
	assert_false(GameState.has_flag("storage_remote"), "one Rift is not enough")
	var maelis: Dictionary = _npc("tide_rift", "warden_maelis")
	assert_eq(str(maelis.warden), "tide")
	assert_true(GameState.seal_rift("tide"))
	assert_true(GameState.has_flag("storage_remote"), "Storage from the menu after the second Rift")

func test_rifts_open_in_any_order() -> void:
	assert_true(GameState.seal_rift("tide"))
	assert_true(GameState.seal_rift("cinder"))
	assert_true(GameState.has_flag("storage_remote"))

func test_bag_is_unlimited() -> void:
	GameState.add_item("tonic", 5000)
	GameState.add_item("tonic", 5000)
	assert_eq(GameState.item_count("tonic"), 10000)

func test_starter_is_saved() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Ada", 1, "Puddlet")
	var d: Dictionary = GameState.to_dict()
	GameState.reset()
	GameState.from_dict(d)
	assert_eq(GameState.starter, "Puddlet")
	GameState.reset()
