extends GutTest
## Item 2109: everything outside battle works with taps alone. A tap on a sign, counter,
## hidden find, smooth rock passage, ladder anchor or plank gap walks next to it and uses it.

func before_all() -> void:
	Database.load_all()

func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Dictionary in list:
		out.append(Vector2i(int(d.x), int(d.y)))
	return out

func test_every_usable_cell_is_used_on_arrival() -> void:
	var checked: int = 0
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		var cells: Array[Vector2i] = []
		cells.append_array(_cells(m.secrets))
		cells.append_array(_cells(m.ladders))
		cells.append_array(_cells(m.passages))
		for s: Dictionary in m.signs:
			if not s.has("show_flag"):
				cells.append(Vector2i(int(s.x), int(s.y)))
		for y: int in m.height:
			for x: int in m.rows[y].length():
				var k: int = m.kind_at(Vector2i(x, y))
				if k == TilesetFactory.Kind.COUNTER or k == TilesetFactory.Kind.PLANK:
					cells.append(Vector2i(x, y))
		for c: Vector2i in cells:
			checked += 1
			assert_true(Overworld.used_on_arrival(m, c, {}), "%s %s can be used with a tap" % [id, c])
	assert_gt(checked, 20, "the maps have usable spots to check")

func test_plain_ground_is_only_walked_to() -> void:
	var town: MapData = MapData.load_map("brindlewick")
	assert_false(Overworld.used_on_arrival(town, Vector2i(5, 1), {}), "a path cell is a walk target")

func test_taken_find_is_no_longer_used() -> void:
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for sc: Dictionary in m.secrets:
			var c := Vector2i(int(sc.x), int(sc.y))
			if m.sign_at(c).is_empty() and m.ladder_at(c).is_empty() and m.passage_at(c).is_empty():
				var k: int = m.kind_at(c)
				if k != TilesetFactory.Kind.COUNTER and k != TilesetFactory.Kind.PLANK:
					assert_false(Overworld.used_on_arrival(m, c, {str(sc.flag): true}))
					return
	pass_test("no hidden finds on any map")

func _overworld() -> Overworld:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	ow.load_map("brindlewick", Vector2i(5, 1), "down")
	ow.player.place(Vector2i(5, 1), "down")
	return ow

func _walkable_near(ow: Overworld, from: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i(0, 2), Vector2i(0, 3), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(3, 0), Vector2i(-3, 0)]:
		var c: Vector2i = from + d
		if ow.map.is_walkable(c) and ow.npc_at(c) == null:
			return c
	return Vector2i(-1, -1)

func test_tap_marks_the_target_with_a_frame() -> void:
	var ow: Overworld = await _overworld()
	var goal: Vector2i = _walkable_near(ow, ow.player.cell)
	assert_ne(goal, Vector2i(-1, -1), "a walkable cell near the start")
	ow.tap_cell(goal)
	var mk: TapMarker = ow._entities.get_node_or_null("tap_marker")
	assert_not_null(mk, "item 1812: the target blinks")
	assert_false(mk.cross)
	assert_false(ow.player.path.is_empty())
	assert_eq(mk.position, GridWalker.cell_to_pos(goal))

func test_unreachable_tap_shows_a_cross() -> void:
	var ow: Overworld = await _overworld()
	ow.tap_cell(Vector2i(0, 15))
	var mk: TapMarker = ow._entities.get_node_or_null("tap_marker")
	assert_not_null(mk)
	assert_true(mk.cross, "item 1813: open water gets an X")
	assert_true(ow.player.path.is_empty())
	await wait_seconds(Overworld.TAP_MARKER_TIME + 0.15)
	assert_false(is_instance_valid(mk), "the mark goes away by itself")

func test_new_tap_while_walking_plans_from_the_next_cell() -> void:
	var ow: Overworld = await _overworld()
	var first: Vector2i = _walkable_near(ow, ow.player.cell)
	ow.tap_cell(first)
	await wait_process_frames(2)
	assert_true(ow.player.moving, "the walk started")
	var second: Vector2i = _walkable_near(ow, ow.player.cell)
	ow.tap_cell(second)
	assert_eq(ow._tap_goal, second)
	if not ow.player.path.is_empty():
		assert_true(PathFinder.is_adjacent(ow.player.path[0], ow.player.cell), "item 1814: the new way starts right after the current step")
