extends GutTest
## Area 3 item 1031: every puzzle room names its goal in one line on the first visit.

const DUNGEONS: Array[String] = ["bellstone_ruins", "brackwater_sluice", "lanternwell", "shatterfloor_mine"]

func before_all() -> void:
	Database.load_all()

func test_every_puzzle_room_has_a_goal_line() -> void:
	for file: String in DUNGEONS:
		var top: MapData = MapData.load_map(file)
		var with_goal: int = 0
		for i: int in top.floor_count:
			var m: MapData = MapData.load_map(MapData.floor_id(file, i))
			var puzzle: bool = not m.beam.is_empty() or not m.sluices.is_empty() or m.blocks.any(
				func(b: Dictionary) -> bool: return not str(b.get("open_flag", "")).begins_with("_"))
			if puzzle:
				assert_false(m.goal.is_empty(), "%s room %d has a goal" % [file, i + 1])
			if not m.goal.is_empty():
				with_goal += 1
				assert_true(m.goal.begins_with("Goal: "), m.goal)
				assert_ne(Loc.t(m.goal), "", m.goal)
		assert_gt(with_goal, 0, file)

func test_goal_lines_do_not_carry_over_to_plain_floors() -> void:
	assert_eq(MapData.load_map("shatterfloor_mine@1").goal, "")
	assert_eq(MapData.load_map("bellstone_ruins@4").goal, "")

func test_goal_flag_is_one_per_room() -> void:
	assert_ne(Overworld.goal_flag("lanternwell"), Overworld.goal_flag("lanternwell@1"))
	assert_false(Overworld.goal_flag("lanternwell@1").contains(MapData.FLOOR_SEP))

func test_puzzle_rooms_keep_wild_cells_on_the_landing_only() -> void:
	var errors := PackedStringArray()
	WorldValidator.check_room_encounters(errors, MapData.all_ids())
	assert_eq(errors, PackedStringArray())
	var any_wild: bool = false
	for file: String in DUNGEONS:
		var top: MapData = MapData.load_map(file)
		for i: int in top.floor_count:
			var m: MapData = MapData.load_map(MapData.floor_id(file, i))
			if not m.goal.is_empty():
				for c: Vector2i in WorldValidator.wild_cells(m):
					any_wild = true
					assert_eq(c.y, m.height - 2, "%s %s" % [m.id, c])
	assert_true(any_wild, "the landings still have wild cells")

func test_validator_catches_wild_cells_inside_a_puzzle() -> void:
	var m: MapData = MapData.load_map("lanternwell@1")
	var errors := PackedStringArray()
	m.rows[2] = m.rows[2].substr(0, 3) + ":" + m.rows[2].substr(4)
	for c: Vector2i in WorldValidator.wild_cells(m):
		if c.y != m.height - 2:
			errors.append(str(c))
	assert_eq(errors.size(), 1)
