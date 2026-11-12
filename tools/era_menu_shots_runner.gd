extends Node
## The work of tools/era_menu_shots.gd, run as a node so the autoloads exist.

const MAX_FRAMES: int = 240
var out: String = "user://era_menu_shots"
var _problems: PackedStringArray = []
var _count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

## A journey with enough in it to fill every screen: four Spirlings of different eras, things
## in every satchel pocket, seen and bonded kinds with places, visited towns, pinned shortcuts.
static func setup_state() -> void:
	Database.load_all()
	GameState.settings_from_dict({})
	GameState.new_game(GameState.Difficulty.TAMER, "Rowan", 0, "Kindlop")
	GameState.reduce_motion = true
	GameState.tips_enabled = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var all: Array = Database.spirlings.values()
	all.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	var picked: int = 0
	for sd: SpirlingData in all:
		if picked >= 3:
			break
		if sd.species_name == "Kindlop" or sd.elements.size() < 1 + picked % 2:
			continue
		GameState.party.append(Spirling.new(sd, 9 + picked * 9, rng))
		picked += 1
	GameState.party[0].held = "tonic" if Database.item("tonic").has("held") else GameState.party[0].held
	GameState.party[1].hp = maxi(1, GameState.party[1].max_hp() / 3)
	GameState.party[2].hp = 0
	GameState.party[1].favorite = true
	for id: Variant in Database.items:
		var it: Dictionary = Database.item(str(id))
		var tab: int = PauseMenu.bag_tab(it)
		var have: int = 0
		for own: Variant in GameState.inventory:
			have += 1 if PauseMenu.bag_tab(Database.item(str(own))) == tab else 0
		if have < 4:
			GameState.add_item(str(id), 1 + have)
	for place: String in ["brindlewick", "fernstair", "crowcrest", "saltmarsh"]:
		if MapData.exists(place):
			var m: MapData = MapData.load_map(place)
			Survey.reveal(m, Vector2i(m.width / 2, m.height / 2))
	var n: int = 0
	for sd: SpirlingData in all:
		if n >= 14:
			break
		GameState.current_map = ["brindlewick", "fernstair", "crowcrest", "saltmarsh"][n % 4]
		GameState.mark_seen(sd.species_name, n % 3 != 2)
		var e: Dictionary = GameState.spirlog[sd.species_name]
		if e.has("maps") and not GameState.current_map in (e.maps as Array):
			(e.maps as Array).append(GameState.current_map)
		n += 1
	for s: Spirling in GameState.party:
		GameState.mark_seen(s.data.species_name, true)
	GameState.current_map = "fernstair"
	GameState.play_time = 3.0 * 3600.0 + 7.0 * 60.0
	GameState.set_flag(PauseMenu.STORAGE_FLAG)
	GameState.set_flag("aldo_gift")
	for l: String in ["Team", "Satchel", "Spirlog"]:
		GameState.flags[EraMenus.QUICK_FLAG % l.to_lower()] = true
	Billing.state = {"balance": 120, "band": 18, "open": true}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var keep_lang: String = GameState.language
	for lang: String in ["en", "de"]:
		setup_state()
		GameState.language = lang
		Loc.set_language(lang)
		for era: int in range(1, 6):
			# The newest open era is the look (the Retro filter is a shop setting and falls
			# back to it when the shop state says it is not owned).
			EraManager.unlocked_era = era
			EraManager.set_retro_filter(0)
			await get_tree().process_frame
			await get_tree().process_frame
			await _era(era, lang)
	GameState.language = keep_lang
	EraManager.unlocked_era = 1
	EraManager.set_retro_filter(0)
	print("era menu shots: %d screens, %d problems" % [_count, _problems.size()])
	for p: String in _problems:
		printerr("  " + p)
	get_tree().quit(1 if not _problems.is_empty() else 0)

func _menu() -> PauseMenu:
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	menu.encounter_table = "fernstair"
	add_child(menu)
	return menu

func _era(era: int, lang: String) -> void:
	var tag: String = "era%d_%s" % [era, lang]
	var m: PauseMenu = _menu()
	await get_tree().process_frame
	var labels: Array[String] = PauseMenu.menu_labels(true, not GameState.travel_targets("fernstair").is_empty(), false, false, true,
		not Trust.ledger_rows(GameState.flags).is_empty())
	labels.insert(labels.find("Satchel") + 1, "Shop")
	await _shoot(m, tag + "_01_pause", m.run, [])
	await _shoot(m, tag + "_02_party", m.run_team, [])
	await _shoot(m, tag + "_03_summary", m.run_team, [0, 0])
	if bool(EraMenus.layout(era, "summary").get("tabs", false)):
		for t: int in range(1, 4):
			await _shoot(m, tag + "_03_summary_tab%d" % t, m.run_team, [0, 0], t)
	else:
		for t: int in range(1, EraMenus.layout(era, "summary").pages.size()):
			await _shoot(m, tag + "_03_summary_page%d" % t, m.run_team, [0, 0], t)
	await _shoot(m, tag + "_04_bag", m.run_bag, [])
	await _shoot(m, tag + "_05_dex", m.run_spirlog, [])
	await _shoot(m, tag + "_05_dex_page", func() -> void: await SpirlogPage.show_pages(m, _seen_kinds(), 1), [])
	if "size" in (EraMenus.layout(era, "dex").get("tools", []) as Array):
		await _shoot(m, tag + "_05_dex_size", func() -> void: await EraDexViews.show_size(m, _seen_kinds()[1]), [])
	if "area" in (EraMenus.layout(era, "dex").get("tools", []) as Array):
		await _shoot(m, tag + "_05_dex_area", func() -> void: await EraDexViews.show_area(m, _seen_kinds()[1]), [])
	await _shoot(m, tag + "_06_save", m.run_save, [])
	await _shoot(m, tag + "_07_options", m.run_settings, [])
	var names: Array[String] = []
	for t: String in ShopCatalog.TABS:
		names.append(ShopCatalog.TAB_NAMES[t])
	names.append_array(["My purchases", "Spending limit", "About purchases", "Help with purchases"])
	await _shoot(m, tag + "_08_shop", func() -> void:
		await m.pick_screen("shop", ShopMenu.title(), ShopMenu.list_rows(names, EraMenus.layout(era, "shop")), {"panel_text": ShopMenu.RG_NO_VALUE}), [])
	await _shoot(m, tag + "_08_shop_tab", func() -> void: await ShopMenu._run_tab(m, "riftglass"), [])
	await _shoot(m, tag + "_09_map", func() -> void: await WorldMapMenu.run(m, "fernstair"), [])
	m.queue_free()
	await get_tree().process_frame

func _seen_kinds() -> Array[SpirlingData]:
	var out: Array[SpirlingData] = []
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		if SpirlogBook.is_seen(GameState.spirlog, sd.species_name):
			out.append(sd)
	return out

## Runs [param start], answers its lists with [param path], takes the picture of what is then
## open and closes everything again. [param page] turns a summary to that page or tab first.
func _shoot(m: PauseMenu, shot: String, start: Callable, path: Array, page: int = 0) -> void:
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await start.call()
		state.done = true
	var seen: int = m.picks
	runner.call()
	var steps: Array = path.duplicate()
	for i: int in MAX_FRAMES:
		await get_tree().process_frame
		if steps.is_empty():
			break
		if m.picks > seen and m.picker.visible:
			seen = m.picks
			m.picker.picked.emit(int(steps.pop_front()))
	# A text that comes before the list (a long title shown in full first) is tapped away.
	if not "_summary" in shot:
		for i: int in 20:
			if m._info_wait:
				m._close_info()
			await get_tree().process_frame
	for i: int in 8:
		await get_tree().process_frame
	var summary: EraSummary = m.get_node_or_null("era_summary") as EraSummary
	if page > 0 and summary != null:
		summary.show_tab(page, false)
	elif page > 0 and m._info_wait:
		for k: int in page:
			m._page_turn = 1
			m._close_info()
			for i: int in 3:
				await get_tree().process_frame
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])
	_count += 1
	for p: String in EraMenuKit.fit_problems(m, not ("_dex" in shot or "_map" in shot or "_bag" in shot or "_shop_tab" in shot or "_party" in shot)):
		_problems.append("%s: %s" % [shot, p])
	# Close whatever is open until the screen's coroutine ends.
	for i: int in MAX_FRAMES:
		if state.done:
			break
		var card: Node = _find(m, "era_card")
		var page_node: Node = null
		for c: Node in m.get_children():
			if c is SpirlogPage:
				page_node = c
		if card != null:
			card.emit_signal("closed")
		elif m.get_node_or_null("era_summary") != null:
			m.get_node("era_summary").emit_signal("closed")
		elif page_node != null:
			page_node.emit_signal("_closed")
		elif m._info_wait:
			m._page_turn = -2
			m._close_info()
		elif m.picker.visible:
			m.picker.picked.emit(-1)
		await get_tree().process_frame
	if not state.done:
		_problems.append("%s: did not close" % shot)

func _find(n: Node, child_name: String) -> Node:
	for c: Node in n.get_children():
		if c.name == child_name:
			return c
		var deep: Node = _find(c, child_name)
		if deep != null:
			return deep
	return null
