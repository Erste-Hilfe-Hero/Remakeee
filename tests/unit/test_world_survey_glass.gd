extends GutTest
## Area 3 items 1052 and 1053: the Survey Glass spots hidden finds up to 6 steps ahead,
## with 20 seconds between looks.

func _map() -> MapData:
	var rows: Array = []
	for y: int in 12:
		rows.append(".".repeat(12))
	return MapData.from_dict("glass_t", {"rows": rows, "outdoor": true, "secrets": [
		{"x": 5, "y": 1, "item": "tonic", "count": 1, "flag": "glass_a"},
		{"x": 6, "y": 3, "item": "tonic", "count": 1, "flag": "glass_b"},
		{"x": 8, "y": 6, "item": "tonic", "count": 1, "flag": "glass_c"},
		{"x": 5, "y": 9, "item": "tonic", "count": 1, "flag": "glass_d"}]})

func test_scan_looks_ahead_in_a_narrow_band() -> void:
	var m: MapData = _map()
	var up: Array[Vector2i] = SurveyGlass.scan(m, Vector2i(5, 7), Vector2i.UP, {})
	assert_true(Vector2i(5, 1) in up, "6 steps straight ahead")
	assert_true(Vector2i(6, 3) in up, "one cell to the side")
	assert_false(Vector2i(8, 6) in up, "too far to the side")
	assert_false(Vector2i(5, 9) in up, "behind the player")
	var down: Array[Vector2i] = SurveyGlass.scan(m, Vector2i(5, 7), Vector2i.DOWN, {})
	assert_eq(down, [Vector2i(5, 9)] as Array[Vector2i])

func test_range_and_taken_finds() -> void:
	var m: MapData = _map()
	assert_false(Vector2i(5, 1) in SurveyGlass.scan(m, Vector2i(5, 8), Vector2i.UP, {}), "7 steps is too far")
	assert_false(Vector2i(5, 1) in SurveyGlass.scan(m, Vector2i(5, 7), Vector2i.UP, {"glass_a": true}), "taken finds stay hidden")

func test_cooldown_of_twenty_seconds() -> void:
	SurveyGlass.mark_used(100000)
	assert_false(SurveyGlass.ready(110000))
	assert_eq(SurveyGlass.wait_left(110000), 10)
	assert_true(SurveyGlass.ready(120000))
	SurveyGlass.mark_used(-SurveyGlass.COOLDOWN_MS)

func test_glass_is_gear_with_a_giver() -> void:
	var it: Dictionary = Database.item(SurveyGlass.ITEM)
	assert_true(bool(it.get("gear", false)))
	assert_true(str(Dialogue.get_entry("wrenhollow/surveyor").get("action", "")).begins_with("give_item survey_glass"))
