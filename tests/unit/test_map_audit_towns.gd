extends GutTest
## Map audit, towns of Vellmarch (Era II) and Halcyra (Era IV) (tools/maps/audit_maps.py kinds
## town_twin and town_few_doors): no two towns of a region share a layout, every town has at
## least three buildings you can walk into, every Halcyra town has a shop, a rest house and two
## homes with someone in them, and every Vellmarch town has a landmark of its own.

const REGIONS: Array[String] = ["vellmarch", "halcyra"]
const TWIN_SHARE: float = 0.6
const MIN_TOWN_DOORS: int = 3
const HALCYRA_TOWNS: Array[String] = ["brightledge", "gildcrest", "starwell", "paleshore", "whitecairn"]

func before_all() -> void:
	Database.load_all()

func _towns(region: String) -> Array[String]:
	var out: Array[String] = []
	var places: Dictionary = WorldValidator.load_layout().maps
	for id: String in places:
		var p: Dictionary = places[id]
		if str(p.get("kind", "")) == "town" and MapData.exists(id) and MapData.load_map(id).region == region:
			out.append(id)
	out.sort()
	return out

## What an inner cell of a town is built from ("" for open ground and decoration).
func _built(m: MapData, c: Vector2i) -> String:
	match m.kind_at(c):
		TilesetFactory.Kind.PATH, TilesetFactory.Kind.PIER, TilesetFactory.Kind.STAIRS:
			return "road"
		TilesetFactory.Kind.WALL, TilesetFactory.Kind.ROOF, TilesetFactory.Kind.DOOR:
			return "house"
		TilesetFactory.Kind.WATER:
			return "water"
		TilesetFactory.Kind.CLIFF:
			return "cliff"
	return ""

## Share of the built cells of two towns that hold the same thing (1.0: the same layout).
func _twin_share(a: MapData, b: MapData) -> float:
	var same: int = 0
	var built: int = 0
	for y: int in range(1, maxi(a.height, b.height) - 1):
		for x: int in range(1, maxi(a.width, b.width) - 1):
			var c := Vector2i(x, y)
			var ka: String = _built(a, c) if a.in_bounds(c) and x < a.width - 1 and y < a.height - 1 else ""
			var kb: String = _built(b, c) if b.in_bounds(c) and x < b.width - 1 and y < b.height - 1 else ""
			if ka.is_empty() and kb.is_empty():
				continue
			built += 1
			if ka == kb:
				same += 1
	return float(same) / built if built > 0 else 0.0

func _rooms(m: MapData) -> Array[String]:
	var out: Array[String] = []
	for w: Dictionary in m.warps:
		if m.kind_at(Vector2i(int(w.x), int(w.y))) != TilesetFactory.Kind.DOOR:
			continue
		var dest: MapData = MapData.load_map(str(w.to))
		if dest != null and not dest.outdoor and not out.has(str(w.to)):
			out.append(str(w.to))
	return out

func _action(map_id: String, key: String) -> String:
	var parts: PackedStringArray = key.split("/")
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % parts[0]))
	var e: Variant = file.get(parts[1], {})
	return str((e as Dictionary).get("action", "")) if e is Dictionary else ""

func test_no_two_towns_of_a_region_share_a_layout() -> void:
	for region: String in REGIONS:
		var towns: Array[String] = _towns(region)
		assert_eq(towns.size(), 5, "%s has five towns" % region)
		for i: int in towns.size():
			for j: int in i:
				var share: float = _twin_share(MapData.load_map(towns[i]), MapData.load_map(towns[j]))
				assert_lt(share, TWIN_SHARE, "%s and %s look different (%.2f of the built cells agree)" % [towns[i], towns[j], share])

func test_the_twin_check_knows_a_copy() -> void:
	var a: MapData = MapData.load_map("hookwick")
	assert_eq(_twin_share(a, MapData.load_map("hookwick")), 1.0, "a town is its own twin")
	var rows: Array = ["TTTTTT", "T.RR.T", "T.HD.T", "T.__.T", "TT__TT"]
	var b: MapData = MapData.from_dict("probe", {"outdoor": true, "rows": rows})
	var moved: MapData = MapData.from_dict("probe", {"outdoor": true, "rows": ["TTTTTT", "TRR..T", "THD..T", "T__..T", "T__TTT"]})
	assert_lt(_twin_share(b, moved), TWIN_SHARE, "a town with the house and road moved is no twin")

func test_every_town_has_three_buildings_to_walk_into() -> void:
	for region: String in REGIONS:
		for id: String in _towns(region):
			var m: MapData = MapData.load_map(id)
			assert_gte(_rooms(m).size(), MIN_TOWN_DOORS, "%s: buildings with a door and a room" % id)

func test_halcyra_towns_have_a_shop_a_rest_house_and_homes() -> void:
	for id: String in HALCYRA_TOWNS:
		var rooms: Array[String] = _rooms(MapData.load_map(id))
		for key: String in ["shop", "spring", "home_1", "home_2"]:
			var rid: String = "%s_%s" % [id, key]
			assert_has(rooms, rid, "%s has the door to %s" % [id, rid])
			var room: MapData = MapData.load_map(rid)
			assert_not_null(room, rid)
			if room == null:
				continue
			assert_eq(room.region, "halcyra", "%s is drawn in the Era IV look" % rid)
			assert_eq(room.npcs.size(), 1, "%s has someone in it" % rid)
			var action: String = _action(rid, str(room.npcs[0].dialogue))
			if key == "shop":
				assert_true(action.begins_with("shop "), "%s sells" % rid)
			elif key == "spring":
				assert_eq(action, "heal", "%s heals" % rid)
				assert_true(room.is_walkable(room.heal_point), "%s has a rest point" % rid)
			else:
				assert_eq(action, "", "%s is a home" % rid)
		var roles: Dictionary = MapData.load_map(id).door_roles()
		assert_has(roles.values(), TilesetFactory.DoorRole.SHOP, "%s shows a shop door" % id)
		assert_has(roles.values(), TilesetFactory.DoorRole.HEAL, "%s shows a rest house door" % id)

func test_every_vellmarch_town_has_its_own_landmark() -> void:
	var kinds: Dictionary = {}
	for id: String in _towns("vellmarch"):
		var lm: Dictionary = Landmarks.for_map(id)
		assert_false(lm.is_empty(), "%s has a landmark" % id)
		if lm.is_empty():
			continue
		var kind: String = str(lm.kind)
		assert_eq(Landmarks.region_of(kind), "vellmarch", "%s: landmark from Vellmarch's own set" % id)
		assert_false(kinds.has(kind), "%s shares its landmark with %s" % [id, kinds.get(kind, "")])
		kinds[kind] = id
		assert_eq(Landmarks.lines_at(id, Landmarks.cell(lm)).size(), 2, "%s: the landmark can be read" % id)
	assert_eq(kinds.size(), 5)

func test_tallowmere_road_does_not_run_into_the_trees() -> void:
	var m: MapData = MapData.load_map("tallowmere")
	for x: int in [5, 6]:
		assert_ne(m.kind_at(Vector2i(x, 1)), TilesetFactory.Kind.PATH, "no road arm under the closed north side")
	for door: Vector2i in [Vector2i(3, 3), Vector2i(8, 3)]:
		assert_eq(m.kind_at(door + Vector2i.DOWN), TilesetFactory.Kind.PATH, "a lane runs past the door %s" % door)
