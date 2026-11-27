extends GutTest
## Whole-world connectivity (map pass 1.3.2, scripts/core/WorldGraph.gd): every map is reachable
## from the start, every way into a map lands on free floor, no patch the player can reach is a
## one-way trap without a way back to a rest spring, and the story regions open in story order.

var _maps: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_maps = WorldGraph.load_all()

func test_the_world_has_no_connectivity_problems() -> void:
	var out: PackedStringArray = WorldGraph.problems(_maps)
	for p: String in out:
		gut.p(p)
	assert_eq(out.size(), 0, "world graph problems (listed above)")

func test_every_map_and_floor_is_in_the_graph() -> void:
	var g := WorldGraph.new(_maps)
	var reached: Dictionary = g.reach([g.start_node()] as Array[String])
	var seen: Dictionary = {}
	for n: String in reached:
		seen[n.get_slice("#", 0)] = true
	assert_eq(seen.size(), MapData.all_ids().size(), "every map id is reached from the start")
	assert_false(g.start_node().is_empty(), "the start cell is floor")

func test_story_regions_open_in_order() -> void:
	# Before the ferry flag only Veydal; after the last gate all eight regions.
	var all_gates: Dictionary = {}
	for r: String in WorldGraph.REGION_GATES:
		all_gates[WorldGraph.REGION_GATES[r]] = true
	var shut := WorldGraph.new(_maps, WorldGraph.Mode.OPEN, all_gates)
	assert_eq(_regions(shut), ["veydal"])
	var open := WorldGraph.new(_maps)
	var want: Array = WorldGraph.REGION_ORDER.duplicate()
	want.sort()
	assert_eq(_regions(open), want)

func _regions(g: WorldGraph) -> Array:
	var out: Dictionary = {}
	for n: String in g.reach([g.start_node()] as Array[String]):
		out[(_maps[n.get_slice("#", 0)] as MapData).region] = true
	var k: Array = out.keys()
	k.sort()
	return k

func test_rest_points_are_free_floor() -> void:
	var g := WorldGraph.new(_maps)
	assert_eq(g.check_rests().size(), 0, str(g.check_rests()))
	var rests: int = 0
	for id: String in _maps:
		if (_maps[id] as MapData).heal_point.x >= 0:
			rests += 1
			assert_false(g.node_at(id, (_maps[id] as MapData).heal_point).is_empty(), "%s rest point is in a patch" % id)
	assert_gt(rests, 30, "the world has rest springs")

# --- The checks catch what they are meant to catch (small made-up worlds) -------------------

func _map(id: String, rows: Array, extra: Dictionary = {}) -> MapData:
	var raw: Dictionary = {"name": id, "region": "veydal", "rows": rows, "warps": [], "npcs": [], "signs": []}
	raw.merge(extra, true)
	return MapData.from_dict(id, raw)

func test_a_one_way_warp_into_a_room_without_rest_is_a_trap() -> void:
	var maps: Dictionary = {
		"lighthouse": _map("lighthouse", ["......", "......", "......", "......", "......", "......"],
			{"heal_point": [1, 1], "warps": [{"x": 5, "y": 4, "to": "pit", "tx": 1, "ty": 1}]}),
		"pit": _map("pit", ["WWWW", "W..W", "WWWW"]),
	}
	var open := WorldGraph.new(maps)
	var worst := WorldGraph.new(maps, WorldGraph.Mode.WORST)
	var reached: Dictionary = open.reach([open.start_node()] as Array[String])
	assert_true(reached.has(open.node_at("pit", Vector2i(1, 1))), "the pit is reached")
	var traps: PackedStringArray = WorldGraph.traps(open, worst, reached)
	assert_eq(traps.size(), 1, str(traps))
	assert_string_contains(traps[0], "'pit'")

func test_a_warp_back_out_of_the_room_is_no_trap() -> void:
	var maps: Dictionary = {
		"lighthouse": _map("lighthouse", ["......", "......", "......", "......", "......", "......"],
			{"heal_point": [1, 1], "warps": [{"x": 5, "y": 4, "to": "room", "tx": 1, "ty": 1}]}),
		"room": _map("room", ["WWWW", "W..W", "WWDW"], {"warps": [{"x": 2, "y": 2, "to": "lighthouse", "tx": 4, "ty": 4}]}),
	}
	var open := WorldGraph.new(maps)
	var worst := WorldGraph.new(maps, WorldGraph.Mode.WORST)
	assert_eq(WorldGraph.traps(open, worst, open.reach([open.start_node()] as Array[String])).size(), 0)

func test_a_person_who_may_appear_and_seal_a_dead_end_is_a_trap() -> void:
	# Corridor: the person who shows up later stands between the end cell and the rest.
	var maps: Dictionary = {
		"lighthouse": _map("lighthouse", ["TTTTTT", "T....T", "TTTT.T", "TTTT.T", "TTTT.T", "TTTTTT"],
			{"heal_point": [1, 1], "npcs": [{"id": "late", "x": 4, "y": 3, "show_flag": "later"}]}),
	}
	var open := WorldGraph.new(maps)
	var worst := WorldGraph.new(maps, WorldGraph.Mode.WORST)
	var traps: PackedStringArray = WorldGraph.traps(open, WorldGraph.new(maps, WorldGraph.Mode.WORST), open.reach([open.start_node()] as Array[String]))
	assert_eq(traps.size(), 1, str(traps))
	assert_true(worst.node_at("lighthouse", Vector2i(4, 3)).is_empty(), "the person's cell is no floor in the worst case")

func test_a_warp_onto_a_wall_or_a_person_is_a_bad_landing() -> void:
	var maps: Dictionary = {
		"lighthouse": _map("lighthouse", ["......", "......", "......", "......", "......", "......"],
			{"heal_point": [1, 1], "warps": [{"x": 5, "y": 4, "to": "room", "tx": 0, "ty": 0}, {"x": 5, "y": 5, "to": "room", "tx": 1, "ty": 1},
				{"x": 0, "y": 5, "to": "nowhere", "tx": 1, "ty": 1}]}),
		"room": _map("room", ["WWWW", "W..W", "WWWW"], {"npcs": [{"id": "keeper", "x": 1, "y": 1}]}),
	}
	var text: String = "\n".join(WorldGraph.new(maps).land_problems)
	assert_string_contains(text, "lands on a solid tile 'W' in 'room' at (0, 0)")
	assert_string_contains(text, "lands on 'keeper' standing at (1, 1) in 'room'")
	assert_string_contains(text, "unknown map 'nowhere'")

func test_a_rest_point_under_a_person_is_reported() -> void:
	var maps: Dictionary = {
		"lighthouse": _map("lighthouse", ["......", "......", "......", "......", "......", "......"],
			{"heal_point": [1, 1], "npcs": [{"id": "keeper", "x": 1, "y": 1}]}),
	}
	assert_eq(WorldGraph.new(maps).check_rests().size(), 1)

func test_story_warps_follow_dialogue_and_scenes() -> void:
	var g := WorldGraph.new(_maps)
	# The Corvane ferry runs as a scene from the ferry sign at the dock (story line, not Transit).
	var m: MapData = _maps["brindlewick"]
	var found: Array[Dictionary] = []
	for list: Array in [m.npcs, m.signs]:
		for n: Dictionary in list:
			for t: Dictionary in g.story_warps(str(n.get("dialogue", ""))):
				if str(t.to) == "corvane_quay":
					found.append(t)
	assert_false(found.is_empty(), "the Brindlewick ferry sign takes the player to Corvane")
	for t: Dictionary in found:
		assert_true("ferry_corvane_open" in t.flags or "scene_ferry_crossing_seen" in t.flags, "the crossing waits for the story: %s" % [t.flags])
	assert_false(g.node_at("corvane_quay", Vector2i(6, 22)).is_empty(), "the ferry lands on the quay")
