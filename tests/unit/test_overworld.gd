extends GutTest
## Maps, encounters and dialogue (pure parts of the overworld).

func before_all() -> void:
	Database.load_all()

func test_world_data_is_consistent() -> void:
	var errors: PackedStringArray = WorldValidator.validate()
	assert_eq(errors.size(), 0, "World errors:\n" + "\n".join(errors))

func test_map_walkability_and_warps() -> void:
	var town: MapData = MapData.load_map("start_town")
	assert_false(town.is_walkable(Vector2i(0, 0)), "trees block")
	assert_true(town.is_walkable(Vector2i(8, 1)), "path is open")
	assert_false(town.is_walkable(Vector2i(-1, 3)), "outside the map blocks")
	assert_eq(str(town.warp_at(Vector2i(3, 4)).to), "home")
	assert_true(town.warp_at(Vector2i(5, 5)).is_empty())

func test_tall_grass_on_route() -> void:
	var route: MapData = MapData.load_map("route_1")
	assert_eq(route.kind_at(Vector2i(1, 1)), TilesetFactory.Kind.TALL_GRASS)
	assert_eq(route.encounter_table, "route_1")

func test_encounter_roll_is_seeded_and_in_range() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 5
	var b := RandomNumberGenerator.new()
	b.seed = 5
	for i: int in 20:
		var x: Spirling = EncounterTable.roll("route_1", a)
		var y: Spirling = EncounterTable.roll("route_1", b)
		assert_eq(x.data.species_name, y.data.species_name)
		assert_eq(x.level, y.level)
		assert_true(x.data.species_name in EncounterTable.species_on("route_1"))
		assert_between(x.level, 2, 5)

func test_dialogue_after_flag_variant() -> void:
	var entry: Dictionary = Dialogue.get_entry("home/mom")
	var before: Array[String] = Dialogue.lines_for(entry, {})
	var after: Array[String] = Dialogue.lines_for(entry, {"mom_gift": true})
	assert_ne(before, after)

func test_tileset_has_one_tile_per_kind() -> void:
	var ts: TileSet = TilesetFactory.get_tileset()
	var src: TileSetAtlasSource = ts.get_source(0)
	assert_eq(src.get_tiles_count(), TilesetFactory.Kind.size())
