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

func test_rival_counter_picks_the_starter() -> void:
	var kestra: Dictionary = _npc("route_2", "kestra")
	assert_true(TrainerData.is_trainer(kestra))
	var expect: Dictionary = {"Kindlop": "Puddlet", "Puddlet": "Mossling", "Mossling": "Kindlop"}
	for starter: String in expect:
		var team: Array[Spirling] = TrainerData.build_team(kestra, starter, _rng)
		assert_eq(team.back().data.species_name, expect[starter], "rival ace vs %s" % starter)

func test_trainer_battle_info() -> void:
	var bram: Dictionary = _npc("route_2", "bram")
	var team: Array[Spirling] = TrainerData.build_team(bram, "Kindlop", _rng)
	assert_eq(team.size(), 2)
	var info: Dictionary = TrainerData.battle_info(bram, team, 0)
	assert_eq(info.name, "Hiker Bram")
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
	var lio: Dictionary = _npc("route_2", "lio")
	assert_false(TrainerData.is_beaten(lio, "route_2", GameState.flags))
	GameState.set_flag(TrainerData.beaten_flag(lio, "route_2"))
	assert_true(TrainerData.is_beaten(lio, "route_2", GameState.flags))
	var kestra: Dictionary = _npc("route_2", "kestra")
	assert_eq(TrainerData.beaten_flag(kestra, "route_2"), "rival_kestra_1")

func test_sealing_rifts_raises_veteran_cap_and_unlocks_pc() -> void:
	GameState.difficulty = GameState.Difficulty.VETERAN
	var cap0: int = GameState.level_cap()
	assert_true(GameState.seal_rift("cinder"))
	assert_false(GameState.seal_rift("cinder"), "only once")
	assert_gt(GameState.level_cap(), cap0)
	assert_true(GameState.has_flag("rift_cinder_sealed"), "opens the guard path")
	var maelis: Dictionary = _npc("tide_rift", "warden_maelis")
	assert_eq(str(maelis.warden), "tide")
	assert_true("pc_unlocked" in maelis.win_flags, "PC access from the menu after Rift 2")

func test_guard_hides_after_rift_one() -> void:
	var guard: Dictionary = _npc("thornridge", "guard")
	assert_eq(str(guard.hide_flag), "rift_cinder_sealed")

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
