extends GutTest
## Area 3 puzzle dungeons (items 1008 to 1011, 1317): each room is solved with its test solution.

func before_all() -> void:
	Database.load_all()

func _overworld() -> Overworld:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var o: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(o)
	await wait_process_frames(2)
	return o

func _enter(o: Overworld, id: String) -> void:
	o.load_map(id, Vector2i(5, 5), "up")

func _rooms(file: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in MapData.all_ids():
		if str(MapData.split_id(id)[0]) == file:
			out.append(id)
	return out

func test_dungeon_room_counts() -> void:
	assert_eq(_rooms("bellstone_ruins").size(), 5)
	assert_eq(_rooms("brackwater_sluice").size(), 6)
	assert_eq(_rooms("lanternwell").size(), 5)
	assert_eq(_rooms("shatterfloor_mine").size(), 2)

func test_bells_in_the_wall_order_open_the_door() -> void:
	# Item 1008: the wall text names the bells in order; ringing them so sets the room flag.
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	for id: String in _rooms("bellstone_ruins"):
		var m: MapData = MapData.load_map(id)
		var steps: Dictionary = {}
		var puzzle: String = ""
		var total: int = 0
		for s: Dictionary in m.signs:
			var act: PackedStringArray = str(Dialogue.get_entry(str(s.dialogue)).get("action", "")).split(" ")
			if act[0] == "bell":
				puzzle = act[1]
				total = int(act[3])
				steps[int(act[2])] = true
		assert_eq(steps.size(), total, id)
		assert_eq(GameState.press_switch(puzzle, 2, total), GameState.SwitchResult.WRONG, "wrong bell first")
		for n: int in range(1, total + 1):
			GameState.press_switch(puzzle, n, total)
		assert_true(GameState.has_flag(puzzle), id)
		for b: Dictionary in m.blocks:
			assert_eq(str(b.open_flag), puzzle)

func test_sluice_wheels_raise_the_water() -> void:
	# Item 1009.
	var ow: Overworld = await _overworld()
	_enter(ow, "brackwater_sluice")
	assert_eq(ow._world.water_level(ow.map), 0)
	assert_eq(ow.map.char_at(Vector2i(5, 2)), "~", "pontoon sits low at mark 0")
	GameState.set_flag("sluice_a")
	ow._world.refresh(ow.player.cell)
	assert_eq(ow._world.water_level(ow.map), 1)
	assert_eq(ow.map.char_at(Vector2i(5, 2)), "+", "pontoon floats up at mark 1")
	_enter(ow, "brackwater_sluice@1")
	assert_eq(ow.map.char_at(Vector2i(5, 2)), "+", "low pier dry at mark 1")
	GameState.set_flag("sluice_b")
	ow._world.refresh(ow.player.cell)
	assert_eq(ow.map.char_at(Vector2i(5, 2)), "~", "low pier floods at mark 2")

func test_sluice_can_be_crossed_in_order() -> void:
	var open: Dictionary = {}
	var rooms: Array[String] = _rooms("brackwater_sluice")
	var set: Dictionary = {}
	for id: String in rooms:
		var m: MapData = MapData.load_map(id)
		for s: Dictionary in m.signs:
			var act: String = str(Dialogue.get_entry(str(s.dialogue)).get("action", ""))
			if act.begins_with("toggle "):
				set[act.get_slice(" ", 1)] = true
		var f: Dictionary = set.duplicate()
		var level: int = 0
		for k: Variant in m.sluices:
			if f.has(k):
				level += 1
		WorldMechanics.water_flags(level, f)
		for b: Dictionary in m.blocks:
			assert_true(f.has(str(b.open_flag)), "%s passable going forward at mark %d" % [id, level])
	assert_eq(set.size(), 3)

func test_mirrors_light_every_crystal() -> void:
	# Item 1010: the start is wrong; turning the path mirrors lights the crystal.
	var ow: Overworld = await _overworld()
	for id: String in _rooms("lanternwell"):
		_enter(ow, id)
		var m: MapData = ow.map
		assert_false(WorldMechanics.beam_hits(m, ow._world.mirrors(m)), "%s starts dark" % id)
		var solved: bool = false
		for mm: Variant in m.beam.mirrors:
			if ow._world.turn_mirror(Vector2i(int(mm[0]), int(mm[1]))):
				solved = true
				break
			if WorldMechanics.beam_hits(m, ow._world.mirrors(m)):
				solved = true
				break
		if not solved:
			# Brute force like the validator, then check the flag is set by the last turn.
			var cells: Array = m.beam.mirrors.map(func(v: Array) -> Vector2i: return Vector2i(int(v[0]), int(v[1])))
			for bits: int in 1 << cells.size():
				var ways: Dictionary = {}
				for i: int in cells.size():
					ways[cells[i]] = "\\" if bits & (1 << i) else "/"
				if WorldMechanics.beam_hits(m, ways):
					solved = true
					break
		assert_true(solved, id)
		assert_gt(ow._world.beam_points(), 1, "%s draws the beam" % id)

func test_one_turn_lights_the_first_chamber() -> void:
	var ow: Overworld = await _overworld()
	_enter(ow, "lanternwell")
	var mm: Array = ow.map.beam.mirrors[0]
	assert_true(ow._world.turn_mirror(Vector2i(int(mm[0]), int(mm[1]))))
	assert_true(GameState.has_flag(str(ow.map.beam.flag)))
	assert_ne(ow.map.char_at(Vector2i(5, 0)), "@", "the stair door opened")

func test_shatterfloor_drops_to_the_gallery() -> void:
	# Item 1011.
	var top: MapData = MapData.load_map("shatterfloor_mine")
	assert_eq(top.drop_to, "shatterfloor_mine@1")
	var below: MapData = MapData.load_map(top.drop_to)
	var cracked: int = 0
	for y: int in top.height:
		for x: int in top.width:
			if top.kind_at(Vector2i(x, y)) == TilesetFactory.Kind.CRACKED:
				cracked += 1
				assert_true(below.is_walkable(Vector2i(x, y)), "lands on floor at %d,%d" % [x, y])
	assert_gt(cracked, 10)
	var ups: Array = below.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == "shatterfloor_mine")
	assert_eq(ups.size(), 1, "a ladder leads back up")
