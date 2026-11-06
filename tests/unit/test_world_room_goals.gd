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
