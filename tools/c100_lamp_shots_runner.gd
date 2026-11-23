extends Node
## The work of tools/c100_lamp_shots.gd, run as a node so the autoloads exist.

var out: String = "user://c100_lamp_shots"
var lang: String = "en"
var _n: int = 0
var _room_visits: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	Loc.set_language(lang)
	GameState.language = lang
	EraBoot.shown = true
	GameState.reduce_motion = true
	for n: int in range(1, SaveManager.SLOTS + 1):
		SaveManager.set_slot(n)
		SaveManager.delete_save()
	SaveManager.set_slot(1)
	var server := LocalBackend.new("user://c100_lamp_server.json")
	server.offline = true
	Online.backend = server
	Online.state = Online.State.OFFLINE
	Online.offline_play = true
	GameState.new_game(GameState.Difficulty.TAMER, "Rowan", 0, "Kindlop")
	SaveManager.start_fresh_slot()
	for f: String in ["got_starter", "aldo_gift", Overworld.FIRST_WALK_FLAG]:
		GameState.set_flag(f)
	GameState.current_map = "lighthouse"
	GameState.player_cell = Vector2i(7, 1)
	GameState.facing = "right"
	GameState.in_game = true
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	# Let the start toasts (festival, lamp note) run out before the first shot.
	await _frames(600)
	await _shot("lighthouse")
	# Night 1: the stairs, the lamp room, the log page, the visitor, the Echo call, the card.
	await _night(ow, ["stairs", "light", "log", "gift", "visitor_a", "visitor_b", "joined", "joined2"])
	# Night 7: six more nights lit on earlier days, then tonight brings the Gleam.
	GameState.records[LampWatch.RECORD] = {"nights": 6, "last_day": "2000-01-01", "answered": "2000-01-01"}
	await _night(ow, ["n7_stairs", "n7_light", "n7_log", "n7_log2", "n7_gift", "n7_visitor", "n7_visitor2", "n7_joined", "n7_gleam"])
	get_tree().quit()

func _night(ow: Overworld, box_names: Array[String]) -> void:
	var box: TextBox = ow.text_box()
	var boxes: int = 0
	var done: bool = false
	var run := func() -> void:
		await ow.run_dialogue("lighthouse/stairs")
		done = true
	run.call()
	for i: int in 6000:
		if done:
			break
		var game: BondMinigame = _find_game(ow)
		if game != null and game.visible:
			await _frames(30)
			await _shot("echo_call")
			game.finished.emit(1.0)
			await _frames(4)
			continue
		for c: Node in ow._ui.get_children():
			if c is MenuHost and (c as MenuHost)._info_panel.visible:
				await _frames(20)
				await _shot("info")
				(c as MenuHost)._close_info()
				await _frames(4)
		if ow._picker.visible and ow._picker._buttons.size() > 0:
			await _frames(20)
			await _shot("stairs_choice")
			ow._picker.picked.emit(0)
			await _frames(4)
			continue
		var menu: MenuHost = _open_menu(ow)
		if menu != null:
			await _frames(20)
			if menu.last_title == Loc.t("The lamp room"):
				_room_visits += 1
				await _shot("lamp_room")
				# First visit of a night: light it. Afterwards: read the log once, then leave.
				var rows: Array[String] = menu.last_rows
				if rows[0] == "Light the lamp":
					menu.picker.picked.emit(0)
				elif _room_visits == 2 and rows.has("Mirela's lamp log"):
					menu.picker.picked.emit(rows.find("Mirela's lamp log"))
				else:
					menu.picker.picked.emit(-1)
			else:
				await _shot("answer_prompt")
				menu.picker.picked.emit(0)
			await _frames(4)
			continue
		if box._waiting:
			var name: String = box_names[boxes] if boxes < box_names.size() else "box%d" % boxes
			boxes += 1
			await _shot(name)
			print("box: ", box._label.text.replace("\n", " "))
			box.advance_now()
			await _frames(2)
			continue
		await get_tree().process_frame

func _find_game(ow: Overworld) -> BondMinigame:
	for c: Node in ow.ui_root().get_children():
		if c is BondMinigame:
			return c
	return null

func _open_menu(ow: Overworld) -> MenuHost:
	for c: Node in ow._ui.get_children():
		if c is MenuHost and (c as MenuHost).picker.visible and (c as MenuHost).picker._buttons.size() > 0:
			return c
	return null

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	_n += 1
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = "%s/%02d_%s_%s_%dx%d.png" % [out, _n, name, lang, size.x, size.y]
	img.save_png(path)
	print("saved ", path)
