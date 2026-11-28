extends GutTest
## Area 3 caves (items 978 to 983): Mossmere Grotto, Sablecove, Echo Gallery, Kindle Vents.

const CAVES: Array[String] = ["mossmere_grotto", "sablecove", "murk_hollow@1", "kindle_vents"]
const ENTRANCES: Dictionary = {"gloamwood": "mossmere_grotto", "brackwater_fen": "sablecove",
	"crowcrest": "murk_hollow", "cinder_rift": "kindle_vents"}

var ow: Overworld

func before_all() -> void:
	Database.load_all()

func _overworld() -> Overworld:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var o: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(o)
	await wait_process_frames(2)
	return o

func _arrive(o: Overworld, id: String) -> void:
	var m: MapData = MapData.load_map(id)
	o.load_map(id, Vector2i(int(m.warps[0].x), int(m.warps[0].y)), "up")

func test_caves_are_caves_with_tables() -> void:
	for id: String in CAVES:
		var m: MapData = MapData.load_map(id)
		assert_not_null(m, id)
		assert_eq(m.biome, "cave", id)
		assert_false(EncounterTable.table(m.encounter_table).is_empty(), id)

func test_entrance_signs_show_the_gear() -> void:
	# Item 982.
	for outside: String in ENTRANCES:
		var m: MapData = MapData.load_map(outside)
		var found: bool = false
		for s: Dictionary in m.signs:
			if str(s.dialogue).ends_with(ENTRANCES[outside] + "_sign"):
				found = true
				assert_gt((s.get("gear", []) as Array).size(), 0, outside)
				for g: Variant in s.gear:
					assert_false(Database.item(str(g)).is_empty(), str(g))
		assert_true(found, "%s has a sign at the cave door" % outside)

func test_gear_icons_above_the_text() -> void:
	ow = await _overworld()
	var icons: Control = ow._gear_icons(["wading_boots", "plank_bundle"])
	assert_not_null(icons)
	assert_eq(icons.get_child_count(), 2)
	icons.queue_free()
	assert_null(ow._gear_icons([]))

func test_deep_levels_have_a_rope_back() -> void:
	# Item 983: the rope is a block on a warp to the top level, opened by a lever inside.
	for id: String in ["mossmere_grotto@1", "murk_hollow@1"]:
		var m: MapData = MapData.load_map(id)
		var rope: bool = false
		for b: Dictionary in m.blocks:
			var w: Dictionary = m.warp_at(Vector2i(int(b.x), int(b.y)))
			if not w.is_empty() and MapData.split_id(str(w.to))[1] == 0:
				rope = true
				var lever: bool = false
				for s: Dictionary in m.signs:
					lever = lever or str(Dialogue.get_entry(str(s.dialogue)).get("action", "")) == "lever " + str(b.open_flag)
				assert_true(lever, "%s: a lever without gear lets the rope down" % id)
		assert_true(rope, id)

func test_low_tide_hours() -> void:
	assert_true(WorldMechanics.low_tide(3))
	assert_false(WorldMechanics.low_tide(8))
	assert_true(WorldMechanics.low_tide(14))
	assert_false(WorldMechanics.low_tide(23))

func test_sablecove_inner_chamber_opens_at_low_tide() -> void:
	# Item 979.
	ow = await _overworld()
	ow._world.hour_override = 8
	_arrive(ow, "sablecove")
	assert_eq(ow.map.char_at(Vector2i(6, 3)), "~", "flooded at high tide")
	ow._world.hour_override = 3
	_arrive(ow, "sablecove")
	assert_eq(ow.map.char_at(Vector2i(6, 3)), ".", "dry at low tide")

func test_vents_blow_on_a_beat_but_not_under_the_player() -> void:
	# Item 981.
	ow = await _overworld()
	_arrive(ow, "kindle_vents")
	var vent := Vector2i(5, 7)
	assert_eq(ow.map.char_at(vent), "_", "calm on arrival")
	ow._world.vent_tick()
	assert_eq(ow.map.char_at(vent), "@", "blowing")
	ow._world.vent_tick()
	assert_eq(ow.map.char_at(vent), "_", "calm again")
	ow.player.place(vent, "up")
	ow._world.vent_tick()
	assert_eq(ow.map.char_at(vent), "_", "waits while the player stands in it")
	assert_eq(WorldMechanics.VENT_HALF * 2, 4.0)
