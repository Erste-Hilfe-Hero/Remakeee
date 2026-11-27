extends Node
## The work of tools/c200_team_shots.gd, run as a node so the autoloads exist.

const MAX_FRAMES: int = 240
var out: String = "user://c200_team_shots"
var langs: PackedStringArray = ["en", "de"]
var eras: PackedStringArray = ["1"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://c200_team_shots_settings.json"
	var runner: GDScript = load("res://tools/era_menu_shots_runner.gd")
	for era_s: String in eras:
		for lang: String in langs:
			runner.call("setup_state")
			GameState.flags["story_complete"] = true
			GameState.party[0].held = "spark_coil"
			GameState.party[1].held = "tonic"
			GameState.party[2].held = ""
			var first: SpirlingData = SpirlogBook.visible_kinds(GameState.flags)[0]
			GameState.mark_seen(first.species_name, true)
			GameState.note_event_kind(first.species_name, LampWatch.RECORD)
			GameState.language = lang
			Loc.set_language(lang)
			EraManager.unlocked_era = int(era_s)
			EraManager.set_retro_filter(0)
			await get_tree().process_frame
			await get_tree().process_frame
			var t: String = "era%s_%s" % [era_s, lang]
			var m := PauseMenu.new()
			m.current_map = "fernstair"
			m.encounter_table = "fernstair"
			add_child(m)
			await get_tree().process_frame
			await _shoot(m, t + "_team", m.run_team, false)
			await _shoot(m, t + "_spirlog_kinds", m.run_spirlog, false)
			await _shoot(m, t + "_spirlog_top", m.run_spirlog, true)
			m.queue_free()
			await get_tree().process_frame
	EraManager.unlocked_era = 1
	get_tree().quit(0)

func _picture(shot: String) -> void:
	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])

func _shoot(m: PauseMenu, shot: String, start: Callable, top: bool) -> void:
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await start.call()
		state.done = true
	runner.call()
	if top:
		for i: int in 12:
			await get_tree().process_frame
		var b: Array = m.picker.get("_buttons")
		if not b.is_empty():
			(b[0] as Button).grab_focus()
			var sc: ScrollContainer = m.picker.get("_scroll")
			for i: int in 6:
				await get_tree().process_frame
				if sc != null:
					sc.scroll_vertical = 0
	await _picture(shot)
	for i: int in MAX_FRAMES:
		if state.done:
			break
		if m._info_wait:
			m._page_turn = -2
			m._close_info()
		elif m.picker.visible:
			m.picker.picked.emit(-1)
		await get_tree().process_frame
	if not state.done:
		printerr("%s: did not close" % shot)
