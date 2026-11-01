extends GutTest
## Maps, encounters and dialogue (pure parts of the overworld).

func before_all() -> void:
	Database.load_all()

func test_world_data_is_consistent() -> void:
	var errors: PackedStringArray = WorldValidator.validate()
	assert_eq(errors.size(), 0, "World errors:\n" + "\n".join(errors))

func test_map_walkability_and_warps() -> void:
	var town: MapData = MapData.load_map("brindlewick")
	assert_false(town.is_walkable(Vector2i(0, 0)), "trees block")
	assert_true(town.is_walkable(Vector2i(5, 1)), "path is open")
	assert_false(town.is_walkable(Vector2i(-1, 3)), "outside the map blocks")
	assert_true(town.is_walkable(Vector2i(5, 15)), "the pier crosses the lake")
	assert_false(town.is_walkable(Vector2i(0, 15)), "open water blocks")
	assert_eq(str(town.warp_at(Vector2i(3, 11)).to), "lighthouse")
	assert_true(town.warp_at(Vector2i(5, 5)).is_empty())

func test_hub_reaches_both_paths() -> void:
	var town: MapData = MapData.load_map("brindlewick")
	var targets: Array[String] = []
	for w: Dictionary in town.warps:
		targets.append(str(w.to))
	assert_has(targets, "fernstair")
	assert_has(targets, "saltmarsh")

func test_terraces_and_new_encounter_ground() -> void:
	var path: MapData = MapData.load_map("fernstair")
	assert_false(path.is_walkable(Vector2i(2, 3)), "cliffs block")
	assert_true(path.is_walkable(Vector2i(8, 3)), "stairs climb the terrace")
	assert_true(TilesetFactory.Kind.REEDS in TilesetFactory.ENCOUNTER_KINDS)
	assert_true(TilesetFactory.Kind.SCREE in TilesetFactory.ENCOUNTER_KINDS)

func test_tall_grass_on_route() -> void:
	var route: MapData = MapData.load_map("fernstair")
	assert_eq(route.kind_at(Vector2i(1, 1)), TilesetFactory.Kind.TALL_GRASS)
	assert_eq(route.encounter_table, "fernstair")

func test_encounter_roll_is_seeded_and_in_range() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 5
	var b := RandomNumberGenerator.new()
	b.seed = 5
	for i: int in 20:
		var x: Spirling = EncounterTable.roll("fernstair", a)
		var y: Spirling = EncounterTable.roll("fernstair", b)
		assert_eq(x.data.species_name, y.data.species_name)
		assert_eq(x.level, y.level)
		assert_true(x.data.species_name in EncounterTable.species_on("fernstair"))
		assert_between(x.level, 2, 5)

func test_dialogue_after_flag_variant() -> void:
	var entry: Dictionary = Dialogue.get_entry("lighthouse/aldo")
	var before: Array[String] = Dialogue.lines_for(entry, {})
	var after: Array[String] = Dialogue.lines_for(entry, {"aldo_gift": true})
	assert_ne(before, after)

func test_tileset_has_every_kind_and_variant() -> void:
	var ts: TileSet = TilesetFactory.get_tileset()
	var src: TileSetAtlasSource = ts.get_source(0)
	assert_eq(src.get_tiles_count(), TilesetFactory.Kind.size() * TilesetFactory.VARIANT_ROWS)

func test_masked_tiles_pick_edges_from_neighbours() -> void:
	TilesetFactory.get_tileset()
	var all_water: Callable = func(_c: Vector2i) -> int: return TilesetFactory.Kind.WATER
	var all_grass: Callable = func(_c: Vector2i) -> int: return TilesetFactory.Kind.GRASS
	var w: int = TilesetFactory.Kind.WATER
	assert_eq(TilesetFactory.atlas_coords(w, Vector2i.ZERO, all_water), Vector2i(w, 15), "open water")
	assert_eq(TilesetFactory.atlas_coords(w, Vector2i.ZERO, all_grass), Vector2i(w, 0), "pond with shore all round")
