extends Node
## The work of tools/era45_overworld_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 3
## [era, map, cell, hour of the game clock]
const SHOTS: Array = [
	[3, "ledgerholm", Vector2i(5, 9), 12],
	[4, "starwell", Vector2i(5, 9), 12], [4, "gildcrest", Vector2i(5, 9), 12],
	[5, "driftwick", Vector2i(5, 9), 12], [5, "mossgate", Vector2i(5, 9), 17],
	# Slice 6: trees and cliffs, a small outdoor map, a house inside, an old region on the wide screen.
	[4, "cloudshadow_meadow", Vector2i(5, 12), 12], [4, "white_stair", Vector2i(5, 6), 12],
	[5, "wandering_wood", Vector2i(5, 12), 12], [5, "lastbloom", Vector2i(5, 9), 12],
	[4, "starwell_home_1", Vector2i(4, 5), 12], [5, "driftwick_net_shed", Vector2i(3, 4), 12],
	[5, "brindlewick", Vector2i(5, 9), 12],
]
var out: String = "user://era45_overworld"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var gs: Object = get_tree().root.get_node("/root/GameState")
	var em: Node = get_tree().root.get_node("/root/EraManager")
	Database.load_all()
	gs.call("new_game", 1, "Rowan", 0, "Kindlop")
	gs.call("set_flag", "got_starter")
	gs.set("weather", false)
	gs.set("tips_enabled", false)
	gs.set("reduce_motion", false)
	em.set("unlocked_era", 5)
	# The first scene sets the window up; its picture is thrown away.
	em.call("set_retro_filter", 1)
	await _shot("warmup")
	DirAccess.remove_absolute("%s/warmup.png" % out)
	for s: Array in SHOTS:
		em.call("set_retro_filter", int(s[0]))
		var m: MapData = MapData.load_map(str(s[1]))
		var cell: Vector2i = s[2]
		if not m.is_walkable(cell):
			cell = _free_cell(m, cell)
		gs.set("current_map", s[1])
		gs.set("player_cell", cell)
		(gs.get("records") as Dictionary)["clock_shift"] = posmod(int(s[3]) - int(Time.get_time_dict_from_system().hour), 24)
		for depth: bool in [false, true]:
			EraDepthLayer.enabled = depth
			await _shot("era%d_%s_%s" % [s[0], s[1], "depth" if depth else "flat"])
	EraDepthLayer.enabled = true
	get_tree().quit()

## The walkable cell nearest to [param want].
func _free_cell(m: MapData, want: Vector2i) -> Vector2i:
	var best: Vector2i = want
	var best_d: int = 1 << 30
	for y: int in m.height:
		for x: int in m.width:
			var c := Vector2i(x, y)
			var d: int = (c - want).length_squared()
			if m.is_walkable(c) and d < best_d:
				best = c
				best_d = d
	return best

func _shot(file: String) -> void:
	var inst: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(inst)
	for i: int in 150:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, file])
	print("saved ", file)
	inst.queue_free()
	await get_tree().process_frame
