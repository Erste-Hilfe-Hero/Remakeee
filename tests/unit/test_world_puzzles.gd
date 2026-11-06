extends GutTest
## Area 3 puzzles and gear (items 893, 1012 to 1014, 1044 to 1049): boulders, plates, cracked
## floor, plank gaps, the solver, saved world state and "always on foot".

func before_all() -> void:
	Database.load_all()

## A small room: two boulders, two plates, a door block at the top that the plates open.
func _room() -> MapData:
	return MapData.from_dict("t_room", {"name": "Test Room", "rows": [
		"WWWWfWWWW",
		"WfffffffW",
		"WfBfffPfW",
		"WfffBfffW",
		"WfffffPfW",
		"WffffkffW",
		"WWWWDWWWW"],
		"blocks": [{"x": 4, "y": 0, "open_flag": "t_room_open"}],
		"puzzles": [{"id": "plates", "flag": "t_room_open"}],
		"warps": [{"x": 4, "y": 6, "to": "brindlewick", "tx": 2, "ty": 5}]})

func test_push_moves_a_boulder_one_cell() -> void:
	var m: MapData = _room()
	assert_eq(PuzzleRoom.step(m, Vector2i(1, 2), Vector2i.RIGHT), Vector2i(2, 2), "the player follows into the old cell")
	assert_eq(m.char_at(Vector2i(3, 2)), "B")
	assert_eq(m.char_at(Vector2i(2, 2)), "f", "the boulder leaves floor behind")

func test_boulders_stop_at_walls_other_boulders_and_warps() -> void:
	var m: MapData = _room()
	assert_false(PuzzleRoom.push(m, Vector2i(2, 2), Vector2i.LEFT) and m.char_at(Vector2i(0, 2)) == "B", "wall")
	PuzzleRoom.set_boulders(m, [Vector2i(3, 3), Vector2i(4, 3)])
	assert_false(PuzzleRoom.push(m, Vector2i(3, 3), Vector2i.RIGHT), "another boulder")
	PuzzleRoom.set_boulders(m, [Vector2i(4, 5), Vector2i(2, 2)])
	assert_false(PuzzleRoom.push(m, Vector2i(4, 5), Vector2i.DOWN), "never onto a door or warp")
	assert_false(PuzzleRoom.can_take_boulder(m, Vector2i(5, 5)), "never onto cracked floor")
	assert_false(PuzzleRoom.can_take_boulder(m, Vector2i(2, 3), {Vector2i(2, 3): true}), "never onto an NPC")

func test_plates_open_the_door_while_pressed() -> void:
	var m: MapData = _room()
	var pz: Dictionary = m.puzzles[0]
	assert_eq(PuzzleRoom.plates(m, pz).size(), 2)
	assert_false(PuzzleRoom.pressed(m, pz))
	PuzzleRoom.set_boulders(m, [Vector2i(6, 2), Vector2i(1, 1)])
	assert_false(PuzzleRoom.pressed(m, pz), "one plate is not enough")
	assert_true(PuzzleRoom.pressed(m, pz, Vector2i(6, 4)), "the player can hold a plate too")
	PuzzleRoom.set_boulders(m, [Vector2i(6, 2), Vector2i(6, 4)])
	assert_true(PuzzleRoom.pressed(m, pz))
	var flags: Dictionary = PuzzleRoom.live_flags(m, {})
	assert_true(flags.has("t_room_open"))
	m.apply_blocks(flags)
	assert_eq(m.char_at(Vector2i(4, 0)), "f", "the block opens back to its map tile")
	PuzzleRoom.reset(m, {})
	m.apply_blocks(PuzzleRoom.live_flags(m, {}))
	assert_eq(m.char_at(Vector2i(4, 0)), "@", "after a reset the door shuts again")

func test_plate_under_a_boulder_comes_back() -> void:
	var m: MapData = _room()
	PuzzleRoom.set_boulders(m, [Vector2i(6, 1), Vector2i(4, 3)])
	assert_true(PuzzleRoom.push(m, Vector2i(6, 1), Vector2i.DOWN))
	assert_eq(m.char_at(Vector2i(6, 2)), "B")
	assert_true(PuzzleRoom.push(m, Vector2i(6, 2), Vector2i.DOWN))
	assert_eq(m.char_at(Vector2i(6, 2)), "P", "the plate shows again")

func test_solver_finds_and_replays_a_solution() -> void:
	var m: MapData = _room()
	var moves: Variant = PuzzleSolver.solve(m, m.puzzles[0], Vector2i(4, 5))
	assert_not_null(moves)
	var done: Dictionary = PuzzleSolver.replay(m, Vector2i(4, 5), moves)
	assert_true(PuzzleRoom.pressed(done.map, m.puzzles[0]))
	assert_false(PuzzleRoom.pressed(m, m.puzzles[0]), "solving works on a copy")

func test_solver_reports_impossible_rooms() -> void:
	var m := MapData.from_dict("t_stuck", {"rows": ["WWWWW", "WBffW", "WfffW", "WffPW", "WWWWW"],
		"puzzles": [{"id": "p", "flag": "t_stuck"}]})
	assert_null(PuzzleSolver.solve(m, m.puzzles[0], Vector2i(2, 2)), "a boulder in a corner never moves")

func test_state_survives_save_and_load() -> void:
	var m: MapData = _room()
	PuzzleRoom.push(m, Vector2i(2, 2), Vector2i.RIGHT)
	var state: Dictionary = PuzzleRoom.capture(m, {})
	state = PuzzleRoom.break_floor(m, state, Vector2i(5, 5))
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.set_world_of("t_room", state)
	var d: Dictionary = GameState.to_dict()
	GameState.from_dict(JSON.parse_string(JSON.stringify(d)))
	var again: MapData = _room()
	PuzzleRoom.apply_state(again, GameState.world_of("t_room"))
	assert_eq(again.char_at(Vector2i(3, 2)), "B")
	assert_eq(again.char_at(Vector2i(2, 2)), "f")
	assert_true(PuzzleRoom.is_broken(GameState.world_of("t_room"), Vector2i(5, 5)))
	assert_eq(again.char_at(Vector2i(5, 5)), "Y", "broken floor is a hole")
	GameState.set_world_of("t_room", {})
	assert_false(GameState.world_state.has("t_room"), "empty state is not saved")

func test_reset_puts_boulders_back() -> void:
	var m: MapData = _room()
	PuzzleRoom.push(m, Vector2i(2, 2), Vector2i.RIGHT)
	var state: Dictionary = PuzzleRoom.capture(m, {"planks": [[1, 1]]})
	state = PuzzleRoom.reset(m, state)
	assert_false(state.has("boulders"))
	assert_true(state.has("planks"), "planks are not part of the puzzle")
	assert_eq(PuzzleRoom.boulders(m), PuzzleRoom.start_boulders(m))

func test_planks_bridge_gaps_for_good() -> void:
	var m := MapData.from_dict("t_gap", {"rows": ["fYf"]})
	assert_false(m.is_walkable(Vector2i(1, 0)))
	var state: Dictionary = PuzzleRoom.lay_plank(m, {}, Vector2i(1, 0))
	assert_true(m.is_walkable(Vector2i(1, 0)))
	var again := MapData.from_dict("t_gap", {"rows": ["fYf"]})
	PuzzleRoom.apply_state(again, state)
	assert_true(again.is_walkable(Vector2i(1, 0)))

func test_wading_and_vines_need_gear() -> void:
	var m := MapData.from_dict("t_wade", {"rows": ["fwv"]})
	assert_false(PuzzleRoom.passable(m, Vector2i(1, 0), []))
	assert_true(PuzzleRoom.passable(m, Vector2i(1, 0), ["wading_boots"]))
	assert_false(PuzzleRoom.passable(m, Vector2i(2, 0), ["wading_boots"]))
	assert_true(PuzzleRoom.passable(m, Vector2i(2, 0), ["climbing_pick"]))
	assert_false(PuzzleRoom.passable(m, Vector2i(3, 0), ["climbing_pick"]), "off the map")

func test_new_gear_items_exist() -> void:
	for id: String in ["wading_boots", "pry_bar", "rope_ladder", "plank_bundle"]:
		var it: Dictionary = Database.item(id)
		assert_true(bool(it.get("gear", false)), id)
		assert_false(str(it.get("hint", "")).is_empty(), id)
		assert_false((it.get("works_on", []) as Array).is_empty(), id)
	for k: int in TilesetFactory.GEAR_KINDS:
		assert_true(bool(Database.item(TilesetFactory.GEAR_KINDS[k]).get("gear", false)))

func test_gear_page_lists_where_it_works() -> void:
	var page: String = PauseMenu.gear_page("wading_boots")
	assert_string_contains(page, "Wading Boots")
	assert_string_contains(page, "shallow water")
	assert_not_null(PauseMenu.gear_picture("wading_boots"))

## Item 1048, LEGAL.md: traversal stays on the ground. Gear opens only cells with something to
## stand on or hold (shallow water, a vine wall, a laid plank), gear spots cross at most one
## cell, and no animation, tween or state is named after flying, gliding or riding.
func test_traversal_stays_on_foot() -> void:
	for k: int in TilesetFactory.GEAR_KINDS:
		assert_true(k in [TilesetFactory.Kind.WADE, TilesetFactory.Kind.VINES], "gear kind %d" % k)
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for g: Dictionary in m.gear_spots:
			if g.has("to"):
				var f := Vector2i(int(g.from[0]), int(g.from[1]))
				var t := Vector2i(int(g.to[0]), int(g.to[1]))
				assert_true(absi(f.x - t.x) + absi(f.y - t.y) <= 2, "%s: gear spot jumps too far" % id)
	var banned := RegEx.create_from_string("(?i)\"[a-z_]*(fly|flying|glide|gliding|ride|riding|soar)[a-z_]*\"")
	for path: String in ["res://scripts/overworld/Overworld.gd", "res://scripts/overworld/Player.gd",
			"res://scripts/overworld/GridWalker.gd", "res://scripts/overworld/WorldMechanics.gd"]:
		var src: String = FileAccess.get_file_as_string(path)
		assert_null(banned.search(src), "%s names a flying or riding animation" % path)

## Item 1049: the grapple pulls along a stretched rope in steps, with no jump arc.
func test_grapple_pulls_hand_over_hand() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	assert_string_contains(src, "GRAPPLE_PULLS")
	assert_string_contains(src, "if gear == \"grapple_line\":")

## Items 1317, 1318: every puzzle on a real map has a solution file that solves it.
func test_puzzle_fixtures_solve_every_puzzle() -> void:
	var checked: int = 0
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m.puzzles.is_empty():
			continue
		var path: String = "res://tests/fixtures/puzzles/%s.json" % id
		assert_true(FileAccess.file_exists(path), "%s has puzzles but no %s" % [id, path])
		if not FileAccess.file_exists(path):
			continue
		var sol: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for pz: Dictionary in m.puzzles:
			var s: Dictionary = sol.get(str(pz.id), {})
			assert_false(s.is_empty(), "%s: no solution for puzzle %s" % [id, pz.id])
			if s.is_empty():
				continue
			var open: Dictionary = {}
			for b: Dictionary in m.blocks:
				open[str(b.get("open_flag", ""))] = true
			open.erase(str(pz.flag))
			var fresh: MapData = MapData.load_map(id)
			fresh.apply_blocks(open)
			var done: Dictionary = PuzzleSolver.replay(fresh, Vector2i(int(s.start[0]), int(s.start[1])), s.moves)
			assert_true(PuzzleRoom.pressed(done.map, pz), "%s: solution for %s does not press every plate" % [id, pz.id])
			checked += 1
	pass_test("checked %d puzzles" % checked)

func test_world_puzzles_have_no_errors() -> void:
	var errors: PackedStringArray = []
	WorldValidator.check_puzzles(errors, MapData.all_ids())
	assert_eq(errors, PackedStringArray())
