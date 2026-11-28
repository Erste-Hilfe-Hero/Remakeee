extends "res://tools/c100_menu_shots_runner.gd"
## The work of tools/c200_set_shots.gd: reuses the menu shot helpers of c100_menu_shots_runner.

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://c200_set_shots_settings.json"
	load("res://tools/era_menu_shots_runner.gd").call("setup_state")
	GameState.language = "en"
	Loc.set_language("en")
	EraManager.set_retro_filter(0)
	await get_tree().process_frame
	var m := PauseMenu.new()
	m.current_map = "fernstair"
	m.encounter_table = "fernstair"
	add_child(m)
	await get_tree().process_frame
	await _shoot(m, "c200_126_sound_reset", m._run_setting_group.bind("Sound", "sound"))
	for mode: int in [0, 1, 2]:
		GameState.night_mode = mode
		GameState.apply_display()
		await _shoot(m, "c200_127_night_%s" % GameState.NIGHT_MODE_NAMES[mode].to_lower(), m.run_display)
	GameState.night_mode = 0
	GameState.apply_display()
	m.queue_free()
	get_tree().quit(0)
