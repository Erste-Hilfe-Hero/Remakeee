extends Node
## The work of tools/adaptive_shots.gd, run as a node so the autoloads exist.

var out: String = "user://adaptive_shots"
var tag: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	var w: Window = get_window()
	if tag.is_empty():
		tag = "%dx%d" % [w.size.x, w.size.y]
	SaveManager.settings_path = "user://adaptive_shots_settings.json"
	if Online.has_signal("state_changed") and Online.state_changed.is_connected(Billing._on_online_state):
		Online.state_changed.disconnect(Billing._on_online_state)
	load("res://tools/era_menu_shots_runner.gd").call("setup_state")
	Loc.set_language("en")
	GameState.language = "en"
	GameState.terms_version = LegalInfo.TERMS_VERSION
	EraBoot.shown = true
	GameState.notices.clear()
	VirtualPad.force_visible = true
	VirtualPad.call("_refresh")
	GameState.current_map = "brindlewick"
	GameState.player_cell = Vector2i(5, 8)
	await _frames(4)
	print("%s window=%s view=%s final=%s" % [tag, w.size, w.get_visible_rect().size, w.get_final_transform()])
	get_tree().change_scene_to_file("res://scenes/overworld/Overworld.tscn")
	await _frames(60)
	GameState.notices.clear()
	for i: int in 6:
		_tap()
		await _frames(15)
	await _shot("overworld")
	var ow: Node = get_tree().current_scene
	var ui_root: Control = ow.get("_ui_root")
	print("%s overworld ui column %s text %s" % [tag, ui_root.get_global_rect(), (ow.get("_text") as Control).get_global_rect()])
	ow.call("open_menu")
	await _frames(20)
	await _shot("pause")
	var menu: MenuHost = null
	for n: Node in get_tree().root.find_children("*", "PauseMenu", true, false):
		menu = n as MenuHost
	if menu != null:
		Billing.state = {"balance": 1250, "band": 18, "open": true, "bought": {}, "unlocks": {}, "rifts": 1,
			"cap_cents": 10000, "spent_cents": 0, "withdrawal_ok": true}
		for o: Dictionary in ShopCatalog.offers():
			Billing.prices[str(o.get("product_id", ""))] = ShopCatalog.format_eur(int(o.get("eur_cents", 0)))
		var s := ShopScreen.new()
		s.menu = menu
		menu.add_child(s)
		await _frames(12)
		await _shot("shop")
		for p: String in ShopScreen.fit_problems(s):
			printerr("%s shop: %s" % [tag, p])
		s.queue_free()
	get_tree().change_scene_to_file("res://scenes/battle/Battle.tscn")
	for i: int in 240:
		if i % 40 == 39:
			_tap()
		await get_tree().process_frame
	await _shot("battle")
	get_tree().quit()

## The whole window as it is on screen, bars included.
func _shot(what: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var w: Window = get_window()
	var path: String = ProjectSettings.globalize_path("%s/%s_%s.png" % [out, tag, what])
	# X screen grab (ImageMagick under xvfb-run), so bars around the view would show.
	var crop: String = "%dx%d+%d+%d" % [w.size.x, w.size.y, w.position.x, w.position.y]
	if OS.execute("import", ["-window", "root", "-crop", crop, "+repage", path]) != 0:
		var img: Image = w.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(path)
	print("saved %s_%s" % [tag, what])

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _tap() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = "ui_accept"
	Input.parse_input_event.call_deferred(up)
