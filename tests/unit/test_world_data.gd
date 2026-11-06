extends GutTest
## Area 3 "world data and tools" (items 890 to 896): new tile characters, hidden finds,
## floors in one map file, encounter table checks and the world layout.

func before_all() -> void:
	Database.load_all()

func test_new_tile_characters_are_in_the_legend() -> void:
	var want: Dictionary = {"w": TilesetFactory.Kind.WADE, "B": TilesetFactory.Kind.BOULDER,
		"P": TilesetFactory.Kind.PLATE, "k": TilesetFactory.Kind.CRACKED,
		"v": TilesetFactory.Kind.VINES, "Y": TilesetFactory.Kind.PLANK}
	for ch: String in want:
		assert_eq(TilesetFactory.kind_for(ch), want[ch], ch)
		assert_true(TilesetFactory.COLORS.has(want[ch]), "fallback colour for %s" % ch)
	assert_false(TilesetFactory.is_solid(TilesetFactory.Kind.PLATE), "plates are walked on")
	assert_false(TilesetFactory.is_solid(TilesetFactory.Kind.CRACKED), "cracked floor holds one step")
	assert_true(TilesetFactory.is_solid(TilesetFactory.Kind.BOULDER))
	for k: int in TilesetFactory.GEAR_KINDS:
		assert_true(TilesetFactory.is_solid(k), "without gear %d stays closed" % k)

func test_atlas_has_a_column_for_every_kind() -> void:
	var tex: Texture2D = load(TilesetFactory.ATLAS_PATH)
	assert_eq(tex.get_width(), TilesetFactory.TILE * TilesetFactory.Kind.size())

func test_gear_kinds_name_real_gear_or_planned_gear() -> void:
	for k: int in TilesetFactory.GEAR_KINDS:
		assert_false(TilesetFactory.GEAR_KINDS[k].is_empty())

func _cave() -> Dictionary:
	return {"name": "Test Cave", "region": "veydal", "encounters": "murk_hollow", "backdrop": "ridge",
		"rows": ["@@@", "@.@", "@=@"],
		"secrets": [{"x": 1, "y": 1, "item": "tonic", "count": 2, "flag": "t_find"}],
		"floors": [{"name": "Test Cave, Level 2", "rows": ["@@@@", "@..@", "@@@@"]},
			{"rows": ["@@", "@@"], "encounters": ""}]}

func test_floors_load_from_one_file() -> void:
	var top: MapData = MapData.from_dict("cave", _cave())
	assert_eq(top.floor_count, 3)
	assert_eq(top.floor_index, 0)
	var two: MapData = MapData.from_dict("cave@1", _cave())
	assert_eq(two.width, 4)
	assert_eq(two.display_name, "Test Cave, Level 2")
	assert_eq(two.encounter_table, "murk_hollow", "a floor inherits the table")
	assert_eq(two.backdrop, "ridge")
	assert_eq(two.file_id, "cave")
	var three: MapData = MapData.from_dict("cave@2", _cave())
	assert_eq(three.display_name, "Test Cave", "a floor without a name uses the file's")
	assert_eq(three.encounter_table, "", "a floor can switch the table off")
	assert_eq(MapData.split_id("cave@2"), ["cave", 2])
	assert_eq(MapData.split_id("cave"), ["cave", 0])
	assert_eq(MapData.floor_id("cave", 0), "cave")
	assert_eq(MapData.floor_id("cave", 3), "cave@3")

func test_missing_floor_is_null() -> void:
	assert_null(MapData.from_dict("cave@5", _cave()))
	assert_push_error("no floor")

func test_secrets_can_be_taken_once() -> void:
	var m: MapData = MapData.from_dict("cave", _cave())
	assert_false(m.secret_at(Vector2i(1, 1)).is_empty())
	assert_true(m.secret_at(Vector2i(0, 0)).is_empty())
	assert_eq(m.secrets_found({}), Vector2i(0, 1))
	var flags: Dictionary = {"t_find": true}
	assert_true(m.secret_at(Vector2i(1, 1), flags).is_empty(), "taken finds are gone")
	assert_eq(m.secrets_found(flags), Vector2i(1, 1))

func test_all_ids_lists_every_map_file() -> void:
	var ids: PackedStringArray = MapData.all_ids()
	assert_true("brindlewick" in ids)
	for id: String in ids:
		assert_true(MapData.exists(id), id)

func test_world_data_has_no_errors() -> void:
	var errors: PackedStringArray = []
	var ids: PackedStringArray = MapData.all_ids()
	WorldValidator.check_encounter_tables(errors, ids)
	WorldValidator.check_secrets(errors, ids)
	WorldValidator.check_layout(errors, ids, WorldValidator.load_layout())
	assert_eq(errors, PackedStringArray())

func test_layout_check_finds_missing_edges() -> void:
	var layout: Dictionary = WorldValidator.load_layout().duplicate(true)
	(layout.maps.fernstair as Dictionary).neighbours = ["crowcrest"]
	(layout.maps.brindlewick as Dictionary).neighbours = ["saltmarsh"]
	var errors: PackedStringArray = []
	WorldValidator.check_layout(errors, MapData.all_ids(), layout)
	assert_true(errors.size() >= 1)
	assert_string_contains(errors[0], "not an edge")

func test_layout_check_finds_maps_without_a_place() -> void:
	var layout: Dictionary = WorldValidator.load_layout().duplicate(true)
	(layout.maps as Dictionary).erase("map_house")
	var errors: PackedStringArray = []
	WorldValidator.check_layout(errors, MapData.all_ids(), layout)
	assert_true("world layout: map 'map_house' has no place" in errors)

func test_interiors_count_as_their_town() -> void:
	var places: Dictionary = WorldValidator.load_layout().maps
	assert_eq(WorldValidator.layout_place(places, "lighthouse"), "brindlewick")
	assert_eq(WorldValidator.layout_place(places, "fernstair"), "fernstair")
	assert_eq(WorldValidator.layout_edge("b", "a"), "a-b")
