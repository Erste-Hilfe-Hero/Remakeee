extends GutTest
## Tamer Gear: data is consistent, and spots are found from the right cell only.

func before_all() -> void:
	Database.load_all()

func test_gear_spots_are_well_formed() -> void:
	var count: int = 0
	for f: String in DirAccess.get_files_at("res://data/maps"):
		var m: MapData = MapData.load_map(f.get_basename())
		for g: Dictionary in m.gear_spots:
			count += 1
			var gear: String = str(g.gear)
			assert_true(bool(Database.item(gear).get("gear", false)), "%s: '%s' is not a gear item" % [m.id, gear])
			var target := Vector2i(int(g.x), int(g.y))
			if g.has("to"):
				var from := Vector2i(int(g.from[0]), int(g.from[1]))
				var to := Vector2i(int(g.to[0]), int(g.to[1]))
				assert_true(m.is_walkable(from), "%s: gear 'from' %s must be walkable" % [m.id, from])
				assert_true(m.is_walkable(to), "%s: gear 'to' %s must be walkable" % [m.id, to])
				assert_true(PathFinder.is_adjacent(from, target), "%s: target must be next to 'from'" % m.id)
				assert_false(m.is_walkable(target), "%s: a gear spot should cross something you can't walk" % m.id)
	assert_gt(count, 2)

func test_spot_lookup_needs_the_right_cell() -> void:
	var m: MapData = MapData.load_map("brindlewick")
	assert_false(m.gear_spot(Vector2i(5, 16), Vector2i(4, 16)).is_empty())
	assert_true(m.gear_spot(Vector2i(5, 15), Vector2i(4, 16)).is_empty())
	assert_eq(m.gear_needed_at(Vector2i(4, 16)), "")

func test_gear_is_given_somewhere() -> void:
	var given: Dictionary = {}
	for f: String in DirAccess.get_files_at("res://data/dialogue"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + f))
		for k: Variant in d:
			if d[k] is Dictionary and str(d[k].get("action", "")).begins_with("give_item "):
				given[str(d[k].action).split(" ")[1]] = true
	for f: String in DirAccess.get_files_at("res://data/maps"):
		for g: Dictionary in MapData.load_map(f.get_basename()).gear_spots:
			assert_true(given.has(str(g.gear)), "nobody gives '%s' but a map needs it" % g.gear)

func test_has_gear() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	assert_false(GameState.has_gear("grapple_line"))
	GameState.add_item("grapple_line")
	assert_true(GameState.has_gear("grapple_line"))
