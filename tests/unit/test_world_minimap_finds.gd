extends GutTest
## Plan item 1097: a taken hidden find stays as a filled cross on the minimap.

func _map() -> MapData:
	var rows: Array = []
	for y: int in 8:
		rows.append(".".repeat(12))
	return MapData.from_dict("mm_finds_t", {"rows": rows, "outdoor": true, "secrets": [
		{"x": 3, "y": 3, "item": "potion", "count": 1, "flag": "mm_t_a"},
		{"x": 8, "y": 4, "item": "potion", "count": 1, "flag": "mm_t_b"}]})

func test_only_taken_finds_get_a_cross() -> void:
	var m: MapData = _map()
	var mm := Minimap.new()
	add_child_autofree(mm)
	mm.refresh(m, Vector2i(5, 4), [], {})
	assert_eq(mm.taken_finds().size(), 0, "nothing taken yet")
	mm.refresh(m, Vector2i(5, 4), [], {"mm_t_b": true})
	assert_eq(mm.taken_finds(), [Vector2i(8, 4)] as Array[Vector2i])

func test_game_flags_are_the_default() -> void:
	var m: MapData = _map()
	var mm := Minimap.new()
	add_child_autofree(mm)
	GameState.flags["mm_t_a"] = true
	mm.refresh(m, Vector2i(5, 4))
	assert_eq(mm.taken_finds(), [Vector2i(3, 3)] as Array[Vector2i])
	GameState.flags.erase("mm_t_a")
