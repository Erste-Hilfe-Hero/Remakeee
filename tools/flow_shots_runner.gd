extends Node
## The work of tools/flow_shots.gd, run as a node so the autoloads exist.

const TILES: int = 12
const COLUMNS: int = 6

var out: String = "user://flow_shots"
var eras: Array[int] = [1, 4]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://flow_shots_settings.json"
	load("res://tools/era_menu_shots_runner.gd").setup_state()
	GameState.reduce_motion = false
	GameState.flags = {"aldo_gift": true, "got_starter": true}
	EraManager.unlocked_era = 5
	for era: int in eras:
		EraManager.set_retro_filter(era)
		await _menus(era)
		await _overworld(era)
	get_tree().quit()

func _menus(era: int) -> void:
	var host := MenuHost.new()
	get_tree().root.add_child(host)
	await _frames(4)
	var rows: Array[String] = ["Team", "Spirlog", "Satchel", "Save", "Settings"]
	var first := func() -> void: await host.pick_strings("Menu", rows)
	first.call()
	await _strip("era%d_list_open" % era)
	host.picker.picked.emit(0)
	var second := func() -> void: await host.pick_strings("Team", ["Kindlop", "Zippit", "Wickit"] as Array[String])
	second.call()
	await _strip("era%d_list_forward" % era)
	host.picker.picked.emit(-1)
	first.call()
	await _strip("era%d_list_back" % era)
	host.picker.picked.emit(-1)
	await _strip("era%d_list_close" % era)
	var note := func() -> void: await host.info("Kindlop\nRing 9   Vigor 28/28\nA warm ember that follows the lamp.")
	note.call()
	await _strip("era%d_info_open" % era)
	host._info_closed.emit()
	await _strip("era%d_info_close" % era)
	var sets := func() -> void: await host._run_setting_group("Sound", "sound")
	sets.call()
	await _frames(20)
	host.picker.picked.emit(0)
	await _strip("era%d_setting_change" % era)
	host.picker.picked.emit(-1)
	await _frames(4)
	host.toast("Saved.", 0.3)
	await _strip("era%d_menu_toast_in" % era)
	await _frames(10)
	await _strip("era%d_menu_toast_out" % era)
	host.queue_free()
	var top := Toast.new()
	get_tree().root.add_child(top)
	await _frames(2)
	top.show_note("Badge earned: First steps", null, "")
	await _strip("era%d_note_in" % era)
	await get_tree().create_timer(Toast.SHOW_TIME - 0.3).timeout
	await _strip("era%d_note_out" % era, 24)
	top.queue_free()
	await _frames(2)

func _overworld(era: int) -> void:
	GameState.current_map = "brindlewick"
	var inst: Node = (load("res://scenes/overworld/Overworld.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	await get_tree().create_timer(9.0).timeout
	var menu := func() -> void: await inst.open_menu()
	menu.call()
	await _strip("era%d_pause_open" % era)
	var pause: PauseMenu = null
	for c: Node in inst._ui.get_children():
		if c is PauseMenu:
			pause = c
	if pause != null:
		pause.picker.picked.emit(-1)
		await _strip("era%d_pause_close" % era)
	await _frames(30)
	var said := func() -> void: await inst.say(["The lamp is lit. The road to Fernstair is open."] as Array[String])
	said.call()
	await _strip("era%d_text_open" % era)
	Input.action_press("ui_accept")
	await _frames(2)
	Input.action_release("ui_accept")
	await _frames(20)
	Input.action_press("ui_accept")
	await _frames(2)
	Input.action_release("ui_accept")
	await _strip("era%d_text_close" % era)
	await _frames(30)
	await _battle(era, inst)
	inst.queue_free()
	await _frames(4)

func _battle(era: int, inst: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var foes: Array[Spirling] = [Spirling.new(Database.spirlings["Zippit"], 4, rng)]
	var fight := func() -> void: await inst.start_battle(foes, true)
	fight.call()
	await _strip("era%d_battle_in" % era, 24)
	var scene: BattleScene = null
	for i: int in 900:
		await get_tree().process_frame
		for c: Node in inst._battle_layer.get_children():
			if c is BattleScene:
				scene = c
		if scene != null and scene._waiting_orders:
			break
		if scene != null and i % 20 == 0:
			_tap()
	if scene == null:
		return
	scene._menu.set_enabled(false)
	await _frames(2)
	scene._menu.set_enabled(true)
	await _strip("era%d_battle_menu_in" % era)
	scene._menu.chosen.emit(BattleAction.Kind.RUN, -1)
	for i: int in 900:
		if not inst.busy:
			break
		if i % 20 == 0:
			_tap()
		if not is_instance_valid(scene) or scene.is_queued_for_deletion():
			break
		await get_tree().process_frame
	await _strip("era%d_battle_out" % era, 24)
	for i: int in 600:
		if not inst.busy:
			break
		if i % 20 == 0:
			_tap()
		await get_tree().process_frame

func _tap() -> void:
	Input.action_press("ui_accept")
	await _frames(2)
	Input.action_release("ui_accept")

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

## Saves the next [param n] frames as one sheet, oldest first.
func _strip(shot: String, n: int = TILES) -> void:
	var tiles: Array[Image] = []
	for i: int in n:
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		tiles.append(img)
	var w: int = tiles[0].get_width()
	var h: int = tiles[0].get_height()
	var rows: int = ceili(float(n) / COLUMNS)
	var sheet: Image = Image.create(COLUMNS * (w + 2), rows * (h + 2), false, Image.FORMAT_RGB8)
	sheet.fill(Color(1, 0, 1))
	for i: int in n:
		sheet.blit_rect(tiles[i], Rect2i(0, 0, w, h), Vector2i((i % COLUMNS) * (w + 2), (i / COLUMNS) * (h + 2)))
	sheet.save_png("%s/%s.png" % [out, shot])
	print("saved ", shot)
