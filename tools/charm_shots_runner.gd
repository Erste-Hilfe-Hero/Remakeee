extends Node
## The work of tools/charm_shots.gd, run as a node so the autoloads exist.

var out: String = "user://charm_shots"
var langs: PackedStringArray = ["de"]
var eras: Array[int] = [1, 4]
var _problems: int = 0

const BAG: Dictionary = {"kin_charm": 3, "charm_inkquill": 2, "charm_kindred": 1, "charm_moonwick": 2, "charm_stormbell": 1,
	"charm_mender": 1, "rg_charm_hush": 1, "rg_charm_swiftleaf": 3, "rg_charm_lantern": 1, "rg_charm_firstlight": 1, "charm_pagebound": 3, "rg_bond_seal": 1}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://charm_shots_settings.json"
	var setup: GDScript = load("res://tools/era_menu_shots_runner.gd")
	if Online.has_signal("state_changed") and Online.state_changed.is_connected(Billing._on_online_state):
		Online.state_changed.disconnect(Billing._on_online_state)
	for e: int in eras:
		for lang: String in langs:
			setup.call("setup_state")
			GameState.language = lang
			Loc.set_language(lang)
			EraManager.unlocked_era = e
			EraManager.set_retro_filter(0)
			await get_tree().process_frame
			await get_tree().process_frame
			var t: String = "era%d_%s" % [e, lang]
			await _picker_shot(t)
			await _shop_shots(t)
	EraManager.unlocked_era = 1
	print("charm_shots: %d fit problems" % _problems)
	get_tree().quit(1 if _problems > 0 else 0)

func _picker_shot(t: String) -> void:
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = BattleScene.DEMO_SEED
	var mine: Array[Spirling] = BattleScene._demo_team(rng, ["Kindlop"] as Array[String], 14)
	var theirs: Array[Spirling] = BattleScene._demo_team(rng, ["Zippit"] as Array[String], 12)
	var model := BattleModel.new(mine, theirs, true, BattleScene.DEMO_SEED, 0)
	inst.setup(model)
	get_tree().root.add_child(inst)
	for i: int in 1800:
		if inst._menu != null and inst._menu._content != null and inst._menu._content.visible:
			break
		inst._text.advance_now()
		await get_tree().process_frame
	model.inventory = BAG.duplicate()
	inst._menu._content.visible = false
	inst._bond()
	for i: int in 240:
		await get_tree().process_frame
		if inst._picker.visible:
			break
		if i % 20 == 19:
			inst._text.advance_now()
	await _picture(t + "_01_charm_picker")
	inst._picker._scroll.scroll_vertical = 100000
	await _picture(t + "_02_charm_picker_end")
	inst.queue_free()
	await get_tree().process_frame

func _state() -> void:
	Billing.state = {"balance": 1250, "band": 18, "open": true, "bought": {}, "unlocks": {},
		"rifts": 1, "cap_cents": 10000, "spent_cents": 0, "withdrawal_ok": true}
	Billing.prices.clear()
	for o: Dictionary in ShopCatalog.offers():
		Billing.prices[str(o.get("product_id", ""))] = ShopCatalog.format_eur(int(o.get("eur_cents", 0)))

func _shop_shots(t: String) -> void:
	var m := PauseMenu.new()
	add_child(m)
	await get_tree().process_frame
	_state()
	var h: MenuHost = ShopZoom.enter(m)
	var s := ShopScreen.new()
	s.menu = h
	h.add_child(s)
	s.select_tab("advantages")
	await _picture(t + "_03_shop_advantages_link", s)
	s.select_tab("charms")
	await _picture(t + "_04_shop_charms", s)
	s._scroll.scroll_vertical = 520 if EraManager.active_era() < 3 else 900
	await _picture(t + "_05_shop_charms_mid", s)
	s._scroll.scroll_vertical = 100000
	await _picture(t + "_06_shop_charms_end", s)
	s._scroll.scroll_vertical = 0
	await get_tree().process_frame
	s._scroll.ensure_control_visible(s.find_child("charm_charm_pagebound", true, false))
	await _picture(t + "_08_shop_pagebound", s)
	s.show_detail(ShopCatalog.offer("rg_charm_satchel"))
	await _picture(t + "_07_detail_satchel", s)
	s.queue_free()
	ShopZoom.leave(h)
	m.queue_free()
	await get_tree().process_frame

func _picture(shot: String, s: Control = null) -> void:
	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if s != null:
		for p: String in ShopScreen.fit_problems(s):
			_problems += 1
			printerr("%s: %s" % [shot, p])
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])
