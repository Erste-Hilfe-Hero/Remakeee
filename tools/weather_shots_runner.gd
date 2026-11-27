extends Node
## The work of tools/weather_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 3
const FRAMES: int = 150
## [name, era, map, weather, hour, month, extra]
const SHOTS: Array = [
	["era1_rain", 1, "brindlewick", "rain", 12.0, 6, ""],
	["era1_storm", 1, "saltmarsh", "storm", 12.0, 6, ""],
	["era1_fog", 1, "brindlewick", "fog", 12.0, 6, ""],
	["era1_wind", 1, "brindlewick", "wind", 12.0, 6, ""],
	["era2_rain", 2, "hookwick", "rain", 12.0, 6, ""],
	["era2_drizzle", 2, "hookwick", "rain", 12.0, 6, "light"],
	["era2_storm", 2, "hookwick", "storm", 12.0, 6, ""],
	["era2_fog", 2, "tithe_road", "fog", 12.0, 6, ""],
	["era2_wind", 2, "tithe_road", "wind", 12.0, 6, ""],
	["era3_rain", 3, "ledgerholm", "rain", 12.0, 6, ""],
	["era3_drizzle", 3, "ledgerholm", "rain", 12.0, 6, "light"],
	["era3_downpour", 3, "ledgerholm", "rain", 12.0, 6, "heavy"],
	["era3_rain_low_fx", 3, "ledgerholm", "rain", 12.0, 6, "low"],
	["era3_rain_fx_off", 3, "ledgerholm", "rain", 12.0, 6, "off"],
	["era3_rain_to_clear_fade", 3, "ledgerholm", "rain", 12.0, 6, "fade"],
	["era3_after_rain_rainbow", 3, "ledgerholm", "clear", 12.0, 6, "rainbow"],
	["era3_storm", 3, "ledgerholm", "storm", 12.0, 6, ""],
	["era3_storm_flash", 3, "ledgerholm", "storm", 19.0, 6, "flash"],
	["era3_fog", 3, "smudge_marsh", "fog", 9.0, 6, ""],
	["era3_wind", 3, "ledgerholm", "wind", 12.0, 6, ""],
	["era3_rain_water", 3, "smudge_marsh", "rain", 12.0, 6, ""],
	["era4_rain", 4, "brightledge", "rain", 12.0, 6, ""],
	["era4_storm", 4, "brightledge", "storm", 12.0, 6, ""],
	["era4_fog", 4, "cloudshadow_meadow", "fog", 12.0, 6, ""],
	["era4_wind", 4, "cloudshadow_meadow", "wind", 12.0, 6, ""],
	["era4_snow", 4, "white_stair", "rain", 12.0, 1, ""],
	["era4_snow_starting", 4, "white_stair", "rain", 12.0, 1, "wet30"],
	["era5_rain", 5, "mossgate", "rain", 12.0, 6, ""],
	["era5_rain_night", 5, "mossgate", "rain", 23.0, 6, ""],
	["era5_storm", 5, "driftwick", "storm", 12.0, 6, ""],
	["era5_fog", 5, "wandering_wood", "fog", 9.0, 6, ""],
	["era5_wind", 5, "wandering_wood", "wind", 12.0, 6, ""],
	["era5_indoor_no_weather", 5, "", "storm", 12.0, 6, "indoor"],
	["era3_banner_weather_icon", 3, "ledgerholm", "storm", 12.0, 6, "banner"],
]
var out: String = "user://weather_shots"
var prefix: String = "after"
var only: PackedStringArray = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	GameState.set_flag("got_starter")
	# First-time tips open a text box over the map: none in a weather shot.
	for id: String in Tips.TOPICS:
		GameState.set_flag(Tips.flag(id))
	# The settings file of this machine must not decide what the shots show.
	GameState.reduce_motion = false
	GameState.day_night = true
	GameState.weather = true
	GameState.language = "en"
	Loc.set_language("en")
	EraManager.unlocked_era = 5
	# A first overworld takes the start-up notices and settles the window; it is not shot.
	var warm: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(warm)
	for i: int in 20:
		await get_tree().process_frame
	warm.queue_free()
	await get_tree().process_frame
	GameState.notices.clear()
	EraManager.unlocked_era = 5
	for s: Array in SHOTS:
		if only.is_empty() or _wanted(str(s[0])):
			await _shot(s)
	get_tree().quit()

func _wanted(shot: String) -> bool:
	for part: String in only:
		if part in shot:
			return true
	return false

## A free cell near the middle of [param m], away from warps.
func _spot(m: MapData) -> Vector2i:
	var mid := Vector2(m.width, m.height) / 2.0
	var best := Vector2i(1, 1)
	var best_d: float = INF
	for y: int in m.height:
		for x: int in m.rows[y].length():
			var c := Vector2i(x, y)
			var d: float = Vector2(c).distance_to(mid)
			if d < best_d and m.is_walkable(c) and m.warp_at(c).is_empty() and m.kind_at(c) in [TilesetFactory.Kind.PATH, TilesetFactory.Kind.FLOOR, TilesetFactory.Kind.GRASS]:
				best = c
				best_d = d
	return best

func _indoor_map() -> String:
	for id: String in ["driftwick_pole_house", "copperfold_house"]:
		if MapData.load_map(id) != null:
			return id
	return GameState.current_map

func _shot(s: Array) -> void:
	EraManager.set_retro_filter(int(s[1]))
	EraLight.debug_weather = str(s[3])
	EraLight.debug_hour = float(s[4])
	EraLight.debug_month = int(s[5])
	var extra: String = str(s[6])
	# The "before" pass runs on the old code, which knows none of these.
	var cycle: Script = load("res://scripts/core/WeatherCycle.gd")
	var new_code: bool = "debug_strength" in cycle
	if new_code:
		cycle.set("debug_strength", 0.2 if extra == "light" else (0.95 if extra == "heavy" else 0.6))
		cycle.set("debug_wet", 0.3 if extra == "wet30" else (0.8 if extra == "rainbow" else -1.0))
		GameState.set("weather_fx", extra if extra in ["low", "off"] else "full")
	elif extra in ["light", "heavy", "low", "off", "fade", "rainbow", "wet30", "indoor", "banner"]:
		return
	var id: String = _indoor_map() if extra == "indoor" else str(s[2])
	var m: MapData = MapData.load_map(id)
	GameState.current_map = m.id
	GameState.player_cell = _spot(m)
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	for i: int in FRAMES:
		await get_tree().process_frame
	var layer: EraLightLayer = ow._era_light
	if extra == "flash":
		layer.try_flash()
		layer._flash_left = 9.0
	if extra == "fade":
		# Half way from rain to a clear sky.
		EraLight.debug_weather = "clear"
		ow.refresh_daylight(true)
		layer.set("mix", 0.5)
		layer.set_process(false)
	# Start-up notes (daily gift, weekend) are not what the shot is about.
	var ticker: Node = get_node_or_null("/root/Ticker")
	if ticker != null:
		(ticker.get("_queue") as Array).clear()
		(ticker.get("_bar") as CanvasItem).visible = false
	if ow.toast != null:
		ow.toast.visible = false
	if extra == "banner":
		ow.call("_show_banner", ow.banner_text())
		for i: int in 40:
			await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s_%s.png" % [out, prefix, str(s[0])])
	var drops: int = 0
	if new_code:
		var wx: Object = layer.get("wx")
		var l: Object = wx.call("look_of", layer.look)
		for i: int in 3:
			drops += int(wx.call("count", l, i, 1.0, float(layer.get("power"))))
	print("saved %s  era %d  %s  fx %s  drops %d" % [s[0], layer.era, layer.look, ", ".join(layer.fx), drops])
	ow.queue_free()
	await get_tree().process_frame
