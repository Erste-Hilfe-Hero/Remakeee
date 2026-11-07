extends GutTest
## Area 3 item 1093: three benches look out over the lake; sitting brings a call and a hint.

const BENCHES: Dictionary = {"reedhaven": Vector2i(1, 5), "brackwater_fen": Vector2i(8, 4), "corvane_quay": Vector2i(4, 19)}

func test_three_benches_with_hints() -> void:
	for mid: String in BENCHES:
		var m: MapData = MapData.load_map(mid)
		var s: Dictionary = m.sign_at(BENCHES[mid])
		assert_eq(str(s.get("dialogue", "")), mid + "/lake_bench", mid)
		var e: Dictionary = Dialogue.get_entry(mid + "/lake_bench")
		var act: String = ""
		for c: Dictionary in e.get("choices", []):
			act = str(c.get("action", act)) if str(c.get("action", "")).begins_with("lake_bench") else act
		var parts: PackedStringArray = act.split(" ")
		assert_eq(parts.size(), 3, act)
		assert_not_null(Database.species(parts[1]), "a real Spirling calls: " + parts[1])
		assert_true(Dialogue.exists(parts[2]), parts[2])
		assert_false(Dialogue.get_entry(parts[2]).lines.is_empty())

func test_benches_face_the_water() -> void:
	for mid: String in BENCHES:
		var m: MapData = MapData.load_map(mid)
		var c: Vector2i = BENCHES[mid]
		var wet: bool = false
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			wet = wet or m.kind_at(c + d) == TilesetFactory.Kind.WATER
		assert_true(wet, mid + " bench is next to the lake")
