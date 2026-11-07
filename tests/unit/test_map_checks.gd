extends GutTest
## CI map checks (item 99): every warp, NPC, sign, gear spot and rest point is reachable,
## and every map can be reached from the start and left again.

func before_all() -> void:
	Database.load_all()

func _ids() -> PackedStringArray:
	return MapData.all_ids()

func test_world_is_fully_reachable() -> void:
	var errors: PackedStringArray = []
	WorldValidator.check_reachability(errors, _ids())
	assert_eq(errors, PackedStringArray())

func _box_map() -> MapData:
	var m := MapData.new()
	m.id = "test_box"
	m.rows = PackedStringArray(["TTTTTT", "T....T", "T.TTTT", "T.T..T", "TTTTTT"])
	m.height = m.rows.size()
	m.width = 6
	m._base_rows = m.rows.duplicate()
	return m

func test_walled_in_cells_are_not_reached() -> void:
	var m: MapData = _box_map()
	var reach: Dictionary = WorldValidator.reachable_cells(m, [Vector2i(1, 1)])
	assert_true(reach.has(Vector2i(4, 1)))
	assert_true(reach.has(Vector2i(1, 3)))
	assert_false(reach.has(Vector2i(3, 3)), "the pocket at the bottom right is sealed")

func test_npcs_block_the_way() -> void:
	var m: MapData = _box_map()
	m.npcs.append({"id": "guard", "x": 1, "y": 2})
	var reach: Dictionary = WorldValidator.reachable_cells(m, [Vector2i(1, 1)])
	assert_false(reach.has(Vector2i(1, 3)))

func test_gear_spots_bridge_gaps() -> void:
	var m: MapData = _box_map()
	m.gear_spots.append({"from": [4, 1], "x": 4, "y": 2, "gear": "climbing_pick", "to": [4, 3]})
	var reach: Dictionary = WorldValidator.reachable_cells(m, [Vector2i(1, 1)])
	assert_true(reach.has(Vector2i(4, 3)))
	assert_true(reach.has(Vector2i(3, 3)))

func test_ferry_sign_is_reachable() -> void:
	var m: MapData = MapData.load_map("brindlewick")
	var reach: Dictionary = WorldValidator.reachable_cells(m, [Vector2i(5, 1)])
	assert_true(reach.has(Vector2i(8, 18)), "the fisher no longer stands in front of the ferry sign")
