extends GutTest
## Wayfarers, Rift Wardens, the rival and the vertical-slice progression (M5).

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
	assert_eq(info.money, 8 * 40, "default money: top ring times 40 (item 659)")
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

# --- Plan area 2, items 645-659 ------------------------------------------------------------

## Every Wayfarer and Warden on every map with its team blocks: [map_id, npc, [entries...]].
func _team_blocks() -> Array:
	var out: Array = []
	var dir := DirAccess.open(MapData.DIR)
	for f: String in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var map_id: String = f.get_basename()
		var m: MapData = MapData.load_map(map_id)
		if m == null:
			continue
		for n: Dictionary in m.npcs:
			if not TrainerData.is_trainer(n) or bool(n.get("wild", false)):
				continue
			var blocks: Array = []
			if n.get("team") is Array:
				blocks.append(n.team)
			if n.get("team_by_starter") is Dictionary:
				blocks.append_array((n.team_by_starter as Dictionary).values())
			if n.get("teams_by_difficulty") is Dictionary:
				blocks.append_array((n.teams_by_difficulty as Dictionary).values())
			for b: Variant in blocks:
				out.append([map_id, n, b])
	return out

func test_no_twin_species_on_the_same_ring() -> void:
	for row: Array in _team_blocks():
		var n: Dictionary = row[1]
		if str(n.get("id", "")) == "bram" or n.has("warden") or n.has("boss"):
			continue
		var seen: Dictionary = {}
		for e: Dictionary in row[2]:
			var k: String = "%s@%d" % [e.species, int(e.get("level", 5))]
			assert_false(seen.has(k), "%s/%s carries %s twice" % [row[0], n.id, k])
			seen[k] = true

## Set pieces show a mix on purpose: Kestra's practice duel, the tag battle and Ilka's 3 v 3.
const MIXED_TEAMS: Array[String] = ["kestra", "kestra_tag", "mystic"]

func test_wayfarer_teams_keep_to_three_elements() -> void:
	for row: Array in _team_blocks():
		var n: Dictionary = row[1]
		if n.has("warden") or n.has("boss") or str(n.get("id", "")) in MIXED_TEAMS:
			continue
		var els: Dictionary = {}
		for e: Dictionary in row[2]:
			for el: int in Database.species(str(e.species)).elements:
				els[el] = true
		assert_lte(els.size(), 3, "%s/%s covers %d elements" % [row[0], n.id, els.size()])

func test_wayfarers_stay_near_the_wild_rings() -> void:
	var enc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounters.json"))
	for row: Array in _team_blocks():
		var n: Dictionary = row[1]
		if n.has("warden") or n.has("boss") or row[2] != n.get("team"):
			continue
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapData.DIR + str(row[0]) + ".json"))
		var table: Variant = enc.get(str(raw.get("encounters", "")), {})
		if not table is Dictionary or (table as Dictionary).get("spawns", []).is_empty():
			continue
		var wild_top: int = 0
		for sp: Dictionary in table.spawns:
			wild_top = maxi(wild_top, int(sp.get("max", 0)))
		var top: int = 0
		for e: Dictionary in row[2]:
			top = maxi(top, int(e.get("level", 5)))
		assert_lte(top, wild_top + 2, "%s/%s ring %d vs wild %d" % [row[0], n.id, top, wild_top])

## Fixed arts may come early (a Wayfarer's trained pick, items 640-648), but each one is in the
## species' learn list or of one of its own elements, so no foe carries a foreign art.
func test_fixed_arts_fit_the_species() -> void:
	for row: Array in _team_blocks():
		for e: Dictionary in row[2]:
			var sd: SpirlingData = Database.species(str(e.species))
			var known: Dictionary = {}
			for mv: MoveData in sd.learnset_moves:
				known[mv.move_name] = true
			for m: Variant in e.get("moves", []):
				var mv: MoveData = Database.move(str(m))
				assert_not_null(mv, str(m))
				if mv != null:
					assert_true(known.has(mv.move_name) or mv.element in sd.elements, "%s/%s: %s and %s don't fit" % [row[0], row[1].id, e.species, m])

func test_default_prize_money_follows_the_ring() -> void:
	var orrin: Dictionary = _npc("cinder_rift", "warden_orrin").duplicate()
	orrin.erase("money")
	var team: Array[Spirling] = TrainerData.build_team(orrin, "Kindlop", _rng)
	var top: int = 0
	for s: Spirling in team:
		top = maxi(top, s.level)
	assert_eq(TrainerData.prize_money(orrin, team), top * 70, "Wardens: top ring times 70")
	assert_eq(TrainerData.prize_money(_npc("fernstair", "imme"), team), 120, "an explicit money key wins")

func test_new_wayfarers_are_placed() -> void:
	var want: Dictionary = {"fernstair/imme": "apprentice", "fernstair/joss": "wall", "saltmarsh/aud": "spoiler", "murk_hollow/fenn": "field_keeper"}
	for key: String in want:
		var parts: PackedStringArray = key.split("/")
		var n: Dictionary = _npc(parts[0], parts[1])
		assert_true(TrainerData.is_trainer(n), key)
		assert_eq(str(n.get("profile", "")), str(want[key]), key)
		assert_true(Dialogue.exists(str(n.intro)) and Dialogue.exists(str(n.defeat)), key)
	assert_eq(int(_npc("fernstair", "imme").money), 120)
