extends GutTest
## Area 3 item 1061: a grey mark with the gear's sign in front of a spot that still needs gear.

class FakeWorld extends Node:
	var map: MapData
	func npc_at(_c: Vector2i) -> NPC:
		return null

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.inventory.duplicate()
	GameState.inventory.erase("climbing_pick")
	GameState.inventory.erase("wading_boots")

func after_each() -> void:
	GameState.inventory = _saved

func test_gear_spot_is_grey_until_the_gear_is_owned() -> void:
	var w := FakeWorld.new()
	add_child_autofree(w)
	w.map = MapData.load_map("crowcrest")
	var from := Vector2i(8, 13)
	var target := Vector2i(8, 14)
	assert_eq(InteractHint.missing_gear(w.map, from, target), "climbing_pick")
	assert_eq(InteractHint.kind_at(w, from, target), InteractHint.Kind.LOCKED)
	GameState.add_item("climbing_pick")
	assert_eq(InteractHint.missing_gear(w.map, from, target), "")
	assert_eq(InteractHint.kind_at(w, from, target), InteractHint.Kind.GEAR)

func test_wading_water_asks_for_boots() -> void:
	var m: MapData = MapData.load_map("brackwater_fen")
	var wade := Vector2i(-1, -1)
	for y: int in m.height:
		for x: int in m.width:
			if wade.x < 0 and m.kind_at(Vector2i(x, y)) == TilesetFactory.Kind.WADE:
				wade = Vector2i(x, y)
	assert_true(wade.x >= 0, "the fen has wading water")
	assert_eq(InteractHint.missing_gear(m, wade + Vector2i.UP, wade), "wading_boots")

func test_every_gear_in_the_world_has_a_sign() -> void:
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for g: Dictionary in m.gear_spots:
			var gear: Variant = g.get("gear", "")
			if gear is String:
				assert_true(InteractHint.GLYPHS.has(gear), "%s: sign for %s" % [id, gear])
