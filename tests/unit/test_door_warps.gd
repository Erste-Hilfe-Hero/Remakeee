extends GutTest
## Map audit (interiors and dungeons): every door on every map and floor leads somewhere, and
## each door warp pairs up with a door on the other side. Going in lands you on free floor in
## front of the way back out, and coming back out lands you in front of the door you used.
## Rooms built by tools/art/gen_rooms.py keep their door emblem: spring rooms heal, shop rooms sell.

func before_all() -> void:
	Database.load_all()

func _next_to(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

## Cells where people of the map file and the story placements stand (the daily wanderers move
## every day and are left out).
func _people(m: MapData) -> Dictionary:
	var out: Dictionary = {}
	var path: String = "res://data/maps/%s.json" % m.file_id
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var level: Dictionary = raw
	if m.floor_index > 0:
		level = (raw.floors as Array)[m.floor_index - 1]
	for n: Variant in level.get("npcs", []):
		out[Vector2i(int(n.x), int(n.y))] = str(n.get("id", ""))
	for n: Variant in StoryPlacements.for_map(m.id).get("npcs", []):
		var d: Dictionary = n
		if d.has("spot"):
			if m.spots.has(str(d.spot)):
				out[m.spots[str(d.spot)]] = str(d.get("id", ""))
		elif d.has("x"):
			out[Vector2i(int(d.x), int(d.y))] = str(d.get("id", ""))
	return out

func _free(m: MapData, c: Vector2i) -> bool:
	return m.is_walkable(c) and m.warp_at(c).is_empty() and not _people(m).has(c)

func test_every_door_has_a_warp() -> void:
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for y: int in m.height:
			for x: int in m.rows[y].length():
				var c := Vector2i(x, y)
				if m.kind_at(c) == TilesetFactory.Kind.DOOR:
					assert_false(m.warp_at(c).is_empty(), "%s: door %s leads somewhere" % [id, c])

func test_every_door_warp_pairs_with_a_door_back() -> void:
	var pairs: int = 0
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for w: Dictionary in m.warps:
			var c := Vector2i(int(w.x), int(w.y))
			if m.kind_at(c) != TilesetFactory.Kind.DOOR:
				continue
			var dest: MapData = MapData.load_map(str(w.to))
			assert_not_null(dest, "%s door %s leads to a map" % [id, c])
			if dest == null:
				continue
			var arrive := Vector2i(int(w.tx), int(w.ty))
			assert_true(_free(dest, arrive), "%s door %s lands on free floor in %s, not %s" % [id, c, w.to, arrive])
			if str(w.to) == id:
				continue  # a hall door through to the other side of the same map (Ashmere Station)
			var back: Dictionary = {}
			for r: Dictionary in dest.warps:
				if str(r.to) == id and _next_to(Vector2i(int(r.x), int(r.y)), arrive):
					back = r
			assert_false(back.is_empty(), "%s door %s: %s has the way back next to %s" % [id, c, w.to, arrive])
			if back.is_empty():
				continue
			var front := Vector2i(int(back.tx), int(back.ty))
			assert_true(_next_to(front, c), "%s door %s: coming back out of %s lands in front of it, not at %s" % [id, c, w.to, front])
			assert_true(_free(m, front), "%s: %s in front of door %s is free floor" % [id, front, c])
			pairs += 1
	assert_gt(pairs, 40, "door pairs checked")

func test_rooms_keep_their_door_emblems() -> void:
	var rooms: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/rooms.json"))
	var layout: Dictionary = WorldValidator.load_layout().maps
	var checked: int = 0
	for id: String in MapData.all_ids():
		if not layout.has(id) or not (layout[id] as Dictionary).has("inside"):
			continue
		var m: MapData = MapData.load_map(id)
		if not m.npcs.any(func(n: Dictionary) -> bool: return str(n.get("dialogue", "")).begins_with("rooms/")):
			continue
		var town: MapData = MapData.load_map(str(layout[id].inside))
		var door := Vector2i(-1, -1)
		for w: Dictionary in town.warps:
			if str(w.to) == id:
				door = Vector2i(int(w.x), int(w.y))
		assert_true(town.in_bounds(door), "%s has a door on %s" % [id, town.id])
		var role: int = int(town.door_roles().get(door, TilesetFactory.DoorRole.HOUSE))
		var actions: Array[String] = []
		for n: Dictionary in m.npcs:
			var key: String = str(n.get("dialogue", ""))
			if key.begins_with("rooms/"):
				actions.append(str((rooms.get(key.trim_prefix("rooms/"), {}) as Dictionary).get("action", "")))
		if id.ends_with("_spring"):
			assert_eq(role, TilesetFactory.DoorRole.HEAL, "%s door shows the heal emblem" % id)
			assert_true(m.heal_point.x >= 0, "%s has a rest point" % id)
			assert_has(actions, "heal", "%s has someone who heals" % id)
		elif id.ends_with("_shop"):
			assert_eq(role, TilesetFactory.DoorRole.SHOP, "%s door shows the shop emblem" % id)
			assert_true(actions.any(func(a: String) -> bool: return a.begins_with("shop ")), "%s has someone who sells" % id)
		else:
			assert_eq(role, TilesetFactory.DoorRole.HOUSE, "%s door is a plain house door" % id)
		assert_true(m.width >= 8 and m.height >= 6, "%s is big enough for its house" % id)
		checked += 1
	assert_eq(checked, 15, "every room behind a former dead door")
