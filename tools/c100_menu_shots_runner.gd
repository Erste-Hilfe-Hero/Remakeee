extends Node
## The work of tools/c100_menu_shots.gd, run as a node so the autoloads exist.

const MAX_FRAMES: int = 240
var out: String = "user://c100_menu_shots"
var langs: PackedStringArray = ["en", "de"]
var era: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://c100_menu_shots_settings.json"
	var runner: GDScript = load("res://tools/era_menu_shots_runner.gd")
	for lang: String in langs:
		runner.call("setup_state")
		GameState.language = lang
		Loc.set_language(lang)
		EraManager.unlocked_era = era
		EraManager.set_retro_filter(0)
		await get_tree().process_frame
		await get_tree().process_frame
		await _screens(lang)
	EraManager.unlocked_era = 1
	get_tree().quit(0)

func _screens(lang: String) -> void:
	var t: String = "era%d_%s" % [era, lang]
	var m := PauseMenu.new()
	m.current_map = "fernstair"
	m.encounter_table = "fernstair"
	add_child(m)
	await get_tree().process_frame
	Online.profile = {"code": "GPRG38FP"}
	Billing.state = {"balance": 120, "band": 18, "open": true}
	await _shoot(m, t + "_01_pause", m.run)
	await _shoot(m, t + "_04_bag", m.run_bag)
	await _shoot(m, t + "_05_dex_page", func() -> void: await SpirlogPage.show_pages(m, _seen_kinds(), 1))
	await _shoot(m, t + "_07_display", m.run_display)
	await _shoot(m, t + "_08_shop", _shop_list.bind(m))
	await _shoot(m, t + "_08_shop_tab", func() -> void: await ShopMenu._run_tab(m, "riftglass"))
	await _shoot(m, t + "_10_account", func() -> void: await AccountMenu.run(m))
	# Offline: no shop state and no friend code from the server.
	Online.profile = {}
	Billing.state = {}
	await _shoot(m, t + "_08_shop_offline", _shop_list.bind(m))
	await _shoot(m, t + "_10_account_offline", func() -> void: await AccountMenu.run(m))
	Online.profile = {"code": "GPRG38FP"}
	Billing.state = {"balance": 120, "band": 18, "open": true}
	# The offline mark over the pause menu (docs/OFFLINE.md).
	var o := OfflineMark.new()
	add_child(o)
	o.update_view(OfflineMark.SHOW_AFTER)
	await _shoot(m, t + "_12_offline_mark", m.run)
	o.queue_free()
	m.queue_free()
	await get_tree().process_frame
	await _update_panel(t)

func _shop_list(m: PauseMenu) -> void:
	var names: Array[String] = []
	for tab: String in ShopCatalog.TABS:
		names.append(ShopCatalog.TAB_NAMES[tab])
	names.append_array(["My purchases", "Spending limit", "About purchases", "Help with purchases"])
	await m.pick_screen("shop", ShopMenu.title(), ShopMenu.list_rows(names, EraMenus.layout(era, "shop")), {"panel_text": ShopMenu.RG_NO_VALUE})

func _update_panel(t: String) -> void:
	var p := UpdatePanel.new()
	add_child(p)
	p.show_view(AppUpdater.TEXT_STORE, ["Update", "Later"] as Array[String])
	await _picture(t + "_11_update_store")
	p.show_view(AppUpdater.TEXT_FLEX, ["Keep playing"] as Array[String])
	p.set_progress(0.4, AppUpdate.size_text(12_300_000, 30_800_000))
	await _picture(t + "_11_update_flex")
	p.hide_progress()
	p.show_view(AppUpdater.TEXT_APK_DONE, ["Install", "Cancel"] as Array[String])
	await _picture(t + "_11_update_done")
	p.queue_free()
	await get_tree().process_frame

func _seen_kinds() -> Array[SpirlingData]:
	var res: Array[SpirlingData] = []
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		if SpirlogBook.is_seen(GameState.spirlog, sd.species_name):
			res.append(sd)
	# A kind with a long unfold line, so the forms row is as wide as it gets.
	res.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool:
		return SpirlogBook.line_of(a).size() > SpirlogBook.line_of(b).size())
	return res

func _picture(shot: String) -> void:
	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])

## Runs [param start], takes the picture of what opens first (a title shown in full before its
## list included), then closes everything until the coroutine ends.
func _shoot(m: PauseMenu, shot: String, start: Callable) -> void:
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await start.call()
		state.done = true
	runner.call()
	await _picture(shot)
	for i: int in MAX_FRAMES:
		if state.done:
			break
		var page_node: Node = null
		for c: Node in m.get_children():
			if c is SpirlogPage:
				page_node = c
		if page_node != null:
			page_node.emit_signal("_closed")
		elif m._info_wait:
			m._page_turn = -2
			m._close_info()
		elif m.picker.visible:
			m.picker.picked.emit(-1)
		await get_tree().process_frame
	if not state.done:
		printerr("%s: did not close" % shot)
