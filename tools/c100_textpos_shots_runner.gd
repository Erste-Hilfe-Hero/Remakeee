extends Node
## The work of tools/c100_textpos_shots.gd, run as a node so the autoloads exist.

var out: String = "user://c100_textpos_shots"
var langs: String = "en,de,ja"
const LINE: String = "Kestra: ...It answered you. It hasn't answered anyone since the Woadfen."

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://c100_textpos_settings.json"
	load("res://tools/era_menu_shots_runner.gd").setup_state()
	GameState.flags = {"aldo_gift": true, "got_starter": true}
	GameState.tips_enabled = false
	EraManager.unlocked_era = 5
	VirtualPad.force_visible = true
	for era: int in [1, 3, 5]:
		EraManager.set_retro_filter(era)
		for lang: String in langs.split(","):
			GameState.language = lang
			Loc.set_language(lang)
			await _world(era, lang)
	get_tree().quit()

func _world(era: int, lang: String) -> void:
	GameState.current_map = "brindlewick"
	GameState.player_cell = Vector2i(5, 8)
	var inst: Node = (load("res://scenes/overworld/Overworld.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	VirtualPad.set_wanted(true)
	await get_tree().create_timer(2.6).timeout
	# One step, so anything that trails the Wayfarer is in place.
	inst.player.step("right", false)
	await get_tree().create_timer(0.6).timeout
	await _save("era%d_walk_%s" % [era, lang])
	VirtualPad.set_talk(true)
	inst.say([LINE] as Array[String])
	await get_tree().create_timer(3.5).timeout
	await _save("era%d_talk_%s" % [era, lang])
	_report(inst)
	inst.queue_free()
	VirtualPad.set_talk(false)
	await get_tree().process_frame

func _report(inst: Node) -> void:
	var box: Control = inst.text_box()
	var r: Rect2 = box.get_global_rect()
	print("TEXTBOX ", r, " pad_top ", VirtualPad.top_y(), " overlap ", VirtualPad.top_y() >= 0.0 and r.end.y > VirtualPad.top_y())

func _save(shot: String) -> void:
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])
	print("saved ", shot)
