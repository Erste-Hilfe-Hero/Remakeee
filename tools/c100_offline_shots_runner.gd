extends Node
## The work of tools/c100_offline_shots.gd, run as a node so the autoloads exist.

var out: String = "user://c100_offline_shots"
var lang: String = "en"
var _n: int = 0

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
	var server := LocalBackend.new("user://c100_offline_server.json")
	server.offline = true
	Online.backend = server
	Online.state = Online.State.OFFLINE
	Online.revs = {}
	Online.dirty = {}
	Online.privacy_seen = false
	# Terms accepted before (an older start), so the privacy note of the offline start shows.
	GameState.terms_version = LegalInfo.TERMS_VERSION
	# Title without a connection: the list offers Start offline.
	var title: Node = load("res://scenes/ui/Title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	var menu: MenuHost = title.get("_menu")
	await _until(func() -> bool: return menu._info_panel.visible or menu.picker.visible)
	if menu._info_panel.visible:
		await _shot("no_connection_text")
		menu._close_info()
		await _until(func() -> bool: return menu.picker.visible)
	await _shot("no_connection")
	menu.picker.picked.emit(2)
	# The short privacy note comes before the journey, as online.
	await _until(func() -> bool: return menu._info_panel.visible)
	await _shot("privacy_note")
	menu._close_info()
	await _until(func() -> bool: return menu.picker.visible and Online.offline_play)
	await _shot("title_offline")
	title.queue_free()
	await _frames(2)
	# New Game offline: the prologue runs without the reconnect screen.
	GameState.new_game(GameState.Difficulty.TAMER, "Rowan", 0, "")
	SaveManager.start_fresh_slot()
	GameState.in_game = true
	var ow: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	await _frames(240)
	await _shot("prologue_offline")
	# The prologue's save point: from here a missing connection pauses as always.
	Online.offline_save_point()
	Online._offline_for = ReconnectOverlay.SHORT_DROP
	await _frames(40)
	await _shot("after_save_point")
	get_tree().quit()

func _until(cond: Callable, max_frames: int = 1200) -> void:
	for i: int in max_frames:
		if cond.call():
			break
		await get_tree().process_frame
	await _frames(20)

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
