extends GutTest
## Save migration (item 98): real-shaped saves from every older format load, land somewhere
## walkable and survive a save/load round trip unchanged. Add a fixture here whenever
## SAVE_VERSION goes up or GameState gains a saved field.

const FIXTURES: String = "res://tests/fixtures/saves/"

var _saved: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_saved = GameState.to_dict()

func after_each() -> void:
	GameState.from_dict(_saved)

func _load_fixture(name: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name))
	assert_true(raw is Dictionary, name)
	var d: Variant = SaveManager.migrate(raw)
	assert_true(d is Dictionary, name + " migrates")
	return d

func _fixtures() -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(FIXTURES):
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out

func test_there_is_a_fixture_per_old_version() -> void:
	var versions: Dictionary = {}
	for f: String in _fixtures():
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + f))
		versions[int(raw.get("save_version", 0))] = true
	for v: int in SaveManager.SAVE_VERSION + 1:
		assert_true(versions.has(v), "no fixture for save_version %d" % v)

func test_every_fixture_loads_onto_a_walkable_cell() -> void:
	for f: String in _fixtures():
		var d: Dictionary = _load_fixture(f)
		assert_eq(int(d.save_version), SaveManager.SAVE_VERSION, f)
		SaveManager.apply_save(d)
		assert_true(MapData.exists(GameState.current_map), "%s: map %s" % [f, GameState.current_map])
		var m: MapData = MapData.load_map(GameState.current_map)
		assert_true(m.is_walkable(GameState.player_cell), "%s: player cell" % f)
		assert_true(MapData.exists(GameState.heal_map), "%s: heal map" % f)
		assert_true(MapData.load_map(GameState.heal_map).is_walkable(GameState.heal_cell), "%s: heal cell" % f)
		for s: Spirling in GameState.party + GameState.storage:
			assert_false(s.moves.is_empty(), "%s: %s has moves" % [f, s.data.species_name])
			assert_between(s.hp, 0, s.max_hp(), f)

func test_round_trip_is_stable() -> void:
	for f: String in _fixtures():
		SaveManager.apply_save(_load_fixture(f))
		var first: Dictionary = GameState.to_dict()
		GameState.from_dict(first.duplicate(true))
		var second: Dictionary = GameState.to_dict()
		second.erase("play_time")
		first.erase("play_time")
		assert_eq(JSON.stringify(second, "", true), JSON.stringify(first, "", true), f)

func test_v1_keeps_team_items_and_old_flags() -> void:
	SaveManager.apply_save(_load_fixture("v1_routes.json"))
	assert_eq(GameState.tamer_name, "Ali")
	assert_eq(GameState.party.size(), 2)
	assert_eq(GameState.party[0].spark.atk, 12)
	assert_eq(int(GameState.inventory.get("tonic", 0)), 3)
	assert_eq(GameState.current_map, "fernstair")
	assert_eq(GameState.heal_map, "brindlewick")
	assert_true(GameState.has_flag("aldo_gift"))
	assert_true(GameState.has_flag("fern_gift"))

func test_v2_gets_defaults_for_newer_fields() -> void:
	SaveManager.apply_save(_load_fixture("v2_before_extras.json"))
	assert_eq(GameState.party[0].nickname, "Ember")
	assert_eq(GameState.party[0].held, "")
	assert_false(GameState.party[0].prism)
	assert_eq(GameState.storage.size(), 1)
	assert_true(GameState.visited_rests.has("thornridge"), "last rest spot counts for fast travel")
	assert_eq(GameState.records, {})
	assert_eq(Achievements.check().size() >= 1, true, "old progress earns achievements")

func test_every_saved_key_is_optional() -> void:
	# A save missing any one top-level key (older or hand-edited) still loads.
	GameState.new_game(GameState.Difficulty.TAMER, "Juno", 0, "Kindlop")
	var full: Dictionary = GameState.to_dict()
	for key: String in full.keys():
		var d: Dictionary = full.duplicate(true)
		d.erase(key)
		GameState.from_dict(d)
		assert_false(GameState.party.is_empty() and key != "party", "missing '%s' drops the party" % key)
	GameState.from_dict(full)
	assert_eq(GameState.party.size(), 1)

func test_v2_to_v3_renames_moves_and_flag_and_trims_the_team() -> void:
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "v2_before_extras.json"))
	old.party[0]["moves"] = ["Headlong Charge", "Flare Lash"]
	for i: int in 4:
		old.party.append({"species": "Zippit", "level": 5, "hp": 10, "moves": ["Tailwind Step"], "uid": "z%d" % i})
	var d: Dictionary = SaveManager.migrate(old)
	assert_eq(int(d.save_version), SaveManager.SAVE_VERSION)
	assert_eq(d.party.size(), 5)
	assert_eq(d.storage.size(), 2, "the sixth Spirling rests in storage")
	assert_eq(d.party[0].moves, ["Bowl Over", "Kiln Strike"])
	assert_true(d.flags.has("storage_remote"))
	assert_false(d.flags.has("pc_unlocked"))
	SaveManager.apply_save(d)
	assert_eq(GameState.party.size(), GameState.MAX_PARTY)
	assert_true(GameState.has_flag("storage_remote"))
