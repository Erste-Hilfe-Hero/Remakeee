extends GutTest
## Area 3 item 1091: finds in ferns and reeds glint every 2 seconds in wind, else every 4.

func _map() -> MapData:
	return MapData.from_dict("glint_t", {"rows": [".,%_"], "outdoor": true})

func test_wind_speeds_up_fern_and_reed_glints() -> void:
	var m: MapData = _map()
	assert_eq(WorldMechanics.glint_every(m, Vector2i(1, 0), "wind"), 2.0, "fern")
	assert_eq(WorldMechanics.glint_every(m, Vector2i(2, 0), "wind"), 2.0, "reeds")
	assert_eq(WorldMechanics.glint_every(m, Vector2i(0, 0), "wind"), 4.0, "short grass stays")
	assert_eq(WorldMechanics.glint_every(m, Vector2i(3, 0), "wind"), 4.0, "path stays")

func test_other_weather_keeps_the_normal_rhythm() -> void:
	var m: MapData = _map()
	for w: String in ["clear", "rain", "fog", "storm"]:
		assert_eq(WorldMechanics.glint_every(m, Vector2i(1, 0), w), 4.0, w)
