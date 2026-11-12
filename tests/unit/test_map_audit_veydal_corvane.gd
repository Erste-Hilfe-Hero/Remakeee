extends GutTest
## Owner map audit ("alle Gebaeude und Map ueberpruefen, dass es clean aussieht"), Veydal and
## Corvane outdoor maps: winding towers, cave doors at the map edge, a cut-off house and people
## standing in front of doors (tools/maps/audit_maps.py finds them).

const TOWNS: Array[String] = ["brindlewick", "copperfold", "wrenhollow", "reedhaven", "thornridge",
	"corvane_quay", "madderby", "greyreach", "stillwater", "woadfen"]

func _kinds(m: MapData) -> Callable:
	return func(c: Vector2i) -> int: return m.kind_at(c) if m.in_bounds(c) else TilesetFactory.Kind.GRASS

func _grid(rows: Array[String]) -> Callable:
	return func(c: Vector2i) -> int:
		if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= rows[c.y].length():
			return TilesetFactory.Kind.GRASS
		return TilesetFactory.kind_for(rows[c.y][c.x])

func test_a_tower_without_lamp_or_door_is_a_winding_tower() -> void:
	TilesetFactory.get_tileset()
	var t: int = TilesetFactory.Kind.TOWER
	var mine: Callable = _grid(["|", "|", "R"])
	assert_true(TilesetFactory.is_headframe(Vector2i(0, 0), mine))
	assert_eq(TilesetFactory.atlas_coords(t, Vector2i(0, 0), mine), Vector2i(t, TilesetFactory.HEADFRAME_TOP_ROW))
	assert_eq(TilesetFactory.atlas_coords(t, Vector2i(0, 1), mine), Vector2i(t, TilesetFactory.HEADFRAME_ROW))
	var lit: Callable = _grid(["L", "|", "D"])
	assert_false(TilesetFactory.is_headframe(Vector2i(0, 1), lit), "the lighthouse keeps its shaft")
	assert_eq(TilesetFactory.atlas_coords(t, Vector2i(0, 1), lit), Vector2i(t, TilesetFactory.LIGHTHOUSE_SHAFT_ROW))
	var dark: Callable = _grid(["|", "|", "D"])
	assert_false(TilesetFactory.is_headframe(Vector2i(0, 0), dark), "a dark lighthouse over a door is no mine tower")

func test_copperfold_towers_are_winding_towers() -> void:
	var m: MapData = MapData.load_map("copperfold")
	for x: int in [3, 9]:
		assert_eq(m.kind_at(Vector2i(x, 1)), TilesetFactory.Kind.TOWER)
		assert_true(TilesetFactory.is_headframe(Vector2i(x, 1), _kinds(m)), "copperfold tower %d" % x)

func test_brackwater_cave_ways_are_jetties_at_the_edge() -> void:
	var m: MapData = MapData.load_map("brackwater_fen")
	for c: Vector2i in [Vector2i(0, 13), Vector2i(11, 16)]:
		assert_eq(m.kind_at(c), TilesetFactory.Kind.PIER, "%s" % c)
		assert_false(m.warp_at(c).is_empty(), "%s still leads on" % c)

func test_no_house_is_a_single_tile_wide() -> void:
	var m: MapData = MapData.load_map("madderby")
	assert_false(m.kind_at(Vector2i(10, 8)) in [TilesetFactory.Kind.ROOF, TilesetFactory.Kind.WALL])
	assert_false(m.kind_at(Vector2i(10, 9)) in [TilesetFactory.Kind.ROOF, TilesetFactory.Kind.WALL])

func test_cave_and_culvert_doors_sit_in_rock() -> void:
	for spot: Array in [["gloamwood", Vector2i(3, 6)], ["quillbrook", Vector2i(9, 24)]]:
		var m: MapData = MapData.load_map(str(spot[0]))
		var c: Vector2i = spot[1]
		assert_eq(m.kind_at(c), TilesetFactory.Kind.DOOR)
		assert_eq(m.kind_at(c + Vector2i.UP), TilesetFactory.Kind.CLIFF, "%s door has rock above" % spot[0])

func test_nobody_stands_in_front_of_a_door() -> void:
	for id: String in TOWNS:
		var m: MapData = MapData.load_map(id)
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
		for n: Dictionary in raw.get("npcs", []):
			var below_door: Vector2i = Vector2i(int(n.x), int(n.y)) + Vector2i.UP
			assert_ne(m.kind_at(below_door) if m.in_bounds(below_door) else -1, TilesetFactory.Kind.DOOR,
				"%s: %s blocks a door" % [id, n.get("id", "")])

func test_woadfen_road_meets_the_west_road() -> void:
	var m: MapData = MapData.load_map("woadfen")
	for x: int in range(0, 8):
		assert_eq(m.kind_at(Vector2i(x, 24)), TilesetFactory.Kind.PATH, "woadfen road at %d,24" % x)
	assert_ne(m.kind_at(Vector2i(9, 25)), TilesetFactory.Kind.PATH, "no loose road scrap")
