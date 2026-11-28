extends GutTest
## Map audit (Ashmere outdoors): every door leads somewhere, no one stands in front of a door,
## roads that reach the border end in a warp, the Saltglass lighthouse has its lamp and the
## landmarks stand inside the map, not in the border cliff.

const MAPS: Array[String] = ["ashmere_station", "cinderfold", "saltglass"]

func before_all() -> void:
	Database.load_all()

func _kinds(m: MapData) -> Callable:
	return func(c: Vector2i) -> int: return m.kind_at(c) if m.in_bounds(c) else TilesetFactory.Kind.GRASS

func test_every_door_has_a_warp_and_a_free_front() -> void:
	for id: String in MAPS:
		var m: MapData = MapData.load_map(id)
		for y: int in m.height:
			for x: int in m.width:
				var c: Vector2i = Vector2i(x, y)
				if m.kind_at(c) != TilesetFactory.Kind.DOOR:
					continue
				assert_false(m.warp_at(c).is_empty(), "%s door %s leads somewhere" % [id, c])
				assert_true(m.is_walkable(c + Vector2i.DOWN), "%s door %s has ground in front" % [id, c])
				for n: Dictionary in m.npcs:
					assert_ne(Vector2i(int(n.x), int(n.y)), c + Vector2i.DOWN, "%s: %s blocks door %s" % [id, n.id, c])

func test_roads_at_the_border_end_in_a_warp() -> void:
	for id: String in MAPS:
		var m: MapData = MapData.load_map(id)
		for y: int in m.height:
			for x: int in m.width:
				var c: Vector2i = Vector2i(x, y)
				var edge: bool = x == 0 or y == 0 or x == m.width - 1 or y == m.height - 1
				if edge and m.is_walkable(c):
					assert_false(m.warp_at(c).is_empty(), "%s: open border cell %s has a warp" % [id, c])

func test_saltglass_lighthouse_has_its_lamp() -> void:
	var m: MapData = MapData.load_map("saltglass")
	var door: Vector2i = Vector2i(8, 6)
	assert_eq(str(m.warp_at(door).get("to", "")), "shade_rift")
	assert_true(TilesetFactory.is_lighthouse_door(door, _kinds(m)), "the shade_rift door is the foot of a lit tower")

func test_landmarks_stand_inside_the_border() -> void:
	for id: String in MAPS:
		var m: MapData = MapData.load_map(id)
		var c: Vector2i = Landmarks.cell(Landmarks.for_map(id))
		assert_true(c.x > 0 and c.x < m.width - 1, "%s landmark %s is not in the side cliff" % [id, c])
		for w: Dictionary in m.warps:
			assert_ne(Vector2i(int(w.x), int(w.y)), c + Vector2i.UP, "%s landmark covers a warp" % id)
