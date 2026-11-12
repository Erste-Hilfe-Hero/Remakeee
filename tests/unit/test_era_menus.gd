extends GutTest
## Menu screen layouts per era (data/era_menus.json, EraMenus, docs/ERA_FEEL_MENUS.md): the
## table is sound, each era brings its handheld step, every function stays in every era, and
## every screen opens in every era with its own layout.

const MAX_FRAMES: int = 200

var _unlocked: int
var _retro: int
var _flags: Dictionary
var _reduce: bool
var _settings_path: String

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter
	_flags = GameState.flags.duplicate()
	_reduce = GameState.reduce_motion
	# The settings screen saves on Back.
	_settings_path = SaveManager.settings_path
	SaveManager.settings_path = "user://test_era_menus_settings.json"

func after_each() -> void:
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)
	GameState.flags = _flags
	GameState.reduce_motion = _reduce
	SaveManager.settings_path = _settings_path
	GameState.in_game = false

func _era(e: int) -> void:
	EraManager.unlocked_era = e
	EraManager.set_retro_filter(0)

# --- Table ----------------------------------------------------------------------

func test_table_is_sound() -> void:
	assert_eq(EraMenus.problems(), [] as Array[String])

func test_all_nine_screens_are_listed() -> void:
	assert_eq(EraMenus.screens(), ["pause", "party", "summary", "bag", "dex", "save", "options", "shop", "map"] as Array[String])

func test_problems_finds_a_missing_function() -> void:
	var keep: Dictionary = EraMenus.config().duplicate(true)
	(((EraMenus._cfg.eras as Dictionary)["4"].screens as Dictionary).party.functions as Dictionary).erase("reorder")
	var found: Array[String] = EraMenus.problems()
	EraMenus._cfg = keep
	assert_has(found, "function:4:party:reorder")

func test_problems_finds_a_lost_icon() -> void:
	var keep: Dictionary = EraMenus.config().duplicate(true)
	((EraMenus._cfg.eras as Dictionary)["3"].base as Dictionary).icons = false
	var found: Array[String] = EraMenus.problems()
	EraMenus._cfg = keep
	assert_has(found, "loses:3:bag:icons")

func test_unknown_screen_gets_the_base_list() -> void:
	var l: Dictionary = EraMenus.layout(2, "nothing")
	assert_eq(str(l.style), "icon")
	assert_eq(int(l.era), 2)
	assert_eq(int(EraMenus.layout(9).era), 5, "clamped to V")

# --- Each era's step ------------------------------------------------------------

func test_era_one_is_a_plain_text_list() -> void:
	for s: String in EraMenus.screens():
		var l: Dictionary = EraMenus.layout(1, s)
		assert_eq(int(l.columns), 1, s)
		assert_false(bool(l.icons), s)
		assert_eq(str(l.cursor), "arrow", s)
	assert_eq((EraMenus.layout(1, "summary").pages as Array).size(), 2, "summary on two pages")
	assert_eq(str(EraMenus.layout(1, "bag").pockets), "flat")
	assert_eq(str(EraMenus.layout(1, "dex").area), "text")
	assert_gt(int(EraMenus.layout(1, "dex").preview), 0, "number list with a small sprite")

func test_era_two_brings_icons_pockets_and_the_clock() -> void:
	assert_true(bool(EraMenus.layout(2, "bag").icons))
	assert_eq(str(EraMenus.layout(2, "bag").pockets), "tabs")
	assert_true(bool(EraMenus.layout(2, "party").sprite_anim), "small animated team icons")
	assert_eq(str(EraMenus.layout(2, "pause").header), "clock")
	assert_eq(str(EraMenus.layout(2, "dex").area), "map")

func test_era_three_brings_tabs_badges_and_page_tools() -> void:
	var s: Dictionary = EraMenus.layout(3, "summary")
	assert_true(bool(s.tabs))
	assert_eq((s.pages as Array).size(), 4, "info, values, arts, merits")
	assert_eq(str(EraMenus.layout(3, "party").badges), "colour")
	assert_true(bool(EraMenus.layout(3, "bag").pocket_art))
	assert_has(EraMenus.layout(3, "dex").tools, "cry")
	assert_has(EraMenus.layout(3, "dex").tools, "size")

func test_era_four_is_the_touch_layout() -> void:
	for s: String in EraMenus.screens():
		var l: Dictionary = EraMenus.layout(4, s)
		assert_eq(str(l.panel), "bottom", s + " keeps the info panel")
		assert_gte(int(l.row_h), EraMenus.TOUCH_MIN_ROW, s + " rows are finger sized")
	assert_eq(int(EraMenus.layout(4, "pause").columns), 2, "big buttons")
	assert_true(bool(EraMenus.layout(4, "party").drag), "drag to reorder")
	assert_true(bool(EraMenus.layout(4, "dex").search_bar))
	assert_true(bool(EraMenus.layout(4, "dex").form_names))

func test_era_five_lives() -> void:
	assert_eq(str(EraMenus.layout(5, EraMenus.LIST).anim), "slide")
	assert_true(bool(EraMenus.layout(5, "summary").sprite_anim))
	assert_true(bool(EraMenus.layout(5, "dex").region_tabs), "region and season dex")
	assert_true(bool(EraMenus.layout(5, "pause").quick_bar), "quick-register shortcuts")
	assert_true(bool(EraMenus.layout(5, "map").pulse))

func test_every_era_looks_different_from_the_one_before() -> void:
	for e: int in range(2, 6):
		var changed: int = 0
		for s: String in EraMenus.screens():
			if str(_strip(EraMenus.layout(e, s))) != str(_strip(EraMenus.layout(e - 1, s))):
				changed += 1
		assert_gte(changed, 4, "era %d changes most screens" % e)

func _strip(l: Dictionary) -> Dictionary:
	l.erase("era")
	return l

# --- Logic ----------------------------------------------------------------------

func test_summary_pages_per_era_hold_every_section() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	assert_eq(EraMenus.summary_pages(s, 1).size(), 2)
	assert_eq(EraMenus.summary_pages(s, 2).size(), 3)
	assert_eq(EraMenus.summary_pages(s, 3).size(), 4)
	for e: int in range(1, 6):
		var all: String = "\n".join(EraMenus.summary_pages(s, e, true))
		assert_string_contains(all, Loc.t("Arts of %s" % s.display_name()))
		assert_string_contains(all, Loc.t("Might %d" % s.atk()))
		assert_string_contains(all, Loc.t("Lead mark"))

func test_marks_follow_the_spirling() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	var ids: Array = EraMenus.marks(s, true).map(func(m: Dictionary) -> String: return str(m.id))
	assert_has(ids, "leader")
	s.favorite = true
	s.level = 26
	ids = EraMenus.marks(s).map(func(m: Dictionary) -> String: return str(m.id))
	assert_has(ids, "favourite")
	assert_has(ids, "ring25")
	assert_does_not_have(ids, "ring10", "only the highest ring mark")
	assert_does_not_have(ids, "leader")

func test_shortcuts_pin_at_most_four() -> void:
	var flags: Dictionary = {}
	var labels: Array[String] = ["Goals", "Team", "Satchel", "Spirlog", "Map", "Save"]
	for l: String in ["Team", "Satchel", "Spirlog", "Map"]:
		assert_true(EraMenus.quick_toggle(flags, l, labels))
	assert_false(EraMenus.quick_toggle(flags, "Save", labels), "the fifth is refused")
	assert_eq(EraMenus.quick_list(flags, labels), ["Team", "Satchel", "Spirlog", "Map"] as Array[String])
	assert_true(EraMenus.quick_toggle(flags, "Team", labels), "unpin")
	assert_eq(EraMenus.quick_list(flags, labels).size(), 3)

func test_clock_and_season() -> void:
	var t: String = EraMenus.clock_text({"weekday": 2, "hour": 7, "minute": 5}, DayCycle.current())
	assert_string_starts_with(t, Loc.t("Tuesday") + " 07:05")
	assert_eq(EraMenus.season_name(4), "Spring")
	assert_eq(EraMenus.season_name(12), "Winter")
	assert_has(EraMenus.season_elements(7), Elements.E.EMBER)
	assert_has(EraMenus.season_elements(7, [Elements.E.FROST] as Array[int]), Elements.E.FROST)

func test_height_and_size_compare() -> void:
	assert_eq(EraMenus.height_m("0.4 m"), 0.4)
	assert_eq(EraMenus.height_m("1,2 m"), 1.2)
	assert_eq(EraMenus.height_m("tall"), 0.0)
	var h: Vector2 = EraDexViews.SizeCompare.heights(1.6, 0.4, 80.0)
	assert_eq(h, Vector2(80, 20))
	h = EraDexViews.SizeCompare.heights(1.6, 3.2, 80.0)
	assert_eq(h, Vector2(40, 80), "the taller one fills the room")

func test_save_card_lines() -> void:
	var lines: Array[String] = EraMenus.save_lines("Rowan", "Fernstair", 3 * 3600 + 7 * 60, 14, 11, 4)
	assert_eq(lines.size(), 5)
	assert_string_contains(lines[2], "3:07")
	assert_eq(EraMenus.save_lines("R", "F", 0, 0, 0, 1, "Monday 10:00").size(), 6, "Era I keeps the clock on the card")

func test_motion_stands_still_when_reduced() -> void:
	assert_eq(EraMenuKit.bob_at(300, 0, true), 0)
	assert_ne(EraMenuKit.bob_at(0, 0, false), EraMenuKit.bob_at(0, 1, false), "rows bob out of step")
	assert_eq(EraSummary.breathe_at(1.3, true), 1.0)
	assert_gt(EraSummary.breathe_at(0.6, false), 1.0)

func test_drag_finds_the_nearest_row() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 50, 20), Rect2(0, 22, 50, 20), Rect2(0, 44, 50, 20)]
	assert_eq(EraPartyDrag.row_at(rects, 5.0), 0)
	assert_eq(EraPartyDrag.row_at(rects, 50.0), 2)
	assert_eq(EraPartyDrag.row_at(rects, 200.0), 2, "below the list: the last row")
	assert_eq(EraPartyDrag.row_at([] as Array[Rect2], 5.0), -1)

func test_symbols_start_in_era_two() -> void:
	for id: String in EraMenuArt.GLYPHS:
		assert_eq((EraMenuArt.GLYPHS[id] as Array).size(), EraMenuArt.SIZE, id)
		for row: Variant in EraMenuArt.GLYPHS[id]:
			assert_eq(str(row).length(), EraMenuArt.SIZE, id)
	assert_null(EraMenuArt.icon("Team", 1))
	assert_not_null(EraMenuArt.icon("Team", 2))
	assert_eq(EraMenuArt.icon("Team", 4, 18).get_width(), 18)
	assert_null(EraMenuKit.icon_for("Team", EraMenus.layout(1, "pause")))

func test_every_start_menu_entry_has_a_symbol_and_hint() -> void:
	for l: String in PauseMenu.menu_labels(true, true, true, true, true, true):
		assert_true(EraMenuKit.PAUSE_HINTS.has(l), l + " explains itself in the info panel")
	assert_true(EraMenuKit.PAUSE_HINTS.has(EraMenuKit.SHORTCUTS))

# --- Every screen opens in every era --------------------------------------------

func _menu() -> PauseMenu:
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	add_child_autofree(menu)
	return menu

## Runs [param start] on [param menu], records the layout of the first list it shows, then
## backs out of everything. Returns {"done", "layout", "visible", "fit"}.
func _open(menu: PauseMenu, start: Callable) -> Dictionary:
	var state: Dictionary = {"done": false, "layout": {}, "visible": false, "fit": [], "summary": false}
	var runner := func() -> void:
		await start.call()
		state.done = true
	var seen: int = menu.picks
	runner.call()
	var frames: int = 0
	var looked: bool = false
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		var summary: Node = menu.get_node_or_null("era_summary")
		var card: Node = menu.get_node_or_null("era_card")
		if summary != null:
			state.summary = true
			summary.emit_signal("closed")
		elif card != null:
			card.emit_signal("closed")
		elif menu._info_wait:
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			if not looked:
				# Let the layout settle before measuring.
				looked = true
				await wait_process_frames(3)
				state.layout = menu.picker.layout.duplicate()
				state.visible = menu.picker.visible
				state.fit = EraMenuKit.fit_problems(menu, false)
			seen = menu.picks
			menu.picker.picked.emit(-1)
	return state

func _setup() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.reduce_motion = true
	GameState.tips_enabled = false
	GameState.add_item("tonic", 2)
	GameState.mark_seen("Kindlop", true)

func test_every_screen_opens_in_every_era() -> void:
	_setup()
	for e: int in range(1, 6):
		_era(e)
		var menu := _menu()
		await wait_process_frames(1)
		var screens: Dictionary = {
			"party": menu.run_team,
			"bag": menu.run_bag,
			"dex": menu.run_spirlog,
			"save": menu.run_save,
			"options": menu.run_settings,
			"shop": func() -> void: await ShopMenu._run_tab(menu, "riftglass"),
			"map": func() -> void: await WorldMapMenu.run(menu, "fernstair"),
		}
		for s: String in screens:
			var st: Dictionary = await _open(menu, screens[s])
			assert_true(st.done, "era %d %s closes" % [e, s])
			assert_true(st.visible, "era %d %s shows a list" % [e, s])
			assert_eq(str(st.layout.get("screen", "")), s, "era %d %s uses its layout" % [e, s])
			assert_eq(int(st.layout.get("era", 0)), e, "era %d %s" % [e, s])
			assert_eq(st.fit, [], "era %d %s fits the screen" % [e, s])
			assert_has(menu.screens_shown, s)
		menu.queue_free()
		await wait_process_frames(1)

func test_start_menu_and_summary_open_in_every_era() -> void:
	_setup()
	for e: int in range(1, 6):
		_era(e)
		var menu := _menu()
		await wait_process_frames(1)
		var st: Dictionary = await _open(menu, menu.run)
		assert_true(st.done, "era %d start menu closes" % e)
		assert_eq(str(st.layout.get("screen", "")), "pause", "era %d" % e)
		assert_eq(int(st.layout.get("columns", 0)), int(EraMenus.layout(e, "pause").columns), "era %d columns" % e)
		var s: Spirling = GameState.party[0]
		var sum: Dictionary = await _open(menu, func() -> void: await menu.run_summary(s, true))
		assert_true(sum.done, "era %d summary closes" % e)
		assert_eq(bool(sum.summary), bool(EraMenus.layout(e, "summary").tabs), "era %d tabbed summary from III" % e)
		assert_has(menu.screens_shown, "summary")
		menu.queue_free()
		await wait_process_frames(1)

func test_drag_moves_a_team_member() -> void:
	_setup()
	GameState.party.append(Spirling.new(Database.species("Mossling"), 5))
	_era(4)
	var menu := _menu()
	await wait_process_frames(1)
	var d: EraPartyDrag = EraPartyDrag.attach(menu, GameState.party.size())
	var first: String = GameState.party[0].data.species_name
	var got: Array = []
	menu.picker.picked.connect(func(i: int) -> void: got.append(i))
	d.drop(0, 1)
	assert_eq(GameState.party[1].data.species_name, first)
	assert_eq(got, [EraMenus.DRAG_PICKED])
	d.drop(0, 9)
	assert_eq(got.size(), 1, "a slot outside the team does nothing")
