extends Node
## The work of tools/era_light_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 2
const FRAMES: int = 100
## [name, era, map, weather, hour, month, extra]
const SHOTS: Array = [
	["era1_rain_pattern", 1, "brindlewick", "rain", 12.0, 10, ""],
	["era1_fog_pattern", 1, "brindlewick", "fog", 12.0, 10, ""],
	["era1_storm_pattern", 1, "saltmarsh", "storm", 12.0, 10, ""],
	["era1_night_no_tint", 1, "brindlewick", "clear", 23.0, 10, ""],
	["era1_cave_light_circle", 1, "murk_hollow", "clear", 12.0, 10, ""],
	["era2_morning", 2, "hookwick", "clear", 6.0, 10, ""],
	["era2_night_rain_windows", 2, "hookwick", "rain", 23.0, 10, ""],
	["era2_fog", 2, "tithe_road", "fog", 12.0, 10, ""],
	["era3_rain_splashes_puddles", 3, "ledgerholm", "rain", 12.0, 10, ""],
	["era3_storm_flash", 3, "ledgerholm", "storm", 19.0, 10, "flash"],
	["era3_sandstorm", 3, "drypoint_lane", "wind", 12.0, 10, ""],
	["era3_ash_fall", 3, "mordant_row", "fog", 12.0, 10, ""],
	["era3_fog_bands", 3, "smudge_marsh", "fog", 7.0, 10, ""],
	["era3_door_wipe", 3, "ledgerholm", "clear", 12.0, 10, "door_wipe"],
	["era3_stair_wipe", 3, "ledgerholm", "clear", 12.0, 10, "stair_wipe"],
	["era4_shafts_cloud_shadows", 4, "brightledge", "clear", 10.0, 10, ""],
	["era4_cloud_shadows_meadow", 4, "cloudshadow_meadow", "clear", 14.0, 10, ""],
	["era4_lamp_glow_night", 4, "lantern_span", "clear", 22.0, 10, ""],
	["era4_snow_prints", 4, "white_stair", "rain", 12.0, 1, "prints"],
	["era4_dusk", 4, "gildcrest", "clear", 19.0, 10, ""],
	["era5_golden_hour_shadows_leaves", 5, "wandering_wood", "clear", 18.5, 10, ""],
	["era5_morning_long_shadows", 5, "driftwick", "clear", 7.0, 10, ""],
	["era5_night_lamps_embers", 5, "lastbloom", "clear", 22.0, 10, ""],
	["era5_spring_pollen", 5, "tallowmere", "clear", 12.0, 5, ""],
	["era5_winter_rain", 5, "mossgate", "rain", 12.0, 1, ""],
	["era5_camera_sweep", 5, "rootchapel", "clear", 17.5, 10, "sweep"],
]
var out: String = "user://era_light_shots"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	GameState.set_flag("got_starter")
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
		await _shot(s)
	get_tree().quit()

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

func _shot(s: Array) -> void:
	EraManager.set_retro_filter(int(s[1]))
	EraLight.debug_weather = str(s[3])
	EraLight.debug_hour = float(s[4])
	EraLight.debug_month = int(s[5])
	var extra: String = str(s[6])
	var m: MapData = MapData.load_map(str(s[2]))
	GameState.current_map = m.id
	GameState.player_cell = _spot(m)
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	for i: int in (30 if extra == "sweep" else FRAMES):
		await get_tree().process_frame
	var layer: EraLightLayer = ow._era_light
	match extra:
		"flash":
			layer.try_flash()
			layer._flash_left = 9.0
		"door_wipe", "stair_wipe":
			layer.wipe_style = extra
			layer.wipe_up = true
			layer.wipe_k = 0.55
		"prints":
			var c: Vector2i = GameState.player_cell
			for d: int in range(4, 0, -1):
				layer.note_step(c + Vector2i(0, d), "up")
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, str(s[0])])
	print("saved %s  era %d  %s  fx %s" % [s[0], layer.era, layer.look, ", ".join(layer.fx)])
	ow.queue_free()
	await get_tree().process_frame
