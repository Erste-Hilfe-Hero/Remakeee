extends GutTest
## Area 3 weather and time of day (items 1142 to 1145, 1167 to 1169).

func before_all() -> void:
	Database.load_all()

func _map(raw: Dictionary) -> MapData:
	return MapData.from_dict("t", raw)

func test_same_region_and_block_same_weather() -> void:
	# Item 1142: one roll per region and 6-hour block, the same for everyone.
	var t: int = 1_800_000_000
	assert_eq(WeatherCycle.roll("veydal", "marsh", t), WeatherCycle.roll("veydal", "marsh", t + 3600))
	assert_eq(WeatherCycle.block_of(t), WeatherCycle.block_of(t + 60))
	assert_ne(WeatherCycle.block_of(t), WeatherCycle.block_of(t + WeatherCycle.BLOCK_SECONDS))
	assert_has(WeatherCycle.KINDS, WeatherCycle.roll("corvane", "fern", t))

func test_shares_follow_the_biome() -> void:
	# Item 1143.
	var marsh: Dictionary = WeatherCycle.shares("marsh")
	assert_eq(int(marsh.clear), 40)
	assert_eq(int(marsh.fog), 25)
	assert_false(WeatherCycle.shares("nowhere").is_empty(), "falls back to default")
	var counts: Dictionary = {}
	for i: int in 400:
		var w: String = WeatherCycle.roll("r%d" % i, "marsh", 0)
		counts[w] = int(counts.get(w, 0)) + 1
	assert_false(counts.has("wind"), "no wind in the marsh table")
	assert_gt(int(counts.get("fog", 0)), 40)

func test_switch_caves_and_rooms_stay_clear() -> void:
	# Item 1145.
	var out := _map({"rows": ["..."], "outdoor": true, "biome": "rift", "region": "veydal"})
	var found: bool = false
	for i: int in 50:
		if WeatherCycle.current(out, i * WeatherCycle.BLOCK_SECONDS, true) != "clear":
			found = true
	assert_true(found, "some weather outdoors")
	for i: int in 50:
		assert_eq(WeatherCycle.current(out, i * WeatherCycle.BLOCK_SECONDS, false), "clear")
	var cave := _map({"rows": ["..."], "outdoor": true, "biome": "cave"})
	assert_eq(WeatherCycle.current(cave, 0, true), "clear")
	var room := _map({"rows": ["..."], "outdoor": false, "biome": "town"})
	assert_eq(WeatherCycle.current(room, 0, true), "clear")

func test_weather_switch_in_display_menu() -> void:
	var rows: Array = MenuHost.display_rows().map(func(r: Array) -> String: return str(r[0]))
	assert_has(rows, "weather")
	GameState.weather = false
	var d: Dictionary = GameState.settings_to_dict()
	GameState.weather = true
	assert_false(bool(d.weather))
	GameState.settings_from_dict(d)
	assert_false(GameState.weather, "the switch is saved")
	GameState.weather = true

func test_weather_layer_dots() -> void:
	# Item 1144.
	var layer := WeatherLayer.new()
	add_child_autofree(layer)
	layer.show_kind("rain")
	assert_gt(layer.visible_dots(), 0)
	layer.show_kind("clear")
	assert_eq(layer.visible_dots(), 0)
	layer.show_kind("fog")
	assert_true(layer._veil.visible)

func test_phase_changed_signal() -> void:
	# Item 1167.
	var got: Array = []
	var cb: Callable = func(p: int) -> void: got.append(p)
	DayCycle.events.phase_changed.connect(cb)
	DayCycle._last_phase = DayCycle.Phase.DAY
	assert_false(DayCycle.poll(DayCycle.Phase.DAY))
	assert_true(DayCycle.poll(DayCycle.Phase.NIGHT))
	assert_eq(got, [DayCycle.Phase.NIGHT])
	DayCycle.events.phase_changed.disconnect(cb)
	DayCycle._last_phase = -1

func test_phase_only_npcs_signs_and_blocks() -> void:
	# Item 1168.
	var night := DayCycle.Phase.NIGHT
	var day := DayCycle.Phase.DAY
	assert_true(DayCycle.shows_at({}, night))
	assert_true(DayCycle.shows_at({"phase_only": ["night", "dusk"]}, night))
	assert_false(DayCycle.shows_at({"phase_only": "night"}, day))
	var m := _map({"rows": ["...", "..."], "signs": [{"x": 1, "y": 0, "dialogue": "a/b", "phase_only": "night"}],
		"blocks": [{"x": 2, "y": 1, "open_flag": "never", "phase_only": ["night"]}]})
	assert_true(m.sign_at(Vector2i(1, 0), {"_phase": day}).is_empty())
	assert_false(m.sign_at(Vector2i(1, 0), {"_phase": night}).is_empty())
	m.apply_blocks({"_phase": night})
	assert_eq(m.char_at(Vector2i(2, 1)), "@", "the night gate is shut at night")
	m.apply_blocks({"_phase": day})
	assert_eq(m.char_at(Vector2i(2, 1)), ".", "and open by day")

func test_banner_has_a_phase_icon() -> void:
	# Item 1169.
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	assert_not_null(ow._phase_icon)
	assert_eq(ow._phase_icon.get_parent(), ow._banner)
	assert_not_null(ow.weather_layer)
	ow._on_phase_changed(DayCycle.Phase.NIGHT)
	assert_eq(ow.map.id, GameState.current_map)
