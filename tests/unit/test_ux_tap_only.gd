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
