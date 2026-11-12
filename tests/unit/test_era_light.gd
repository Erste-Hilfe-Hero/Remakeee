extends GutTest
## Overworld light, weather look, screen effects and transitions per era (data/era_light.json,
## EraLight, EraLightLayer).

const NIGHT: float = 23.0
const NOON: float = 12.5
const MORNING: float = 7.5
const EVENING: float = 18.5
const BASE_LOOKS: Array[String] = ["rain", "storm", "fog", "wind"]
const SEEDS: int = 40
const STORM_SECONDS: float = 600.0

var _keep: Array[int] = []
var _settings: Dictionary
var _flash: Dictionary

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	_settings = GameState.settings_to_dict()
	_flash = (EraLight.flash_cfg() as Dictionary).duplicate()
	GameState.reduce_motion = false
	GameState.day_night = true

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	GameState.settings_from_dict(_settings)
	EraLight.data()["flash"] = _flash
	EraLight.debug_era = 0
	EraLight.debug_hour = -1.0
	EraLight.debug_weather = ""
	EraLight.debug_month = 0

func _map(raw: Dictionary) -> MapData:
	return MapData.from_dict("t", raw)

func _town(region: String, extra: Dictionary = {}) -> MapData:
	var raw: Dictionary = {"region": region, "outdoor": true, "biome": "town",
		"rows": ["TTTTTTTTTTTT", "T____L_____T", "T..........T", "T....=.....T", "TTTTTTTTTTTT"]}
	raw.merge(extra, true)
	return _map(raw)

func _ctx(look: String, hour: float, extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"look": look, "outdoor": true, "lit": true, "hour": hour, "wooded": true, "lamps": true, "cave": false, "month": 10, "reduced": false}
	c.merge(extra, true)
	return c

func _layer(m: MapData, era: int, weather: String, hour: float) -> EraLightLayer:
	EraLight.debug_era = era
	EraLight.debug_weather = weather
	EraLight.debug_hour = hour
	var layer := EraLightLayer.new()
	add_child_autofree(layer)
	layer.refresh(m, weather)
	return layer

func test_all_five_eras_are_configured() -> void:
	var keys: Array = EraLight.for_era(1).keys()
	assert_gt(keys.size(), 18)
	for e: int in range(1, EraLight.ERAS + 1):
		var row: Dictionary = EraLight.for_era(e)
		for k: Variant in keys:
			assert_true(row.has(k), "era %d has %s" % [e, k])
		for k: String in EraLight.BOOL_KEYS:
			assert_true(row.get(k) is bool, "era %d %s is a switch" % [e, k])
		assert_has(EraLight.TINT_STYLES, str(row.tint_style))
		assert_has(EraLight.WEATHER_STYLES, str(row.weather_style))
		for look: String in BASE_LOOKS:
			assert_has(row.looks as Array, look, "era %d knows %s" % [e, look])
		for w: String in EraLight.WARP_KINDS:
			assert_has(EraLight.TRANSITIONS, EraLight.transition(e, w), "era %d %s" % [e, w])
		assert_has(EraLight.CAVE_EDGES, str(EraLight.cave(e).edge))
		assert_gt(int(EraLight.cave(e).radius), 0)
	assert_eq(EraLight.for_era(9), EraLight.for_era(5), "eras past V use V")

func test_later_eras_keep_what_earlier_eras_have() -> void:
	for e: int in range(2, EraLight.ERAS + 1):
		for k: String in EraLight.BOOL_KEYS:
			if EraLight.on(e - 1, k):
				assert_true(EraLight.on(e, k), "era %d keeps %s" % [e, k])
		for look: Variant in EraLight.for_era(e - 1).looks:
			assert_has(EraLight.for_era(e).looks as Array, look)
		assert_gt(int(EraLight.cave(e).radius), int(EraLight.cave(e - 1).radius), "the cave light grows")

func test_old_regions_keep_their_origin_look() -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = 0
	assert_eq(EraLight.era_for("veydal"), 1)
	assert_eq(EraLight.era_for("vellmarch"), 2)
	assert_eq(EraLight.era_for("quillmarch"), 3)
	assert_eq(EraLight.era_for("halcyra"), 4)
	assert_eq(EraLight.era_for("quivermoor"), 5)
	EraManager.retro_filter = 2
	assert_eq(EraLight.era_for("quivermoor"), 2, "never newer than the active era")

func test_era_one_has_no_day_tint_and_plain_weather() -> void:
	var white := Color(1, 1, 1)
	assert_eq(EraLight.day_tint(1, NIGHT, true), white)
	assert_eq(EraLight.world_tint(1, _town("veydal"), "storm", NIGHT, 10, true), white)
	var fx: Array[String] = EraLight.effects(1, _ctx("rain", NIGHT))
	assert_eq(fx, ["weather_pattern", "weather_text"] as Array[String], "a flat pattern and a line, nothing else")
	assert_eq(EraLight.effects(1, _ctx("clear", NIGHT)), [] as Array[String], "no lit windows, no glow")
	assert_eq(EraLight.transition(1, "door"), "cut")
	assert_eq(EraLight.transition(1, "stairs"), "cut")
	assert_eq(EraLight.transition(1, "edge"), "fade")
	assert_eq(EraLight.weather_look(1, "t", "quillmarch", "route", "wind"), "wind", "no sandstorm before Era III")

func test_era_one_weather_lines_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for look: String in BASE_LOOKS:
		var line: String = EraLight.weather_line(look)
		assert_false(line.is_empty(), look)
		assert_true(de.has(line) and str(de[line]) != line, "German for '%s'" % line)

func test_era_one_cave_is_darker_with_a_hard_light_circle() -> void:
	var cave: MapData = _map({"region": "veydal", "biome": "cave", "rows": ["fff", "fff"]})
	assert_true(EraLight.is_cave(cave))
	assert_lt(EraLight.world_tint(1, cave, "clear", NOON, 10, true).get_luminance(), 0.7)
	assert_eq(str(EraLight.cave(1).edge), "hard")
	assert_eq(float(EraLight.cave(1).dark), 1.0)
	assert_has(EraLight.effects(1, _ctx("clear", NOON, {"outdoor": false, "lit": false, "cave": true})), "cave_light")
	var layer: EraLightLayer = _layer(cave, 1, "", NOON)
	var tex: Texture2D = layer._hole_tex(int(EraLight.cave(1).radius), "hard")
	var img: Image = tex.get_image()
	var mid: int = img.get_width() / 2
	assert_eq(img.get_pixel(mid, mid).a, 0.0, "the middle is lit")
	assert_eq(img.get_pixel(0, 0).a, 1.0, "the rim is dark")

func test_era_two_three_tints_lit_windows_and_rain_lines() -> void:
	var seen: Dictionary = {}
	for hour: float in [MORNING, NOON, EVENING, NIGHT]:
		seen[EraLight.day_tint(2, hour, true).to_html()] = true
	assert_eq(seen.size(), 3, "morning, day and night")
	assert_eq(EraLight.day_tint(2, NIGHT, false), Color(1, 1, 1), "rooms keep their light")
	assert_lt(EraLight.day_tint(2, NIGHT, true).r, EraLight.day_tint(2, NIGHT, true).b, "night is blue")
	var fx: Array[String] = EraLight.effects(2, _ctx("rain", NIGHT))
	assert_has(fx, "weather_lines")
	assert_has(fx, "lit_windows")
	assert_does_not_have(fx, "splashes")
	assert_does_not_have(fx, "lamp_glow")
	assert_does_not_have(EraLight.effects(2, _ctx("clear", NOON)), "lit_windows")

func test_era_three_rich_weather_and_wipes() -> void:
	var rain: Array[String] = EraLight.effects(3, _ctx("rain", NOON))
	for k: String in ["weather_rich", "splashes", "puddles"]:
		assert_has(rain, k)
	assert_has(EraLight.effects(3, _ctx("fog", NOON)), "fog_bands")
	assert_has(EraLight.effects(3, _ctx("storm", NOON)), "lightning")
	assert_eq(EraLight.weather_look(3, "drypoint_lane", "quillmarch", "route", "wind"), "sandstorm")
	assert_eq(EraLight.weather_look(3, "mordant_row", "quillmarch", "town", "fog"), "ash")
	assert_eq(EraLight.weather_look(3, "ledgerholm", "quillmarch", "town", "fog"), "fog")
	assert_eq(EraLight.weather_look(3, "white_stair", "halcyra", "town", "rain"), "rain", "snow waits for Era IV")
	assert_eq(EraLight.transition(3, "door"), "door_wipe")
	assert_eq(EraLight.transition(3, "stairs"), "stair_wipe")
	assert_eq(EraLight.warp_kind(TilesetFactory.Kind.STAIRS, false), "stairs")
	assert_eq(EraLight.warp_kind(TilesetFactory.Kind.DOOR, false), "door")
	assert_eq(EraLight.warp_kind(TilesetFactory.Kind.PATH, true), "edge")

func test_lightning_never_passes_three_flashes_a_second() -> void:
	assert_lte(EraLight.max_flashes(), EraLight.HARD_MAX_FLASHES)
	assert_eq(EraLight.HARD_MAX_FLASHES, 3)
	for s: int in SEEDS:
		var times: Array[float] = EraLight.strike_times(s, STORM_SECONDS)
		assert_gt(times.size(), 10, "a storm has lightning")
		assert_lte(EraLight.worst_second(times), EraLight.max_flashes(), "seed %d" % s)
	assert_false(EraLight.flash_allowed([9.2, 9.5, 9.8] as Array[float], 10.0, false), "three in the last second")
	assert_false(EraLight.flash_allowed([9.9] as Array[float], 10.0, false), "inside the gap")
	assert_true(EraLight.flash_allowed([8.0] as Array[float], 10.0, false))

func test_flash_cap_holds_against_bad_data() -> void:
	EraLight.data()["flash"] = {"max_per_second": 99, "min_gap": 0.0, "length": 0.07, "alpha": 1.0, "strike_every": 0.01, "double_share": 1.0}
	assert_eq(EraLight.max_flashes(), 3)
	assert_lte(EraLight.worst_second(EraLight.strike_times(1, 30.0)), 3)
	var layer: EraLightLayer = _layer(_town("quillmarch"), 3, "storm", NOON)
	var frame: float = 1.0 / 60.0
	for i: int in 600:
		layer._t += frame
		layer.try_flash()
	assert_lte(EraLight.worst_second(layer.flash_times), 3, "sixty tries a second still give three")

func test_reduced_motion_switches_flashes_wipes_and_sweeps_off() -> void:
	GameState.reduce_motion = true
	assert_false(EraLight.flash_allowed([] as Array[float], 10.0, true))
	assert_eq(EraLight.strike_times(3, STORM_SECONDS, true), [] as Array[float])
	assert_does_not_have(EraLight.effects(5, _ctx("storm", NOON, {"reduced": true})), "lightning")
	var layer: EraLightLayer = _layer(_town("quillmarch"), 3, "storm", NOON)
	assert_does_not_have(layer.fx, "lightning")
	assert_false(layer.try_flash())
	var fade := ColorRect.new()
	add_child_autofree(fade)
	fade.color.a = 0.0
	assert_false(await layer.warp_out(TilesetFactory.Kind.DOOR, false, "up", fade), "the plain fade of the overworld is used")
	assert_eq(layer.wipe_style, "")
	var before: float = layer._t
	await wait_process_frames(3)
	assert_eq(layer._t, before, "weather stands still")
	var big: EraLightLayer = _layer(_town("quivermoor", {"rows": _rows(12, 20)}), 5, "", NOON)
	assert_false(big.sweeping)

func _rows(w: int, h: int) -> Array:
	var out: Array = []
	for y: int in h:
		out.append("T".repeat(w) if y == 0 else "_".repeat(w))
	return out

func test_era_four_snow_prints_shafts_glow_and_cloud_shadows() -> void:
	assert_eq(EraLight.weather_look(4, "white_stair", "halcyra", "town", "rain"), "snow")
	assert_eq(EraLight.weather_look(4, "brightledge", "halcyra", "town", "rain"), "rain")
	var day: Array[String] = EraLight.effects(4, _ctx("clear", NOON))
	assert_has(day, "light_shafts")
	assert_has(day, "cloud_shadows")
	assert_does_not_have(day, "lamp_glow")
	assert_does_not_have(EraLight.effects(4, _ctx("clear", NOON, {"wooded": false})), "light_shafts")
	var night: Array[String] = EraLight.effects(4, _ctx("clear", NIGHT))
	assert_has(night, "lamp_glow")
	assert_does_not_have(night, "cloud_shadows")
	assert_does_not_have(night, "long_shadows", "long shadows wait for Era V")
	var layer: EraLightLayer = _layer(_town("halcyra"), 4, "snow", NOON)
	assert_has(layer.fx, "snow_prints")
	assert_true(layer.note_step(Vector2i(2, 2), "down"))
	assert_false(layer.note_step(Vector2i(0, 0), "down"), "no prints on a tree")
	for i: int in EraLightLayer.MAX_PRINTS + 5:
		layer.note_step(Vector2i(3, 2), "left")
	assert_eq(layer.prints.size(), EraLightLayer.MAX_PRINTS)
	var dry: EraLightLayer = _layer(_town("halcyra"), 4, "", NOON)
	assert_false(dry.note_step(Vector2i(2, 2), "down"), "prints need snow")

func test_era_five_golden_hour_long_shadows_seasons_and_particles() -> void:
	var gold: Color = EraLight.day_tint(5, EVENING, true)
	assert_gt(gold.r, gold.b, "the golden hour is warm")
	assert_ne(EraLight.day_tint(5, 17.5, true), EraLight.day_tint(5, 18.0, true), "the light moves with the hour")
	assert_eq(EraLight.day_tint(5, NOON, true), Color(1, 1, 1))
	assert_gt(EraLight.golden(EVENING), 0.5)
	assert_eq(EraLight.golden(NOON), 0.0)
	assert_gt(EraLight.shadow(EVENING).length(), EraLight.shadow(NOON).length() * 2.0, "long shadows late in the day")
	assert_lt(EraLight.shadow(MORNING).x, 0.0, "westward in the morning")
	assert_gt(EraLight.shadow(EVENING).x, 0.0, "eastward in the evening")
	assert_eq(EraLight.shadow(NIGHT), Vector2.ZERO)
	var tints: Dictionary = {}
	for month: int in [4, 7, 10, 1]:
		tints[EraLight.season_tint(5, "quivermoor", month).to_html()] = true
		assert_ne(EraLight.season_tint(5, "quivermoor", month), EraLight.season_tint(5, "halcyra", month), "the region has its own seasons")
		assert_eq(EraLight.season_tint(4, "quivermoor", month), Color(1, 1, 1), "no season tint before Era V")
	assert_eq(tints.size(), 4)
	var evening: Array[String] = EraLight.effects(5, _ctx("clear", EVENING))
	for k: String in ["golden_hour", "long_shadows", "leaves", "lamp_glow", "embers", "light_shafts"]:
		assert_has(evening, k)
	assert_has(EraLight.effects(5, _ctx("clear", NOON, {"month": 5})), "pollen")
	assert_does_not_have(EraLight.effects(5, _ctx("rain", NOON, {"month": 5})), "pollen")

func test_era_five_camera_sweeps_into_a_big_place_once() -> void:
	var cam := Camera2D.new()
	add_child_autofree(cam)
	var walker := GridWalker.new()
	add_child_autofree(walker)
	var big: MapData = _town("quivermoor", {"rows": _rows(12, 20)})
	assert_true(EraLight.is_big_place(big))
	assert_false(EraLight.is_big_place(_town("quivermoor")), "a small place")
	EraLight.debug_era = 5
	EraLight.debug_hour = NOON
	var layer := EraLightLayer.new()
	layer.setup(walker, cam)
	add_child_autofree(layer)
	layer.refresh(big, "clear")
	assert_true(layer.sweeping)
	layer._sweep(0.1)
	assert_ne(cam.offset, Vector2.ZERO)
	layer._sweep(EraLightLayer.SWEEP_TIME)
	assert_eq(cam.offset, Vector2.ZERO, "the camera ends on the Wayfarer")
	assert_false(layer.sweeping)
	layer._map_id = ""
	layer.refresh(big, "clear")
	assert_false(layer.sweeping, "only the first visit")
	EraLight.debug_era = 4
	var old := EraLightLayer.new()
	old.setup(walker, cam)
	add_child_autofree(old)
	old.refresh(big, "clear")
	assert_false(old.sweeping, "no sweep before Era V")

func test_transitions_cut_in_era_one_and_wipe_in_era_three() -> void:
	var fade := ColorRect.new()
	add_child_autofree(fade)
	fade.color.a = 0.0
	var one: EraLightLayer = _layer(_town("veydal"), 1, "", NOON)
	assert_true(await one.warp_out(TilesetFactory.Kind.DOOR, false, "up", fade))
	assert_eq(fade.color.a, 1.0, "a cut")
	one._map_id = ""
	one.refresh(_town("veydal"), "clear")
	assert_eq(fade.color.a, 0.0, "the next map shows at once")
	var three: EraLightLayer = _layer(_town("quillmarch"), 3, "", NOON)
	assert_true(await three.warp_out(TilesetFactory.Kind.STAIRS, false, "up", fade))
	assert_eq(three.wipe_style, "stair_wipe")
	assert_eq(three.wipe_k, 1.0)
	assert_true(three.wipe_up)
	var two: EraLightLayer = _layer(_town("vellmarch"), 2, "", NOON)
	assert_false(await two.warp_out(TilesetFactory.Kind.DOOR, false, "up", fade), "Era II keeps the overworld's own")

func test_overworld_shows_every_era() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.set_flag("got_starter")
	GameState.current_map = "brindlewick"
	GameState.player_cell = Vector2i(5, 8)
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	assert_not_null(ow._era_light)
	assert_false(ow.weather_layer.visible, "the era layer draws the weather")
	EraLight.debug_hour = NIGHT
	for e: int in range(1, EraLight.ERAS + 1):
		EraLight.debug_era = e
		for w: String in ["storm", "fog", "wind", "clear"]:
			EraLight.debug_weather = w
			ow.refresh_daylight()
			await wait_process_frames(2)
			assert_eq(ow._era_light.era, e)
		if ow.map.outdoor:
			assert_eq(ow._daylight.color == Color(1, 1, 1), e == 1, "era %d night tint" % e)
			assert_eq(ow._glow.visible, e > 1 and not WindowGlow.window_cells(ow.map).is_empty(), "era %d windows" % e)
