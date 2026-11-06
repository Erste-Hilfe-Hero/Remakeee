extends GutTest
## Area 3 item 992: every cave has a campfire that saves the game but does not heal.

func before_all() -> void:
	Database.load_all()

func _caves() -> Array[String]:
	var out: Array[String] = []
	var places: Dictionary = WorldValidator.load_layout().get("maps", {})
	for id: String in places:
		if str((places[id] as Dictionary).get("kind", "")) == "cave":
			out.append(id)
	return out

func test_every_cave_has_a_campfire_that_saves() -> void:
	assert_gt(_caves().size(), 3)
	for id: String in _caves():
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
		assert_true(raw.has("camp"), "%s has a campfire" % id)
		if not raw.has("camp"):
			continue
		var cell := Vector2i(int(raw.camp[0]), int(raw.camp[1]))
		var m: MapData = MapData.load_map(id)
		assert_eq(m.kind_at(cell), TilesetFactory.Kind.LAMP, id)
		var sign: Dictionary = {}
		for s: Dictionary in m.signs:
			if Vector2i(int(s.x), int(s.y)) == cell:
				sign = s
		assert_false(sign.is_empty(), "%s: the fire has a sign" % id)
		var entry: Dictionary = Dialogue.get_entry(str(sign.get("dialogue", "")))
		assert_eq(str(entry.get("action", "")), "camp", "%s: the fire saves" % id)
		assert_eq(m.heal_point, Vector2i(-1, -1), "%s: no rest point that heals" % id)
