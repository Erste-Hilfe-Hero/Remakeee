extends GutTest
## Area 3 Lake Line, Valley Coach and the Corvane ferry (items 1187-1191, 1287-1290).

func before_all() -> void:
	Database.load_all()

func test_lines_and_stops() -> void:
	# Items 1187, 1189: the routes and their stops.
	assert_eq(Transit.stops("lake_line"), ["brindlewick", "reedhaven", "quillbrook"] as Array[String])
	assert_eq(Transit.stops("valley_coach"), ["brindlewick", "thornridge", "copperfold", "wrenhollow"] as Array[String])
	assert_eq(str(Transit.line("lake_line").kind), "boat")
	assert_eq(str(Transit.line("valley_coach").kind), "coach")
	assert_true(Transit.is_stop("reedhaven"))
	assert_false(Transit.is_stop("crowcrest"))
	var at: Dictionary = Transit.arrival("valley_coach", "copperfold")
	assert_eq(at.cell, Vector2i(9, 17))
	assert_eq(at.facing, "right")

func test_stops_open_on_foot_only() -> void:
	# Item 1190: a stop opens once its map was reached on foot (flag stop_<map>).
	var flags: Dictionary = {}
	assert_true(Transit.open_stops("lake_line", "brindlewick", flags).is_empty())
	flags[Transit.stop_flag("reedhaven")] = true
	assert_eq(Transit.open_stops("lake_line", "brindlewick", flags), ["reedhaven"] as Array[String])
	assert_true(Transit.open_stops("lake_line", "reedhaven", flags).is_empty(), "never offers the stop you stand on")
	# A rest spot used there before the routes existed counts too.
	assert_eq(Transit.open_stops("valley_coach", "brindlewick", {}, {"copperfold": [3, 8]}), ["copperfold"] as Array[String])

func test_corvane_quay() -> void:
	# Items 1287, 1288: the arrival harbour in its own region, 12 x 24, with a rest spot.
	var m: MapData = MapData.load_map("corvane_quay")
	assert_not_null(m)
	assert_eq(m.region, "corvane")
	assert_eq(Vector2i(m.width, m.height), Vector2i(12, 24))
	assert_true(m.heal_point.x >= 0)
	assert_true(m.is_walkable(Vector2i(6, 22)), "the ferry lands on the pier")
	assert_true(m.spots.has("juna") and m.spots.has("page_7"))
	var counts: Dictionary = WorldValidator.region_counts(MapData.all_ids())
	assert_gt(int(counts.corvane), 0, "Corvane maps are counted on their own")
	assert_gt(int(counts.veydal), int(counts.corvane))
	# The road north is shut until the flag opens it.
	m.apply_blocks({})
	assert_false(m.is_walkable(Vector2i(5, 1)))
	m.apply_blocks({"madderby_road_open": true})
	assert_true(m.is_walkable(Vector2i(5, 1)))

func test_ferry_is_the_only_edge_to_corvane() -> void:
	# Items 1289, 1290.
	var layout: Dictionary = WorldValidator.load_layout()
	var places: Dictionary = layout.maps
	var cross: Array[String] = []
	for pid: String in places:
		var p: Dictionary = places[pid]
		if str(p.get("region", "")) != "veydal":
			continue
		for n: Variant in p.get("neighbours", []):
			if str((places[str(n)] as Dictionary).get("region", "")) == "corvane":
				cross.append("%s-%s" % [pid, n])
	assert_eq(cross, ["brindlewick-corvane_quay"] as Array[String])
	assert_true(bool(Transit.line("ferry_corvane").get("story", false)))
	assert_eq(Transit.arrival("ferry_corvane", "corvane_quay").cell, Vector2i(6, 22))
	var corvane: Dictionary = layout.regions.corvane
	assert_gt(int(corvane.origin[0]), int(layout.regions.veydal.size[0]) - 1, "Corvane lies right of Veydal")

func test_every_stop_offers_its_line() -> void:
	# The validator finds the boatman or driver at every stop.
	var errors: PackedStringArray = []
	WorldValidator.check_transit(errors, MapData.all_ids(), WorldValidator.load_layout().lines)
	assert_eq(errors.size(), 0, "\n".join(errors))
	var broken: Dictionary = {"lake_line": {"kind": "boat", "stops": {"brindlewick": [8, 12, "down"], "crowcrest": [5, 5, "up"]}},
		"oops": {"kind": "balloon", "stops": {"brindlewick": [0, 0, "up"]}}}
	WorldValidator.check_transit(errors, MapData.all_ids(), broken)
	var all: String = "\n".join(errors)
	assert_string_contains(all, "nobody on 'crowcrest'")
	assert_string_contains(all, "unknown kind 'balloon'")
	assert_string_contains(all, "needs at least two stops")
	assert_string_contains(all, "not on floor")

func test_ride_scene_runs() -> void:
	var r := TripScene.new("coach", Transit.trip_line("coach", "Copperfold"))
	add_child_autofree(r)
	var was: bool = GameState.reduce_motion
	GameState.reduce_motion = true
	await r.run()
	GameState.reduce_motion = was
	assert_almost_eq(r.progress, 0.5, 0.01)
	assert_string_contains(Transit.trip_line("coach", "Copperfold"), "Copperfold")
