extends GutTest
## The weather system of 1.3.2 (data/weather.json "grades", "names", "fx"; WeatherCycle, WeatherFx,
## EraLightLayer, WeatherIcon): the cycle with strength, grades, forecast and wetness, fades
## between weathers, no weather indoors and in caves, the "Weather effects" setting, snow on
## scree in the cold months, and that the rules the battle reads did not move.

const NOON: float = 12.5
const B: int = WeatherCycle.BLOCK_SECONDS

var _keep: Array[int] = []
var _settings: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	_settings = GameState.settings_to_dict()
	GameState.reduce_motion = false
	GameState.day_night = true
	GameState.weather = true
	GameState.weather_fx = "full"
	GameState.battery_saver = false

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	GameState.settings_from_dict(_settings)
	EraLight.debug_era = 0
	EraLight.debug_hour = -1.0
	EraLight.debug_weather = ""
	EraLight.debug_month = 0
	WeatherCycle.debug_strength = -1.0
	WeatherCycle.debug_wet = -1.0

func _map(raw: Dictionary, id: String = "t") -> MapData:
	return MapData.from_dict(id, raw)

func _town(region: String = "quillmarch", extra: Dictionary = {}, id: String = "t") -> MapData:
	var raw: Dictionary = {"region": region, "outdoor": true, "biome": "town",
		"rows": ["TTTTTTTTTTTT", "T____L_____T", "T..~~......T", "T.,,.=.....T", "T__________T", "TTTTTTTTTTTT"]}
	raw.merge(extra, true)
	return _map(raw, id)

func _layer(m: MapData, era: int, weather: String) -> EraLightLayer:
	EraLight.debug_era = era
	EraLight.debug_weather = weather
	EraLight.debug_hour = NOON
	var layer := EraLightLayer.new()
	add_child_autofree(layer)
	layer.refresh(m, weather)
	return layer

## Start time of the first block where the sky over [param m] is wet or not ([param wet_now]) after
## a block that was wet or not ([param wet_before]); with [param clear_now] it must be clear.
## -1 when 4000 blocks hold none.
func _block(m: MapData, wet_now: bool, wet_before: bool, clear_now: bool = false) -> int:
	for i: int in range(1, 4000):
		var k: String = WeatherCycle.current(m, i * B, true)
		if (k in WeatherCycle.WET) != wet_now or (clear_now and k != "clear"):
			continue
		if (WeatherCycle.current(m, (i - 1) * B, true) in WeatherCycle.WET) == wet_before:
			return i * B
	return -1

# --- The cycle ------------------------------------------------------------------------------

func test_kinds_and_the_public_cycle_did_not_move() -> void:
	assert_eq(WeatherCycle.KINDS, ["clear", "rain", "fog", "wind", "storm"] as Array[String])
	assert_eq(WeatherCycle.BLOCK_SECONDS, 6 * 3600)
	var m: MapData = _town()
	for i: int in 40:
		var k: String = WeatherCycle.current(m, i * B, true)
		assert_has(WeatherCycle.KINDS, k)
		assert_eq(k, WeatherCycle.roll(m.region, m.biome, i * B), "current is the roll of the region and biome")
		assert_eq(str(WeatherCycle.state(m, i * B, true).kind), k, "state carries the same kind")

func test_battle_fields_did_not_move() -> void:
	assert_eq(str(WeatherCycle.battle_field("rain").field), "high_tide")
	assert_eq(str(WeatherCycle.battle_field("fog").field), "deep_murk")
	assert_eq(str(WeatherCycle.battle_field("storm").field), "static_veil")
	assert_true(WeatherCycle.battle_field("wind").is_empty())
	assert_true(WeatherCycle.battle_field("clear").is_empty())
	# A grade is a look and a name only: a drizzle is rain to the rules.
	WeatherCycle.debug_strength = 0.1
	assert_eq(str(WeatherCycle.grade("rain", 0.1).id), "drizzle")
	assert_eq(str(WeatherCycle.battle_field("rain").field), "high_tide")

func test_strength_is_one_roll_per_region_and_block() -> void:
	var t: int = 1_800_000_000
	assert_eq(WeatherCycle.strength("veydal", t), WeatherCycle.strength("veydal", t + 600))
	var seen: Dictionary = {}
	for i: int in 60:
		var s: float = WeatherCycle.strength("veydal", i * B)
		assert_between(s, 0.0, 1.0)
		seen[snappedf(s, 0.01)] = true
	assert_gt(seen.size(), 20, "the strength changes from block to block")
	assert_ne(WeatherCycle.strength("veydal", t), WeatherCycle.strength("corvane", t), "each region rolls its own")

func test_grades_name_the_strength() -> void:
	assert_eq(str(WeatherCycle.grade("rain", 0.0).id), "drizzle")
	assert_eq(str(WeatherCycle.grade("rain", 0.5).id), "rain")
	assert_eq(str(WeatherCycle.grade("rain", 1.0).id), "downpour")
	assert_eq(str(WeatherCycle.grade("fog", 0.9).id), "thick_fog")
	assert_eq(str(WeatherCycle.grade("wind", 0.9).id), "gale")
	assert_eq(str(WeatherCycle.grade("clear", 0.5).id), "clear", "a kind without grades is its own grade")
	assert_lt(float(WeatherCycle.grade("rain", 0.1).amount), float(WeatherCycle.grade("rain", 0.5).amount))
	assert_lt(float(WeatherCycle.grade("rain", 0.5).amount), float(WeatherCycle.grade("rain", 0.95).amount))
	var grades: Dictionary = WeatherCycle.data().get("grades", {})
	var names: Dictionary = WeatherCycle.data().get("names", {})
	for kind: String in grades:
		assert_has(WeatherCycle.KINDS, kind)
		var rows: Array = grades[kind]
		assert_eq(float((rows.back() as Dictionary).upto), 1.0, "%s grades reach strength 1" % kind)
		var last: float = -1.0
		for g: Dictionary in rows:
			assert_gt(float(g.upto), last, "%s grades climb" % kind)
			last = float(g.upto)
			assert_true(names.has(str(g.id)), "grade %s has a name" % g.id)
	for kind: String in WeatherCycle.KINDS:
		assert_true(names.has(kind), "kind %s has a name" % kind)

func test_forecast_is_the_roll_of_the_next_blocks() -> void:
	var m: MapData = _town()
	var t: int = 77 * B + 500
	var f: Array[String] = WeatherCycle.forecast(m, 3, t, true)
	assert_eq(f.size(), 3)
	for i: int in 3:
		assert_eq(f[i], WeatherCycle.current(m, t + (i + 1) * B, true))
	assert_eq(WeatherCycle.seconds_left(t), B - 500)
	var room: MapData = _map({"rows": ["fff"], "outdoor": false, "biome": "town"})
	assert_eq(WeatherCycle.forecast(room, 2, t, true), ["clear", "clear"] as Array[String], "no forecast under a roof")
	assert_eq(WeatherCycle.forecast(m, 2, t, false), ["clear", "clear"] as Array[String], "none with weather off")

func test_ground_gets_wet_in_rain_and_dries_after_it() -> void:
	var m: MapData = _town("veydal", {"biome": "marsh"})
	var cfg: Dictionary = WeatherFx.cfg().puddles
	var start: int = _block(m, true, false)
	assert_gt(start, 0, "a wet block after a dry one exists")
	assert_eq(WeatherCycle.wetness(m, start, true), 0.0, "dry when the rain starts")
	assert_almost_eq(WeatherCycle.wetness(m, start + int(cfg.form_seconds) / 2, true), 0.5, 0.02)
	assert_eq(WeatherCycle.wetness(m, start + int(cfg.form_seconds) + 5, true), 1.0, "puddles have formed")
	var on: int = _block(m, true, true)
	assert_gt(on, 0)
	assert_eq(WeatherCycle.wetness(m, on, true), 1.0, "rain after rain stays wet")
	var after: int = _block(m, false, true, true)
	assert_gt(after, 0, "a clear block after a wet one exists")
	assert_eq(WeatherCycle.wetness(m, after, true), 1.0, "still wet when the sky clears")
	assert_almost_eq(WeatherCycle.wetness(m, after + int(cfg.dry_seconds) / 2, true), 0.5, 0.02)
	assert_eq(WeatherCycle.wetness(m, after + int(cfg.dry_seconds) + 5, true), 0.0, "dry again")
	assert_true(WeatherCycle.after_rain(m, after + 30, true), "a rainbow can stand right after rain")
	assert_false(WeatherCycle.after_rain(m, after + int(WeatherFx.cfg().rainbow_seconds) + 5, true))
	assert_false(WeatherCycle.after_rain(m, start + 30, true), "not while it rains")
	assert_eq(WeatherCycle.wetness(m, start + 4000, false), 0.0, "weather off: always dry")

# --- Indoors and in caves -------------------------------------------------------------------

func test_rooms_caves_and_dungeons_have_no_weather() -> void:
	var places: Array[MapData] = [
		_map({"rows": ["fff", "fff"], "outdoor": false, "biome": "town", "region": "quillmarch"}),
		_map({"rows": ["...", "..."], "outdoor": true, "biome": "cave", "region": "quillmarch"}),
		_map({"rows": ["...", "..."], "outdoor": true, "biome": "dungeon", "region": "quillmarch"}),
	]
	for m: MapData in places:
		for i: int in 60:
			var st: Dictionary = WeatherCycle.state(m, i * B, true)
			assert_eq(str(st.kind), "clear")
			assert_eq(str(st.grade), "clear")
			assert_eq(WeatherCycle.wetness(m, i * B + 100, true), 0.0)
			assert_false(WeatherCycle.after_rain(m, i * B + 100, true))
		assert_eq(EraLight.weather_name(m), "Clear")

func test_the_layer_draws_nothing_indoors_even_when_it_storms_outside() -> void:
	var room: MapData = _map({"rows": ["fff", "fff"], "outdoor": false, "biome": "town", "region": "quillmarch"})
	var cave: MapData = _map({"rows": ["...", "..."], "outdoor": true, "biome": "cave", "region": "quillmarch"}, "c")
	EraLight.debug_era = 5
	EraLight.debug_hour = NOON
	WeatherCycle.debug_wet = 1.0
	for m: MapData in [room, cave]:
		var layer := EraLightLayer.new()
		add_child_autofree(layer)
		# The overworld hands over the sky of the map itself.
		layer.refresh(m, WeatherCycle.current(m, 5 * B, true))
		assert_eq(layer.look, "clear")
		assert_eq(layer.wet_to, 0.0, "no puddles under a roof")
		assert_eq(layer.wet, 0.0)
		for name: String in ["weather_rich", "splashes", "puddles", "fog_bands", "lightning", "rainbow", "snow_prints"]:
			assert_does_not_have(layer.fx, name)
		var icon := WeatherIcon.new()
		add_child_autofree(icon)
		icon.show_for(m)
		assert_false(icon.visible, "no weather symbol indoors")

func test_overworld_room_stays_clear_under_a_storm() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.set_flag("got_starter")
	var inside: MapData = null
	for id: String in ["driftwick_pole_house", "copperfold_house", "corvane_quay_house"]:
		inside = MapData.load_map(id)
		if inside != null and not inside.outdoor:
			break
	assert_not_null(inside)
	assert_false(inside.outdoor)
	GameState.current_map = inside.id
	GameState.player_cell = Vector2i(1, 1)
	EraLight.debug_era = 5
	EraLight.debug_weather = "storm"
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(3)
	assert_eq(ow._era_light.look, "clear", "a storm set for the outdoors does not reach the room")
	assert_eq(ow._era_light.wet, 0.0)
	assert_does_not_have(ow._era_light.fx, "weather_rich")
	assert_false(ow._weather_icon.visible)
	MusicDirector.update_world(true, false, 0.0)

# --- Fades ----------------------------------------------------------------------------------

func test_one_weather_fades_into_the_next() -> void:
	var m: MapData = _town()
	var layer: EraLightLayer = _layer(m, 3, "rain")
	assert_eq(layer.look, "rain")
	assert_eq(layer.mix, 1.0, "a new map shows its sky at once")
	assert_eq(layer.from_look, "clear")
	assert_eq(layer.wet, 1.0, "and its puddles")
	EraLight.debug_weather = "fog"
	layer.refresh(m, "fog")
	assert_eq(layer.look, "fog", "the look is the new one from the start")
	assert_eq(layer.from_look, "rain", "the old one fades out")
	assert_eq(layer.mix, 0.0)
	assert_eq(layer.wet, 1.0, "the ground does not dry in a blink")
	assert_eq(layer.wet_to, 0.0)
	layer._process(WeatherFx.fade_seconds() * 0.5)
	assert_almost_eq(layer.mix, 0.5, 0.01)
	assert_eq(layer.from_look, "rain")
	assert_lt(layer.wet, 1.0)
	assert_gt(layer.wet, 0.9, "drying takes minutes, not seconds")
	layer._process(WeatherFx.fade_seconds() * 0.6)
	assert_eq(layer.mix, 1.0)
	assert_eq(layer.from_look, "clear", "the old sky is gone")
	layer._process(float(WeatherFx.cfg().puddles.dry_seconds) + 1.0)
	assert_eq(layer.wet, 0.0, "and at last the ground is dry")

func test_fade_to_clear_and_back() -> void:
	var m: MapData = _town()
	var layer: EraLightLayer = _layer(m, 4, "storm")
	EraLight.debug_weather = "clear"
	layer.refresh(m, "clear")
	assert_eq(layer.look, "clear")
	assert_eq(layer.from_look, "storm")
	assert_eq(layer.mix, 0.0)
	layer._process(1.0)
	assert_between(layer.mix, 0.01, 0.99)
	# The same sky again does not restart the fade.
	var before: float = layer.mix
	layer.refresh(m, "clear")
	assert_eq(layer.mix, before)

func test_a_new_map_and_reduced_motion_do_not_fade() -> void:
	var a: MapData = _town("quillmarch", {}, "a")
	var b: MapData = _town("quillmarch", {}, "b")
	var layer: EraLightLayer = _layer(a, 3, "rain")
	EraLight.debug_weather = "fog"
	layer.refresh(b, "fog")
	assert_eq(layer.mix, 1.0, "the next map shows its own sky at once")
	assert_eq(layer.from_look, "clear")
	assert_eq(layer.wet, 0.0)
	GameState.reduce_motion = true
	EraLight.debug_weather = "rain"
	layer.refresh(b, "rain")
	assert_eq(layer.mix, 1.0, "no fade with Less motion")
	assert_eq(layer.wet, 1.0)
	var t: float = layer._t
	layer._process(0.5)
	assert_eq(layer._t, t, "and the drops stand still")

func test_the_world_tint_goes_dark_under_clouds() -> void:
	var m: MapData = _town()
	for era: int in range(2, EraLight.ERAS + 1):
		var clear: Color = EraLight.world_tint(era, m, "clear", NOON, 6, true)
		var rain: Color = EraLight.world_tint(era, m, "rain", NOON, 6, true)
		var storm: Color = EraLight.world_tint(era, m, "storm", NOON, 6, true)
		assert_lt(rain.get_luminance(), clear.get_luminance(), "era %d rain is darker than a clear day" % era)
		assert_lt(storm.get_luminance(), rain.get_luminance(), "era %d storm is darker than rain" % era)
		assert_lt(EraLight.world_tint(era, m, "storm", 23.0, 6, true).get_luminance(), storm.get_luminance(), "era %d: darker still at night" % era)

func test_thunder_follows_the_flash() -> void:
	var layer: EraLightLayer = _layer(_town(), 3, "storm")
	assert_has(layer.fx, "lightning")
	assert_lt(layer.thunder_at, 0.0)
	Sound.last_sfx = ""
	assert_true(layer.try_flash())
	assert_gt(layer.thunder_at, layer._t, "the thunder waits a moment")
	var due: float = layer.thunder_at
	layer._flash_left = 0.0
	layer.flash_times.clear()
	layer._next_strike = 9999.0
	layer._process(due - layer._t + 0.05)
	assert_eq(Sound.last_sfx, str(WeatherFx.cfg().thunder.sfx))
	assert_lt(layer.thunder_at, 0.0, "one thunder per flash")
	assert_true(ResourceLoader.exists(Sound.SFX_DIR % Sound.sfx_file(str(WeatherFx.cfg().thunder.sfx))), "the thunder sound exists")

# --- Looks ----------------------------------------------------------------------------------

func test_snow_on_scree_in_the_cold_months() -> void:
	assert_eq(EraLight.weather_look(4, "t", "halcyra", "scree", "rain", 1), "snow")
	assert_eq(EraLight.weather_look(5, "t", "quivermoor", "scree", "storm", 12), "snow")
	assert_eq(EraLight.weather_look(4, "t", "halcyra", "scree", "rain", 7), "rain", "summer rain stays rain")
	assert_eq(EraLight.weather_look(4, "t", "halcyra", "scree", "fog", 1), "fog")
	assert_eq(EraLight.weather_look(4, "t", "halcyra", "town", "rain", 1), "rain", "only on the slopes")
	assert_eq(EraLight.weather_look(3, "t", "quillmarch", "scree", "rain", 1), "rain", "snow waits for Era IV")
	EraLight.debug_month = 1
	assert_eq(EraLight.weather_look(4, "t", "halcyra", "scree", "rain"), "snow", "without a month the calendar decides")
	EraLight.debug_month = 7
	assert_eq(EraLight.weather_look(4, "t", "halcyra", "scree", "rain"), "rain")

func test_snow_settles_and_names_itself() -> void:
	EraLight.debug_month = 1
	var m: MapData = _town("halcyra", {"biome": "scree"})
	var layer: EraLightLayer = _layer(m, 4, "rain")
	assert_eq(layer.look, "snow")
	assert_eq(layer.wet_to, 1.0, "snow lies")
	assert_has(layer.fx, "snow_prints")
	assert_does_not_have(layer.fx, "puddles")
	assert_true(layer.note_step(Vector2i(2, 1), "up"))
	EraLight.debug_era = 4
	WeatherCycle.debug_strength = 0.5
	var snowy: int = -1
	for i: int in range(1, 400):
		if WeatherCycle.current(m, i * B, true) == "rain":
			snowy = i * B
			break
	assert_gt(snowy, 0)
	assert_eq(EraLight.weather_name(m, snowy), "Snow")
	EraLight.debug_month = 7
	assert_eq(EraLight.weather_name(m, snowy), "Rain")
	WeatherCycle.debug_strength = 0.1
	assert_eq(EraLight.weather_name(m, snowy), "Drizzle")

func test_rainbow_after_rain_by_day_only() -> void:
	var ctx: Dictionary = {"look": "clear", "outdoor": true, "lit": true, "hour": NOON, "wooded": false, "lamps": false, "cave": false, "month": 6, "reduced": false, "after_rain": true}
	assert_has(EraLight.effects(3, ctx), "rainbow")
	assert_has(EraLight.effects(5, ctx), "rainbow")
	assert_does_not_have(EraLight.effects(2, ctx), "rainbow", "from the era with puddles on")
	var night: Dictionary = ctx.duplicate()
	night.hour = 23.0
	assert_does_not_have(EraLight.effects(5, night), "rainbow")
	var raining: Dictionary = ctx.duplicate()
	raining.look = "rain"
	assert_does_not_have(EraLight.effects(5, raining), "rainbow")
	var dry: Dictionary = ctx.duplicate()
	dry.after_rain = false
	assert_does_not_have(EraLight.effects(5, dry), "rainbow")
	var inside: Dictionary = ctx.duplicate()
	inside.outdoor = false
	assert_does_not_have(EraLight.effects(5, inside), "rainbow")
	# On the layer: a clear sky over wet ground shows it.
	WeatherCycle.debug_wet = 0.8
	var layer: EraLightLayer = _layer(_town(), 3, "clear")
	assert_has(layer.fx, "rainbow")
	assert_eq(layer.wet, 0.8)

# --- Settings -------------------------------------------------------------------------------

func test_weather_effects_setting_is_saved_and_reset() -> void:
	var rows: Array = MenuHost.display_rows().map(func(r: Array) -> String: return str(r[0]))
	assert_has(rows, "weather_fx")
	assert_has(rows, "weather", "the weather switch is still there")
	assert_true(MenuHost.SETTING_HINTS.has("weather_fx"), "the row explains itself")
	assert_eq(WeatherCycle.FX_LEVELS, ["full", "low", "off"] as Array[String])
	for level: String in WeatherCycle.FX_LEVELS:
		GameState.weather_fx = level
		var d: Dictionary = GameState.settings_to_dict()
		GameState.weather_fx = "full"
		GameState.settings_from_dict(d)
		assert_eq(GameState.weather_fx, level, "%s is saved" % level)
		assert_true(WeatherCycle.FX_LEVEL_NAMES.has(level))
	GameState.settings_from_dict({"weather_fx": "plenty"})
	assert_eq(GameState.weather_fx, "full", "an unknown level falls back to full")
	GameState.settings_from_dict({})
	assert_eq(GameState.weather_fx, "full", "an old settings file starts at full")
	GameState.weather_fx = "off"
	assert_true(SettingsReset.reset("display"))
	assert_eq(GameState.weather_fx, "full", "Reset to default brings it back")

func test_weather_effects_row_cycles_through_the_levels() -> void:
	var texts: Array[String] = []
	for level: String in WeatherCycle.FX_LEVELS:
		GameState.weather_fx = level
		for r: Array in MenuHost.display_rows():
			if str(r[0]) == "weather_fx":
				texts.append(str(r[1]))
	assert_eq(texts, ["Weather effects: Full", "Weather effects: Low", "Weather effects: Off"] as Array[String])

func test_weather_effects_row_fits_in_every_language_at_every_level() -> void:
	# The width test_ux_text allows a settings row (ROW_TEXT_WIDTH); here for all three levels.
	var keep: String = Loc.language()
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		for level: String in WeatherCycle.FX_LEVELS:
			var shown: String = Loc.t("Weather effects: %s" % WeatherCycle.FX_LEVEL_NAMES[level])
			var w: float = PixelFont.get_font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x
			assert_lte(w, 115.0, "%s row too wide (%d px): %s" % [lang, int(w), shown])
	Loc.set_language(keep)

func test_battery_saver_caps_the_level_at_low() -> void:
	GameState.weather_fx = "full"
	assert_eq(WeatherCycle.fx_level(), "full")
	GameState.battery_saver = true
	assert_eq(WeatherCycle.fx_level(), "low")
	GameState.weather_fx = "off"
	assert_eq(WeatherCycle.fx_level(), "off", "off stays off")

func test_level_off_keeps_the_weather_but_draws_none() -> void:
	var m: MapData = _town()
	GameState.weather_fx = "off"
	var layer: EraLightLayer = _layer(m, 4, "storm")
	assert_eq(layer.look, "storm", "the sky is still a storm")
	for name: String in ["weather_rich", "splashes", "puddles", "lightning"]:
		assert_does_not_have(layer.fx, name)
	assert_false(layer._draws_weather())
	assert_eq(layer.wx.density, 0.0)
	assert_false(layer.try_flash() and "lightning" in layer.fx)
	# The rules do not look at the setting.
	assert_eq(str(WeatherCycle.battle_field("storm").field), "static_veil")
	var tint_off: Color = EraLight.world_tint(4, m, layer.look, NOON, 6, true)
	GameState.weather_fx = "full"
	var full: EraLightLayer = _layer(m, 4, "storm")
	for name: String in ["weather_rich", "splashes", "puddles", "lightning"]:
		assert_has(full.fx, name)
	assert_eq(EraLight.world_tint(4, m, full.look, NOON, 6, true), tint_off, "the cloud tint is the same at every level")

func test_low_draws_half_and_no_splashes() -> void:
	var m: MapData = _town()
	var full := WeatherFx.new()
	full.setup(m, 4, "full")
	var low := WeatherFx.new()
	low.setup(m, 4, "low")
	var off := WeatherFx.new()
	off.setup(m, 4, "off")
	var l: WeatherFx.Look = full.look_of("rain")
	for layer: int in l.n.size():
		assert_gt(full.sheet_count(l, layer, 1.0), low.sheet_count(l, layer, 1.0), "layer %d" % layer)
		assert_gt(low.sheet_count(l, layer, 1.0), 0)
		assert_eq(off.sheet_count(l, layer, 1.0), 0)
	assert_true(low.low)
	assert_false(full.low)
	assert_eq(WeatherFx.density_of("low"), 0.5)

func test_era_one_still_shows_the_line_only() -> void:
	# Owner 25.11.2026: no weather over the Era I map. The ink look is in the code, not switched on.
	var layer: EraLightLayer = _layer(_town("veydal"), 1, "rain")
	assert_eq(layer.fx, ["weather_text"] as Array[String])
	assert_false(layer._draws_weather())

# --- The painter ----------------------------------------------------------------------------

func test_fx_data_is_whole() -> void:
	var cfg: Dictionary = WeatherFx.cfg()
	assert_gt(float(cfg.fade_seconds), 1.0, "a fade over seconds, not a hard switch")
	for level: String in WeatherCycle.FX_LEVELS:
		assert_true((cfg.density as Dictionary).has(level))
	for name: String in ["rain", "storm", "snow"]:
		var layers: Array = cfg.looks[name].layers
		assert_eq(layers.size(), 3, "%s has three depths" % name)
		for i: int in layers.size():
			assert_eq((layers[i] as Array).size(), 4)
			if i > 0:
				assert_gt(float(layers[i][3]), float(layers[i - 1][3]), "%s: nearer drops fall faster" % name)
				assert_lt(float(layers[i][0]), float(layers[i - 1][0]), "%s: and are fewer" % name)
	for i: int in 3:
		assert_gt(float(cfg.looks.storm.layers[i][0]), float(cfg.looks.rain.layers[i][0]), "a storm is denser than rain")
		assert_gt(absf(float(cfg.looks.storm.layers[i][2])), absf(float(cfg.looks.rain.layers[i][2])), "and blown further sideways")
	assert_eq((cfg.looks.fog.banks as Array).size(), 3, "fog banks in three layers")
	for era: int in range(1, EraLight.ERAS + 1):
		assert_true((cfg.eras as Dictionary).has(str(era)), "era %d has its colours" % era)
	for era: int in range(2, EraLight.ERAS + 1):
		var row: Dictionary = cfg.eras[str(era)]
		for key: String in ["rain", "snow", "leaf", "fog", "veil", "puddle", "puddle_rim", "shine", "splash", "ripple", "streak", "gust", "cloud"]:
			assert_true(row.has(key), "era %d %s" % [era, key])

func test_mobile_budget() -> void:
	# The whole of a storm on the largest screen: three sheets, and splashes within a fixed cap.
	var wx := WeatherFx.new()
	wx.setup(_town(), 5, "full")
	wx.set_view(Vector2(480, 1040))
	assert_lte(wx._area, float(WeatherFx.cfg().max_area_scale))
	var storm: WeatherFx.Look = wx.look_of("storm")
	assert_lte(wx._scaled(storm.splashes, 1.0, 1.5), 160, "splashes stay few")
	var snow: WeatherFx.Look = wx.look_of("snow")
	var flakes: int = 0
	for layer: int in snow.n.size():
		flakes += wx.count(snow, layer, 1.0, 1.0)
	assert_lte(flakes, 260, "flakes stay few")
	var wind: WeatherFx.Look = wx.look_of("wind")
	assert_lte(wx._scaled(wind.streaks + wind.leaves, 1.0, 1.5), 100)

func test_textures_are_built_once() -> void:
	var wx := WeatherFx.new()
	wx.setup(_town(), 3, "full")
	var l: WeatherFx.Look = wx.look_of("rain")
	var a: Texture2D = wx.rain_tex(l, 0, 20, false)
	assert_same(a, wx.rain_tex(l, 0, 20, false))
	assert_eq(a.get_size(), Vector2(WeatherFx.SHEET, WeatherFx.SHEET))
	assert_same(wx.bank_tex(1), wx.bank_tex(1))
	assert_same(wx.puddle_tex(0, 2, false), wx.puddle_tex(0, 2, false))
	assert_same(wx.snow_tex(1, false), wx.snow_tex(1, false))
	assert_same(wx.rainbow_tex(), wx.rainbow_tex())
	assert_same(wx.cloud_tex(), wx.cloud_tex())
	assert_same(wx.look_of("rain"), l, "a look is read once")
	# A puddle grows: each stage covers more of the tile.
	var px: Array[int] = []
	for stage: int in WeatherFx.PUDDLE_STAGES:
		var img: Image = wx.puddle_tex(1, stage, false).get_image()
		var n: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					n += 1
		px.append(n)
	assert_gt(px[0], 0)
	assert_lt(px[0], px[1])
	assert_lt(px[1], px[2])

func test_rain_streaks_lean_with_the_wind() -> void:
	var wx := WeatherFx.new()
	wx.setup(_town(), 3, "full")
	var l: WeatherFx.Look = wx.look_of("storm")
	var img: Image = wx.rain_tex(l, 2, 1, false).get_image()
	var top := Vector2i(-1, -1)
	var bottom := Vector2i(-1, -1)
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				n += 1
				if top.x < 0:
					top = Vector2i(x, y)
				bottom = Vector2i(x, y)
	assert_between(n, l.length[2] - 3, l.length[2], "one streak of the layer's length")
	if bottom.y - top.y == n - 1:
		assert_lt(bottom.x, top.x, "the storm drives it to the left as it falls")

func test_puddles_lie_on_paths_and_grass_only() -> void:
	var rows: Array = []
	for y: int in 30:
		rows.append("_".repeat(15) + ".".repeat(15) + "~".repeat(5) + "T".repeat(5))
	var m: MapData = _map({"region": "quillmarch", "outdoor": true, "biome": "town", "rows": rows})
	var wx := WeatherFx.new()
	wx.setup(m, 3, "full")
	assert_gt(wx.puddle_x.size(), 10)
	var on_path: int = 0
	for i: int in wx.puddle_x.size():
		var k: int = m.kind_at(Vector2i(wx.puddle_x[i], wx.puddle_y[i]))
		assert_true(k == TilesetFactory.Kind.PATH or k == TilesetFactory.Kind.GRASS)
		if k == TilesetFactory.Kind.PATH:
			on_path += 1
		assert_between(wx.puddle_from[i], 0.0, 0.55)
	assert_gt(on_path, wx.puddle_x.size() - on_path, "paths hold more water than grass")
	assert_lt(wx.puddle_x.size(), 900 / 5, "puddles stay the exception")
	assert_eq(wx.flags_at(31, 0) & WeatherFx.F_WATER, WeatherFx.F_WATER)
	assert_eq(wx.flags_at(0, 0) & WeatherFx.F_GROUND, WeatherFx.F_GROUND)
	assert_eq(wx.flags_at(37, 0), 0, "nothing lands on a tree")
	assert_eq(wx.flags_at(-1, 0), 0)
	# The same map scans the same every time.
	var again := WeatherFx.new()
	again.setup(m, 3, "full")
	assert_eq(again.puddle_x, wx.puddle_x)
	assert_eq(again.puddle_y, wx.puddle_y)

func test_era_one_colours_are_the_region_inks() -> void:
	var wx := WeatherFx.new()
	wx.setup(_town("veydal"), 1, "full")
	var inks: Array[Color] = EraManager.inks_for("veydal")
	for c: Color in wx.rain:
		assert_has(inks, c)
	assert_has(inks, wx.fog)
	assert_false(wx.soft)
	assert_gt(wx.step_fps, 0.0)
	assert_eq(wx.clock(0.26), wx.clock(0.3), "Era I moves in steps")
	var later := WeatherFx.new()
	later.setup(_town("quillmarch"), 3, "full")
	assert_eq(later.clock(0.26), 0.26)
	assert_true(later.soft)
	assert_eq(later.depths, 3)

func test_every_look_paints_in_every_era_without_error() -> void:
	var m: MapData = _town()
	for era: int in range(1, EraLight.ERAS + 1):
		for w: String in ["rain", "storm", "fog", "wind", "clear"]:
			var layer: EraLightLayer = _layer(m, era, w)
			await wait_process_frames(2)
			assert_eq(layer.era, era)
			# Half way into the next sky both are painted.
			EraLight.debug_weather = "storm" if w != "storm" else "fog"
			layer.refresh(m, EraLight.debug_weather)
			layer.mix = 0.5
			await wait_process_frames(2)
	assert_true(true)

# --- The symbol and the names ---------------------------------------------------------------

func test_weather_symbol() -> void:
	var icon := WeatherIcon.new()
	add_child_autofree(icon)
	icon.show_kind("clear")
	assert_false(icon.visible, "nothing under a clear sky")
	for k: String in ["rain", "storm", "fog", "wind", "snow", "sandstorm", "ash"]:
		icon.show_kind(k)
		assert_true(icon.visible, k)
		assert_eq(icon.kind, k)
	await wait_process_frames(1)
	GameState.weather = false
	icon.show_for(_town())
	assert_false(icon.visible, "weather off: always clear")

func test_banner_and_clock_strip_carry_the_symbol() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.set_flag("got_starter")
	GameState.current_map = "brindlewick"
	GameState.player_cell = Vector2i(5, 8)
	EraLight.debug_era = 3
	EraLight.debug_weather = "rain"
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(3)
	assert_not_null(ow._weather_icon)
	assert_eq(ow._weather_icon.get_parent(), ow._banner)
	assert_not_null(ow._phase_icon, "the time-of-day symbol is still there")
	ow._show_banner("Brindlewick")
	assert_true(ow._weather_icon.visible)
	assert_eq(ow._weather_icon.kind, "rain")
	assert_true(ow._banner.text.begins_with("    Brindlewick"))
	var strip: Control = EraMenuKit.clock_strip()
	add_child_autofree(strip)
	await wait_process_frames(1)
	assert_not_null(strip.get("_sky"))
	MusicDirector.update_world(true, false, 0.0)

func test_map_page_names_the_sky_and_what_comes() -> void:
	var m: MapData = MapData.load_map("brindlewick")
	assert_true(m.outdoor)
	var text: String = WorldAtlas.detail_text("brindlewick")
	assert_string_contains(text, Loc.t("Weather: %s") % Loc.t(EraLight.weather_name(m)))
	var soon: String = WeatherCycle.forecast(m, 1)[0]
	if soon != WeatherCycle.current(m):
		assert_string_contains(text, Loc.t("Later: %s") % Loc.t(WeatherCycle.name_of(soon)))
	else:
		assert_false(text.contains(Loc.t("Later: %s") % ""), "no forecast line when the sky stays")
	GameState.weather = false
	assert_string_contains(WorldAtlas.detail_text("brindlewick"), Loc.t("Weather: %s") % Loc.t("Clear"))

func test_new_texts_have_german() -> void:
	var keep: String = Loc.language()
	Loc.set_language("de")
	for en: String in ["Drizzle", "Downpour", "Thick fog", "Gale", "Snow", "Sandstorm", "Ash fall", "Later: %s",
			"Weather effects: Full", "Weather effects: Low", "Weather effects: Off",
			"How much rain, snow and fog is drawn. Low is easier on old phones. Off: only the light changes."]:
		assert_ne(Loc.t(en), en, "'%s' has German" % en)
	Loc.set_language(keep)
