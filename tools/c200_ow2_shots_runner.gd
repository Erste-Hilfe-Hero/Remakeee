extends Node
## The work of tools/c200_ow2_shots.gd, run as a node so the autoloads exist.

var out: String = "user://c200_ow2_shots"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://c200_ow2_settings.json"
	load("res://tools/era_menu_shots_runner.gd").setup_state()
	GameState.flags = {"aldo_gift": true, "got_starter": true}
	GameState.tips_enabled = false
	EraManager.unlocked_era = 5
	GameState.note_place("brindlewick")
	GameState.note_place("fernstair")
	for era: int in [1, 4]:
		EraManager.set_retro_filter(era)
		await _map(era)
	await _reset_room()
	get_tree().quit()

func _map(era: int) -> void:
	var host := MenuHost.new()
	get_tree().root.add_child(host)
	var run := func() -> void: await WorldMapMenu.run(host, "fernstair")
	run.call()
	await get_tree().create_timer(1.0).timeout
	await _save("era%d_map_last_here" % era)
	# "Rest point": the fourth action (a row in Era I, a tab in Era IV).
	var bar: bool = str(EraMenus.layout(EraManager.active_era(), "map").get("actions", "row")) == "bar"
	host.picker.picked.emit(ListPicker.TAB_PICKED - 3 if bar else 3)
	await get_tree().create_timer(1.0).timeout
	await _save("era%d_rest_point_hint" % era)
	host._info_closed.emit()
	await get_tree().create_timer(1.0).timeout
	await _save("era%d_rest_point_ring" % era)
	host.queue_free()
	await get_tree().process_frame

func _reset_room() -> void:
	EraManager.set_retro_filter(1)
	var fix: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/puzzles/sun_rift.json")).sun_dial
	var m: MapData = MapData.load_map("sun_rift")
	var st: Array = fix.start
	var done: Dictionary = PuzzleSolver.replay(m, Vector2i(int(st[0]), int(st[1])), (fix.moves as Array).slice(0, 4))
	GameState.set_world_of("sun_rift", PuzzleRoom.capture(done.map, {}))
	GameState.current_map = "sun_rift"
	GameState.player_cell = done.cell
	var inst: Node = (load("res://scenes/overworld/Overworld.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	# The festival note at the top fades first.
	await get_tree().create_timer(9.0).timeout
	print("RESET BUTTON visible=", inst.reset_button.visible)
	await _save("reset_room_button")
	inst.reset_button.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	await _save("reset_room_confirm")
	inst.queue_free()
	await get_tree().process_frame

func _save(shot: String) -> void:
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])
	print("saved ", shot)
