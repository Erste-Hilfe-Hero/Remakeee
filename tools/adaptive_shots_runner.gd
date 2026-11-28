extends Node
## The work of tools/adaptive_shots.gd, run as a node so the autoloads exist.

var out: String = "user://adaptive_shots"
var tag: String = ""
## Notch / status bar, gesture bar and side cut-outs in window pixels (top, bottom, left, right),
## simulated through SafeArea and tinted on each saved shot so overlap shows.
var insets: Array[float] = [0.0, 0.0, 0.0, 0.0]
## Layout problems found on the way (printed at the end, exit code 1 when any).
var problems: PackedStringArray = []
const MAX_FRAMES: int = 240

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
	if insets.max() > 0.0:
		SafeArea.simulate(Vector2(w.size), insets[0], insets[1], insets[2], insets[3])
	await _frames(4)
	print("%s window=%s view=%s final=%s" % [tag, w.size, w.get_visible_rect().size, w.get_final_transform()])
	get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
	await _frames(90)
	await _shot("title")
	_check_inside(get_tree().current_scene.get_node("version") as Control, "title version")
	get_tree().change_scene_to_file("res://scenes/overworld/Overworld.tscn")
	await _frames(60)
	GameState.notices.clear()
	var ow: Node = get_tree().current_scene
	# Tap the opening notices away (a festival, a lamp, the weekend bonus), as a player would.
	for i: int in 40:
		if i >= 6 and not (ow.get("_text") as Control).is_visible_in_tree():
			break
		_tap()
		await _frames(15)
	# xvfb draws frames uncapped: wait for the notes on their own clock, as a player sees them.
	var toast: Toast = ow.get("toast")
	await _frames(2)
	_check_inside(toast.get("_panel") as Control, "toast")
	while toast.pending() > 0:
		await get_tree().process_frame
	await _shot("overworld")
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
			problems.append("shop: " + p)
		s.show_detail(ShopCatalog.offers()[0])
		await _frames(12)
		await _shot("shop_detail")
		for p: String in ShopScreen.fit_problems(s):
			problems.append("shop detail: " + p)
		s.queue_free()
		await _frames(2)
		menu.picker.picked.emit(-1)
		await _frames(20)
	var m := PauseMenu.new()
	m.current_map = "brindlewick"
	m.encounter_table = "brindlewick"
	# Where Overworld.open_menu puts it, so it draws above the world, and with the pad hidden.
	VirtualPad.set_wanted(false)
	(ow.get("_ui") as Node).add_child(m)
	await _frames(2)
	await _menu_shot(m, "spirlog", m.run_spirlog)
	await _menu_shot(m, "settings", m.run_settings)
	await _menu_shot(m, "friends", func() -> void: await FriendsMenu.run(m))
	await _menu_shot(m, "dialog_confirm", func() -> void: await m.confirm_danger("Replace the saved journey with this one?", "Replace", "Keep"))
	await _menu_shot(m, "dialog_info", func() -> void: await m.info("Your journey was saved. You can close the game now and go on later from the title screen."))
	m.queue_free()
	await _frames(2)
	# Overworld.start_battle hides the touch pad; the battle has its own buttons.
	VirtualPad.set_wanted(false)
	get_tree().change_scene_to_file("res://scenes/battle/Battle.tscn")
	for i: int in 1200:
		var b: Node = get_tree().current_scene
		if i > 60 and b != null and bool(b.get("_waiting_orders")):
			break
		if i % 40 == 39:
			_tap()
		await get_tree().process_frame
	await _frames(30)
	await _shot("battle")
	var scene: Node = get_tree().current_scene
	var bond: BondMinigame = scene.get("_bond_game")
	# Picking Bond gives the orders, which takes the first battle's art arrow away (BattleScene).
	var arrow: FirstArtArrow = scene.get("_first_arrow")
	if arrow != null:
		arrow.stop()
	bond.target_name = "Wickit"
	bond.run_mine()
	for i: int in 7:
		bond.mine_tap()
	await _frames(10)
	await _shot("battle_mine")
	_check_inside(bond.get("_hint") as Control, "mine hint")
	for i: int in 30:
		bond.mine_tap()
	await _frames(90)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	bond.rng = rng
	bond.run()
	await _frames(20)
	await _shot("battle_echo")
	_check_inside(bond.get("_hint") as Control, "echo hint")
	for p: String in problems:
		printerr("%s: %s" % [tag, p])
	print("%s: %d problems" % [tag, problems.size()])
	get_tree().quit(1 if not problems.is_empty() else 0)

## [param c] lies inside the safe area of the view.
func _check_inside(c: Control, what: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if not SafeArea.rect(vp).grow(0.5).encloses(c.get_global_rect()):
		problems.append("%s %s leaves the safe area %s" % [what, c.get_global_rect(), SafeArea.rect(vp)])

## Runs [param start] on [param m], saves what it opens, checks the list fits, closes it again.
func _menu_shot(m: PauseMenu, what: String, start: Callable) -> void:
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await start.call()
		state.done = true
	runner.call()
	await _frames(30)
	await _shot(what)
	for p: String in EraMenuKit.fit_problems(m, what != "spirlog"):
		problems.append("%s: %s" % [what, p])
	if m.picker.visible:
		_check_inside(m.picker, what + " list")
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
		problems.append("%s: did not close" % what)

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
	if insets.max() > 0.0:
		_tint_insets(path)
	print("saved %s_%s" % [tag, what])

## Tints the simulated cut-outs magenta on the saved shot at [param path].
func _tint_insets(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		return
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var rects: Array[Rect2i] = [Rect2i(0, 0, w, int(insets[0])), Rect2i(0, h - int(insets[1]), w, int(insets[1])),
		Rect2i(0, 0, int(insets[2]), h), Rect2i(w - int(insets[3]), 0, int(insets[3]), h)]
	var tint := Color(1.0, 0.0, 1.0, 0.35)
	for r: Rect2i in rects:
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				img.set_pixel(x, y, img.get_pixel(x, y).blend(tint))
	img.save_png(path)

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
