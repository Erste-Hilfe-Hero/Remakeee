extends Node
## The work of tools/c100_notify_shots.gd, run as a node so the autoloads exist.

var out: String = "user://c100_notify_shots"
var lang: String = "en"
var _n: int = 0

class FakePlugin extends RefCounted:
	signal notify_event(json: String)
	func notify_schedule(_id: int, _title: String, _body: String, _delay: int) -> void:
		pass
	func notify_cancel_all() -> void:
		pass
	func notify_request_permission() -> void:
		notify_event.emit.call_deferred(JSON.stringify({"kind": "permission", "granted": true}))

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	Loc.set_language(lang)
	GameState.language = lang
	GameState.reduce_motion = true
	LocalNotify.plugin_override = FakePlugin.new()
	LocalNotify.reset_for_tests()
	var menu := MenuHost.new()
	get_tree().root.add_child(menu)
	await _frames(10)
	# The one question, when the first roaming trip sets off.
	LocalNotify.offer(menu)
	await _until(func() -> bool: return menu._info_panel.visible)
	await _shot("ask_text")
	menu._close_info()
	await _until(func() -> bool: return menu.picker.visible)
	await _shot("ask_question")
	menu.picker.picked.emit(0)
	await _frames(20)
	# Settings > Game with the row on, focus on it.
	var rows: Array[Array] = MenuHost.settings_rows("game")
	var at: int = rows.map(func(r: Array) -> String: return str(r[0])).find("notify")
	menu.pick("Game", MenuHost._rows_to_entries(rows), true, at)
	await _until(func() -> bool: return menu.picker.visible)
	await _shot("settings_row")
	menu.picker.picked.emit(-1)
	await _frames(20)
	menu.info(Loc.t(AccountMenu.PRIVACY_NOTE) + "\n\n" + Loc.t(LocalNotify.PRIVACY_LINE))
	await _until(func() -> bool: return menu._info_panel.visible)
	await _shot("privacy_note")
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
