extends Node
## The work of tools/goal_shots.gd, run as a node so the autoloads exist.

var out: String = "user://goal_shots"
var lang: String = "en"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

## A node running tools/era_menu_shots_runner.gd's shooting with its own full run switched off.
func _helper() -> Node:
	var s := GDScript.new()
	s.source_code = "extends \"res://tools/era_menu_shots_runner.gd\"\nfunc _run() -> void:\n\tpass\n"
	s.reload()
	var n := Node.new()
	n.set_script(s)
	n.set("out", out)
	add_child(n)
	return n

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://goal_shots_settings.json"
	load("res://tools/era_menu_shots_runner.gd").setup_state()
	GameState.language = lang
	Loc.set_language(lang)
	EraManager.unlocked_era = 1
	EraManager.set_retro_filter(0)
	GameState.flags = {"aldo_gift": true, "got_starter": true, PauseMenu.STORAGE_FLAG: true}
	GameState.tips_enabled = false
	VirtualPad.force_visible = true
	await _world("brindlewick", Vector2i(5, 8), "01_ow_town_goal")
	await _world("lighthouse", Vector2i(4, 4), "02_ow_lighthouse_goal")
	GameState.flags["met_kestra"] = true
	await _world("fernstair", Vector2i(8, 6), "03_ow_route_rifts")
	VirtualPad.force_visible = false
	VirtualPad.set_wanted(false)
	var h: Node = _helper()
	var m := PauseMenu.new()
	m.current_map = "fernstair"
	m.encounter_table = "fernstair"
	add_child(m)
	await get_tree().process_frame
	var labels: Array[String] = PauseMenu.menu_labels(true, false, false, Online.league_on())
	labels.insert(labels.find("Satchel") + 1, "Shop")
	await _shot(m, "04_pause", m.run, [])
	await _shot(m, "05_pause_more", m.run, [labels.find(PauseMenu.MORE)])
	await _shot(m, "06_pause_map", m.run, [labels.find("Map")])
	await _shot(m, "07_world_map", m.run, [labels.find("Map"), 0])
	await _shot(m, "08_spirlog", m.run_spirlog, [])
	await _shot(m, "09_spirlog_legend", func() -> void: await m.info(PauseMenu.spirlog_legend()), [])
	await h._shoot(m, "10_spirlog_page", func() -> void: await SpirlogPage.show_pages(m, h._seen_kinds(), 1), [])
	GameState.current_map = "brindlewick"
	await _shot(m, "11_welcome_back", func() -> void: await m.info(TitleScreen.welcome_text(GameState.flags), EraSaveCard.badge(1)), [])
	await _shot(m, "12_settings_game", m.run_settings, [0])
	print("goal shots: %d screens, problems: %s" % [h.get("_count"), h.get("_problems")])
	get_tree().quit()

func _world(map_id: String, cell: Vector2i, shot: String) -> void:
	GameState.current_map = map_id
	GameState.player_cell = cell
	var inst: Node = (load("res://scenes/overworld/Overworld.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	VirtualPad.set_wanted(true)
	# The place banner hides the goal line for its first moments.
	await get_tree().create_timer(2.6).timeout
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])
	print("saved ", shot)
	inst.queue_free()
	await get_tree().process_frame

## Opens [param start], taps the rows of [param path] one list at a time, saves the screen and
## closes everything again (Back on every list, a tap on every text).
func _shot(m: PauseMenu, shot: String, start: Callable, path: Array) -> void:
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await start.call()
		state.done = true
	runner.call()
	var texts: bool = not path.is_empty() or start == m.run
	for step: Variant in path + [null]:
		for i: int in 16:
			await get_tree().process_frame
			# A long title shows in full first (item 1850): tapped away on the way in.
			if texts and m._info_wait:
				m._close_info()
		if step != null:
			m.picker.picked.emit(int(step))
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])
	print("saved ", shot)
	for i: int in 400:
		if state.done:
			break
		if m._info_wait:
			m._page_turn = -2
			m._close_info()
		elif m.picker.visible:
			m.picker.picked.emit(-1)
		await get_tree().process_frame
