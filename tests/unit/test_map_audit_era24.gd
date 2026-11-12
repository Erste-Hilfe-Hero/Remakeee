extends GutTest
## Map audit, Era II Vellmarch and Era IV Halcyra (tools/maps/audit_maps.py, kind road_dead_end):
## a town side without a way out keeps no road arm running into the tree or cliff frame, and the
## Thornridge house that had no door (8,7-10,8) now has one with a room behind it.

const REGIONS: Array[String] = ["vellmarch", "halcyra"]

func before_all() -> void:
	Database.load_all()

func _is_path(m: MapData, c: Vector2i) -> bool:
	return m.in_bounds(c) and m.kind_at(c) == TilesetFactory.Kind.PATH

func _on_edge(m: MapData, c: Vector2i) -> bool:
	return c.x == 0 or c.y == 0 or c.x == m.width - 1 or c.y == m.height - 1

## Road cells one step inside the frame whose straight road (1 or 2 wide, two road cells behind
## each cell) ends at a frame cell with no warp.
func _dead_ends(m: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(1, m.height - 1):
		for x: int in range(1, m.width - 1):
			var c := Vector2i(x, y)
			if not _is_path(m, c):
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if not _on_edge(m, n) or not m.warp_at(n).is_empty() or m.is_walkable(n):
					continue
				var side := Vector2i(d.y, d.x)
				var arm: Array[Vector2i] = [c]
				for s: int in [1, -1]:
					var a: Vector2i = c + side * s
					while _is_path(m, a):
						arm.append(a)
						a += side * s
				if arm.size() > 2:
					continue
				if arm.all(func(a: Vector2i) -> bool: return _is_path(m, a - d) and _is_path(m, a - d * 2)):
					out.append(c)
	return out

func test_no_road_runs_into_the_frame() -> void:
	var checked: int = 0
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if not m.outdoor or not REGIONS.has(m.region):
			continue
		var dead: Array[Vector2i] = _dead_ends(m)
		assert_eq(dead.size(), 0, "%s: no road ends at the frame %s" % [id, dead])
		checked += 1
	assert_gt(checked, 20, "Vellmarch and Halcyra outdoor maps checked")

func test_closed_town_sides_have_no_road_arm() -> void:
	# Hookwick and Cindergate Quay have no north exit, Lastlamp no south exit, Cindergate Quay,
	# Brightledge, Starwell and Whitecairn no west exit.
	for c: Array in [["hookwick", 5, 1], ["cindergate_quay", 5, 1], ["lastlamp", 5, 18], ["cindergate_quay", 1, 8],
			["brightledge", 1, 8], ["starwell", 1, 8], ["whitecairn", 1, 9]]:
		var m: MapData = MapData.load_map(str(c[0]))
		assert_false(_is_path(m, Vector2i(int(c[1]), int(c[2]))), "%s %d,%d is no road scrap" % c)

func test_the_dead_end_check_finds_a_road_arm() -> void:
	var rows: Array = ["TTTTTTTT", "T......T", "T___...T", "T___...T", "T......T", "TTTTTTTT"]
	var m: MapData = MapData.from_dict("probe", {"outdoor": true, "rows": rows, "warps": []})
	assert_eq(_dead_ends(m).size(), 2, "the arm into the trees on the left is found")
	m = MapData.from_dict("probe", {"outdoor": true, "rows": rows, "warps": [
		{"x": 0, "y": 2, "to": "x", "tx": 0, "ty": 0}, {"x": 0, "y": 3, "to": "x", "tx": 0, "ty": 0}]})
	assert_eq(_dead_ends(m).size(), 0, "an arm with an exit is a road")

func test_thornridge_house_has_a_door_and_a_room() -> void:
	var town: MapData = MapData.load_map("thornridge")
	var door := Vector2i(9, 8)
	assert_eq(town.kind_at(door), TilesetFactory.Kind.DOOR, "the house at 8,7-10,8 has a door")
	var w: Dictionary = town.warp_at(door)
	assert_eq(str(w.get("to", "")), "thornridge_house", "the door leads into the house")
	var room: MapData = MapData.load_map("thornridge_house")
	assert_not_null(room, "the room exists")
	if room == null:
		return
	assert_eq(room.region, town.region, "the room is drawn like the town")
	assert_true(room.width >= 3, "the room is no narrower than the house")
	assert_true(room.is_walkable(Vector2i(int(w.tx), int(w.ty))), "going in lands on the floor")
	assert_true(room.npcs.any(func(n: Dictionary) -> bool: return str(n.get("dialogue", "")) == "rooms/thornridge_house_brenna"),
		"someone lives there")
	assert_true(town.is_walkable(door + Vector2i.DOWN), "there is ground in front of the door")
