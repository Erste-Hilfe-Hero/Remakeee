extends GutTest
## Owner bug "Leuchtturm-Tuer mit Leuchtturm richtig verbinden": the Brindlewick lighthouse door
## is part of the tower (Era I and Era II), and every door warp of Brindlewick and the lighthouse
## sits on a building's door and has a return warp to the cell in front of it.

const MAPS: Array[String] = ["brindlewick", "lighthouse"]
const BUILDING: Array[int] = [TilesetFactory.Kind.ROOF, TilesetFactory.Kind.WALL, TilesetFactory.Kind.TOWER, TilesetFactory.Kind.INNER_WALL]
const ATLASES: Array[String] = ["res://art/era1/tiles/overworld.png", "res://art/era1/tiles/overworld_veydal.png", "res://art/era2/tiles/overworld.png"]

func before_all() -> void:
	Database.load_all()

func _kinds(m: MapData) -> Callable:
	return func(c: Vector2i) -> int: return m.kind_at(c) if m.in_bounds(c) else TilesetFactory.Kind.GRASS

func _next_to(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

func _lighthouse_door(m: MapData) -> Vector2i:
	for w: Dictionary in m.warps:
		if str(w.to) == "lighthouse":
			return Vector2i(int(w.x), int(w.y))
	return Vector2i(-1, -1)

func test_every_door_has_a_warp_and_belongs_to_a_building() -> void:
	for id: String in MAPS:
		var m: MapData = MapData.load_map(id)
		for y: int in m.height:
			for x: int in m.rows[y].length():
				var c := Vector2i(x, y)
				if m.kind_at(c) != TilesetFactory.Kind.DOOR:
					continue
				assert_false(m.warp_at(c).is_empty(), "%s door %s has a warp" % [id, c])
				var walls: int = 0
				for d: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
					if m.in_bounds(c + d) and m.kind_at(c + d) in BUILDING:
						walls += 1
				assert_true(walls > 0, "%s door %s is set in a building" % [id, c])

func test_warps_into_buildings_sit_on_doors() -> void:
	for id: String in MAPS:
		var m: MapData = MapData.load_map(id)
		for w: Dictionary in m.warps:
			var c := Vector2i(int(w.x), int(w.y))
			var dest: MapData = MapData.load_map(str(w.to))
			assert_not_null(dest, "%s warp %s leads to a map" % [id, c])
			if dest == null:
				continue
			# Outdoor <-> indoor is a door; other warps are map edges or stairs.
			if m.outdoor != dest.outdoor:
				assert_eq(m.kind_at(c), TilesetFactory.Kind.DOOR, "%s warp %s into %s is on a door" % [id, c, w.to])

func test_every_door_warp_has_a_matching_return() -> void:
	for id: String in MAPS:
		var m: MapData = MapData.load_map(id)
		for w: Dictionary in m.warps:
			var c := Vector2i(int(w.x), int(w.y))
			var kind: int = m.kind_at(c)
			if kind != TilesetFactory.Kind.DOOR and kind != TilesetFactory.Kind.STAIRS:
				continue
			var dest: MapData = MapData.load_map(str(w.to))
			var arrive := Vector2i(int(w.tx), int(w.ty))
			assert_true(dest.is_walkable(arrive) and dest.warp_at(arrive).is_empty(), "%s %s arrives on free floor in %s" % [id, c, w.to])
			var back: Dictionary = {}
			for r: Dictionary in dest.warps:
				if str(r.to) == id and _next_to(Vector2i(int(r.x), int(r.y)), arrive):
					back = r
			assert_false(back.is_empty(), "%s %s: %s has a way back next to %s" % [id, c, w.to, arrive])
			if back.is_empty():
				continue
			var front := Vector2i(int(back.tx), int(back.ty))
			assert_true(_next_to(front, c), "%s %s: the way back lands in front of it, not at %s" % [id, c, front])
			assert_true(m.is_walkable(front) and m.warp_at(front).is_empty(), "%s: %s in front of %s is free floor" % [id, front, c])

func test_lighthouse_door_is_in_front_of_the_path() -> void:
	var m: MapData = MapData.load_map("brindlewick")
	var door: Vector2i = _lighthouse_door(m)
	assert_eq(m.kind_at(door), TilesetFactory.Kind.DOOR)
	assert_eq(m.kind_at(door + Vector2i.UP), TilesetFactory.Kind.TOWER)
	assert_eq(m.kind_at(door + Vector2i.UP * 2), TilesetFactory.Kind.LAMP)
	var inside: MapData = MapData.load_map("lighthouse")
	var exit: Dictionary = inside.warp_at(Vector2i(int(m.warp_at(door).tx), int(m.warp_at(door).ty)) + Vector2i.DOWN)
	assert_eq(str(exit.get("to", "")), "brindlewick", "the lighthouse door inside leads back out")
	assert_eq(Vector2i(int(exit.tx), int(exit.ty)), door + Vector2i.DOWN, "back out onto the tile in front of the door")

func test_lighthouse_door_uses_the_tower_foot_tile() -> void:
	for region: String in ["veydal", ""]:
		TilesetFactory.get_tileset(region)
		var m: MapData = MapData.load_map("brindlewick")
		var door: Vector2i = _lighthouse_door(m)
		var t: int = TilesetFactory.Kind.TOWER
		assert_eq(TilesetFactory.atlas_coords(TilesetFactory.Kind.DOOR, door, _kinds(m)), Vector2i(t, TilesetFactory.LIGHTHOUSE_DOOR_ROW))
		assert_eq(TilesetFactory.atlas_coords(t, door + Vector2i.UP, _kinds(m)), Vector2i(t, TilesetFactory.LIGHTHOUSE_SHAFT_ROW))
		var right: Vector2i = TilesetFactory.atlas_coords(TilesetFactory.Kind.GRASS, door + Vector2i.RIGHT, _kinds(m))
		assert_true(right.y < TilesetFactory.SHADOW_ROW, "no house shadow next to the slim tower")
	TilesetFactory.clear_cache()

func test_tower_door_without_lamp_stays_a_door() -> void:
	TilesetFactory.get_tileset()
	var rows: Array[String] = [".|.", ".D.", "..."]
	var kinds: Callable = func(c: Vector2i) -> int:
		if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= 3:
			return TilesetFactory.Kind.GRASS
		return TilesetFactory.kind_for(rows[c.y][c.x])
	var d: int = TilesetFactory.Kind.DOOR
	assert_false(TilesetFactory.is_lighthouse_door(Vector2i(1, 1), kinds))
	assert_eq(TilesetFactory.atlas_coords(d, Vector2i(1, 1), kinds, TilesetFactory.DoorRole.RIFT_GATE), Vector2i(d, TilesetFactory.DoorRole.RIFT_GATE))
	assert_eq(TilesetFactory.atlas_coords(TilesetFactory.Kind.TOWER, Vector2i(1, 0), kinds), Vector2i(TilesetFactory.Kind.TOWER, 0))

func test_shaft_runs_into_the_door_tile_in_every_atlas() -> void:
	var t: int = TilesetFactory.TILE
	var x0: int = TilesetFactory.Kind.TOWER * t
	for path: String in ATLASES:
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(img, path)
		if img == null:
			continue
		var seam_shaft: int = TilesetFactory.LIGHTHOUSE_SHAFT_ROW * t + t - 1
		var seam_door: int = TilesetFactory.LIGHTHOUSE_DOOR_ROW * t
		# Shaft outline columns (12 px wide at the foot) meet across the seam.
		for x: int in [2, 13]:
			var a: Color = img.get_pixel(x0 + x, seam_shaft)
			var b: Color = img.get_pixel(x0 + x, seam_door)
			assert_eq(a.to_html(), b.to_html(), "%s: shaft edge x %d runs into the door tile" % [path, x])
			assert_ne(a.to_html(), img.get_pixel(x0 + x - 1 if x == 2 else x0 + x + 1, seam_shaft).to_html(), "%s: outline at x %d" % [path, x])
		# The foot tile is not the plain shaft on its plinth.
		var differs: bool = false
		for y: int in t:
			for x: int in t:
				if img.get_pixel(x0 + x, seam_door + y) != img.get_pixel(x0 + x, y):
					differs = true
		assert_true(differs, "%s: the tower foot with its door is drawn" % path)
