extends GutTest
## Area 3 hidden finds and encounter tables (items 1078 to 1081, 1109 to 1111, 1114, 1115).

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	EncounterTable._guard = 0

func test_every_outdoor_map_hides_three_to_five_finds() -> void:
	var outdoor: int = 0
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if not m.outdoor:
			continue
		outdoor += 1
		assert_between(m.secrets.size(), 3, 5, "%s has %d hidden finds" % [id, m.secrets.size()])
	assert_gt(outdoor, 3)

func test_old_find_signs_are_hidden_finds_now() -> void:
	# Item 1081: same flags as before, so old saves keep what they already found.
	var want: Dictionary = {"saltmarsh": "marsh_reed_find", "murk_hollow": "hollow_find", "fernstair": "fern_rock_find",
		"brindlewick": "islet_find", "thornridge": "thorn_rock_find"}
	for id: String in want:
		var m: MapData = MapData.load_map(id)
		var flags: Array = m.secrets.map(func(s: Dictionary) -> String: return str(s.flag))
		assert_has(flags, want[id], id)
	assert_has(MapData.load_map("murk_hollow").secrets.map(func(s: Dictionary) -> String: return str(s.flag)), "hollow_nook_find")
	for id: String in MapData.all_ids():
		for s: Dictionary in MapData.load_map(id).signs:
			var e: Dictionary = Dialogue.get_entry(str(s.dialogue))
			var act: String = str(e.get("action", ""))
			if act.begins_with("give_item") and not s.has("show_flag"):
				fail_test("%s: sign %s still hands out an item; use a hidden find" % [id, s.dialogue])

func test_finds_give_only_items_from_the_item_list() -> void:
	# Item 1080: no premium currency or shop goods in hidden finds.
	for id: String in MapData.all_ids():
		for s: Dictionary in MapData.load_map(id).secrets:
			var it: Dictionary = Database.item(str(s.item))
			assert_false(it.is_empty(), "%s: %s" % [id, s.item])
			assert_false(bool(it.get("premium", false)) or bool(it.get("shop_only", false)), "%s: %s is a shop good" % [id, s.item])

func test_taken_finds_stop_glinting_and_count() -> void:
	var m: MapData = MapData.load_map("crowcrest")
	var total: int = m.secrets.size()
	var flags: Dictionary = {str(m.secrets[0].flag): true}
	assert_eq(m.secrets_found(flags), Vector2i(1, total))

func test_ground_picks_the_spawns() -> void:
	# Item 1109: Shalebat lives in Fernstair's scree, the others in its ferns.
	var scree: Array = EncounterTable.spawns_on("fernstair", "scree").map(func(s: Dictionary) -> String: return str(s.species))
	var fern: Array = EncounterTable.spawns_on("fernstair", "fern").map(func(s: Dictionary) -> String: return str(s.species))
	assert_eq(scree, ["Shalebat"])
	assert_false("Shalebat" in fern)
	assert_true("Zippit" in fern)
	assert_eq(EncounterTable.spawns_on("fernstair", "").size(), EncounterTable.table("fernstair").spawns.size())
	assert_eq(EncounterTable.grounds_for("fernstair", "Shalebat"), ["scree"] as Array[String])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in 20:
		assert_eq(EncounterTable.roll("fernstair", rng, [], "scree").data.species_name, "Shalebat")

func test_ground_of_a_cell() -> void:
	var fern: MapData = MapData.load_map("fernstair")
	assert_eq(EncounterTable.ground_at(fern, Vector2i(1, 1)), "fern")
	assert_eq(EncounterTable.ground_at(fern, Vector2i(10, 12)), "scree")
	var cave: MapData = MapData.load_map("murk_hollow")
	assert_eq(EncounterTable.ground_at(cave, Vector2i(1, 2)), "cave", "in a cave every ground is cave")

func test_quiet_steps_after_a_battle() -> void:
	# Item 1111.
	EncounterTable.start_guard()
	for i: int in EncounterTable.GUARD_STEPS:
		assert_false(EncounterTable.tick_guard(), "step %d stays quiet" % i)
	assert_true(EncounterTable.tick_guard())

func test_rates_fit_the_place() -> void:
	# Item 1110: routes 0.12, marsh and caves 0.10.
	assert_almost_eq(EncounterTable.rate("fernstair"), 0.12, 0.001)
	assert_almost_eq(EncounterTable.rate("saltmarsh"), 0.10, 0.001)
	assert_almost_eq(EncounterTable.rate("murk_hollow"), 0.10, 0.001)

func test_table_balance_check_catches_problems() -> void:
	var errors: PackedStringArray = []
	WorldValidator.check_table_balance(errors, MapData.all_ids())
	assert_eq(errors, PackedStringArray())
	var saved: Dictionary = EncounterTable._tables.duplicate(true)
	EncounterTable._tables["fernstair"]["spawns"] = [{"species": "Zippit", "min": 2, "max": 3, "weight": 10, "ground": "lava"}]
	EncounterTable._tables["fernstair"]["rate"] = 0.3
	WorldValidator.check_table_balance(errors, MapData.all_ids())
	EncounterTable._tables = saved
	assert_true(errors.size() >= 3, "\n".join(errors))

func test_tracker_shows_grounds_and_finds() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var menu := PauseMenu.new()
	menu.encounter_table = "fernstair"
	menu.current_map = "fernstair"
	var text: String = menu._tracker_text()
	menu.free()
	assert_string_contains(text, "scree")
	assert_string_contains(text, "Hidden finds here: 0/")

func test_overworld_loads_every_map() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		var cell := Vector2i(int(m.warps[0].x), int(m.warps[0].y)) if not m.warps.is_empty() else Vector2i(1, 1)
		ow.load_map(id, cell, "down")
		assert_eq(ow.map.id, id)
		var live: int = 0
		for s: Dictionary in m.secrets:
			if not GameState.has_flag(str(s.flag)):
				live += 1
		assert_eq(ow._world.glint_count(), live, "%s: one glint per hidden find" % id)
