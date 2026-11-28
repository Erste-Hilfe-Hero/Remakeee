extends GutTest
## Map audit of the Solenne outdoor maps (Ochrewell, Glasswind Flats): every sign tile can be read,
## every building has a door that leads into a room and back, the road is one piece, and no story
## figure stands in a doorway or on the cell a room drops the player on.

const OUTDOOR: Array[String] = ["ochrewell", "glasswind_flats"]
const ROOMS: Array[String] = ["ochrewell_pottery", "ochrewell_dome", "ochrewell_store"]

func before_all() -> void:
	Database.load_all()

func _cells(m: MapData, ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in m.height:
		var row: String = m.base_row(y)
		for x: int in row.length():
			if row[x] == ch:
				out.append(Vector2i(x, y))
	return out

func test_every_sign_tile_has_a_text() -> void:
	for mid: String in OUTDOOR:
		var m: MapData = MapData.load_map(mid)
		var signed: Dictionary = {}
		for s: Dictionary in m.signs:
			signed[Vector2i(int(s.x), int(s.y))] = true
		for c: Vector2i in _cells(m, "S"):
			assert_true(signed.has(c), "%s sign tile %s has no text" % [mid, c])

func test_oren_heliographs_can_be_turned() -> void:
	var keys: Array = MapData.load_map("glasswind_flats").signs.map(func(s: Dictionary) -> String: return str(s.dialogue))
	for i: int in range(1, 4):
		assert_has(keys, "glasswind_flats/helio_%d" % i)

func test_every_town_door_leads_into_a_room_and_back() -> void:
	var town: MapData = MapData.load_map("ochrewell")
	var doors: Array[Vector2i] = _cells(town, "D")
	assert_eq(doors.size(), 4)
	for d: Vector2i in doors:
		var w: Dictionary = town.warp_at(d)
		assert_false(w.is_empty(), "door %s leads nowhere" % d)
		var room: MapData = MapData.load_map(str(w.to))
		assert_not_null(room)
		var back: Array = room.warps.filter(func(r: Dictionary) -> bool: return str(r.to) == "ochrewell")
		assert_false(back.is_empty(), "%s has no way back" % w.to)
		assert_eq(Vector2i(int(back[0].tx), int(back[0].ty)), d + Vector2i.DOWN, "%s drops the player in front of its door" % w.to)
	for rid: String in ROOMS:
		var r: MapData = MapData.load_map(rid)
		assert_eq(r.region, "solenne")
		assert_eq(r.npcs.size(), 1)

func test_story_figures_keep_doorsteps_free() -> void:
	var town: MapData = MapData.load_map("ochrewell")
	var steps: Dictionary = {}
	for d: Vector2i in _cells(town, "D"):
		steps[d + Vector2i.DOWN] = true
	for n: Variant in StoryPlacements.data().get("ochrewell", {}).get("npcs", []):
		var c := Vector2i(int(n.x), int(n.y))
		assert_false(steps.has(c), "%s stands on a doorstep %s" % [n.id, c])
	for n: Dictionary in town.npcs:
		assert_false(steps.has(Vector2i(int(n.x), int(n.y))), "%s stands on a doorstep" % n.id)

func test_the_roads_are_one_piece() -> void:
	for mid: String in OUTDOOR:
		_road_in_one_piece(mid)

func _road_in_one_piece(mid: String) -> void:
	var m: MapData = MapData.load_map(mid)
	var path: Array[Vector2i] = _cells(m, "_")
	var seen: Dictionary = {path[0]: true}
	var todo: Array[Vector2i] = [path[0]]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if m.base_char(n) == "_" and not seen.has(n):
				seen[n] = true
				todo.append(n)
	assert_eq(seen.size(), path.size(), "the road of %s breaks into pieces" % mid)
