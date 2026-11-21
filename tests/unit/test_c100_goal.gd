extends GutTest
## Plan Chimora 100, items 37-44 (goal and orientation): the goal line in Act I, the doors toward
## the goal on the map and the minimap, the free minimap in Act I, the pause menu's More, the
## Spirlog legend and the Welcome back card.

var _flags: Dictionary
var _billing: Dictionary
var _goal_line: bool
var _open: Callable
var _opened: Array[String] = []

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_flags = GameState.flags
	_billing = Billing.state
	_goal_line = GameState.goal_line
	_open = MenuHost.open_url
	_opened.clear()
	MenuHost.open_url = func(url: String) -> void: _opened.append(url)
	Billing.state = {"unlocks": {}}
	GameState.flags = {}
	GameState.goal_line = true

func after_each() -> void:
	GameState.flags = _flags
	Billing.state = _billing
	GameState.goal_line = _goal_line
	MenuHost.open_url = _open
	Loc.set_language("en")

# --- Item 37: goal line ---------------------------------------------------------------

func test_goal_line_follows_act_one_goals_and_ends_with_it() -> void:
	assert_true(QuestLog.in_act_one({}))
	assert_eq(QuestLog.hud_text({}), "See Aldo downstairs")
	assert_eq(QuestLog.hud_text({"aldo_gift": true}), "Go to the Map House")
	var rifts: Dictionary = {"aldo_gift": true, "met_kestra": true, "rift_cinder_sealed": true}
	assert_eq(QuestLog.hud_text(rifts), "Mend the Rifts (1/3)")
	var after: Dictionary = {"mirela_lamp": true}
	assert_false(QuestLog.in_act_one(after), "Act II starts after Mirela's map")
	assert_eq(QuestLog.hud_text(after), "", "no goal line after Act I")

func test_every_act_one_goal_has_a_short_line() -> void:
	var first_act: String = str((QuestLog.main_goals()[0] as Dictionary).act)
	for g: Variant in QuestLog.main_goals():
		var d: Dictionary = g
		assert_eq(d.has("hud"), str(d.get("act", "")) == first_act, "%s: a goal line exactly in Act I" % d.id)
		if d.has("hud"):
			# One line at 144 px: the flag, a few letters and "(k/n)" (5x9 font, 6 px a letter).
			assert_lte(str(d.hud).length(), 23, "%s fits one line" % d.id)
	Loc.set_language("de")
	assert_eq(QuestLog.hud_text({}), "Aldo unten besuchen")

func test_goal_line_shows_only_when_on_and_quiet() -> void:
	assert_true(GoalLine.wanted("See Aldo downstairs", true))
	assert_false(GoalLine.wanted("See Aldo downstairs", false), "hidden under talk, menus and scenes")
	assert_false(GoalLine.wanted("", true), "nothing after Act I")
	GameState.goal_line = false
	assert_false(GoalLine.wanted("See Aldo downstairs", true), "Settings > Game > Goal line: Off")

func test_goal_line_setting_is_saved_and_listed() -> void:
	GameState.goal_line = false
	var d: Dictionary = GameState.settings_to_dict()
	assert_false(bool(d.goal_line))
	GameState.goal_line = true
	GameState.settings_from_dict(d)
	assert_false(GameState.goal_line)
	GameState.settings_from_dict({})
	assert_true(GameState.goal_line, "on by default")
	var keys: Array[String] = []
	for r: Array in MenuHost.settings_rows("game"):
		keys.append(str(r[0]))
	assert_has(keys, "goal_line")
	assert_true(MenuHost.SETTING_HINTS.has("goal_line"))

# --- Item 38: doors toward the goal ----------------------------------------------------

func test_goal_maps_drop_the_rifts_already_mended() -> void:
	var f: Dictionary = {"aldo_gift": true, "met_kestra": true, "rift_mist_sealed": true}
	assert_eq(QuestLog.goal_maps(f), ["cinder_rift", "tide_rift"] as Array[String])
	assert_eq(QuestLog.goal_maps({"aldo_gift": true}), ["map_house"] as Array[String])

func test_goal_warps_mark_the_next_door() -> void:
	var town: MapData = MapData.load_map("brindlewick")
	assert_eq(QuestLog.goal_warps(town, ["map_house"] as Array[String]), [Vector2i(2, 4)] as Array[Vector2i], "the Map House door")
	var home: MapData = MapData.load_map("lighthouse")
	assert_eq(QuestLog.goal_warps(home, ["map_house"] as Array[String]), [Vector2i(4, 7)] as Array[Vector2i], "out of the lighthouse first")
	assert_eq(QuestLog.goal_warps(town, ["brindlewick"] as Array[String]), [] as Array[Vector2i], "nothing on the goal's own map")
	var north: Array[Vector2i] = QuestLog.goal_warps(town, ["cinder_rift"] as Array[String])
	assert_eq(north, [Vector2i(5, 0), Vector2i(6, 0)] as Array[Vector2i], "the road north toward the Cinder Rift")

func test_minimap_rings_the_goal_or_points_to_it() -> void:
	var m := MapData.from_dict("field_goal", {"rows": ["....................", "....................", "...................."], "outdoor": true})
	var mm := Minimap.new()
	add_child_autofree(mm)
	mm.refresh(m, Vector2i(2, 1), [] as Array[Vector2i], {})
	assert_eq(mm.goal_spot(Vector2i(3, 1)), [Vector2i(7, 6), true], "inside the window")
	assert_eq(mm.goal_spot(Vector2i(19, 1)), [Vector2i(11, 6), false], "outside: on the frame toward it")

func test_goal_marks_point_through_the_warp() -> void:
	var town: MapData = MapData.load_map("brindlewick")
	var gm := GoalMarks.new()
	add_child_autofree(gm)
	gm.show_cells(town, [Vector2i(2, 4)] as Array[Vector2i])
	assert_eq(gm.marks.size(), 1)
	assert_eq(str(gm.marks[0].dir), "up", "walk up into the Map House door")

# --- Item 39: free minimap in Act I ------------------------------------------------------

func test_minimap_is_free_in_act_one_only() -> void:
	assert_true(ShopEffects.owns_setting("minimap"))
	assert_eq(MenuHost.shop_or("minimap", "On"), "On")
	GameState.flags = {"mirela_lamp": true}
	assert_false(ShopEffects.owns_setting("minimap"), "after Act I it is the shop unlock again")
	Billing.state = {"unlocks": {"minimap": 1}}
	assert_true(ShopEffects.owns_setting("minimap"))

# --- Item 40/55: world map ---------------------------------------------------------------

func test_unvisited_places_fit_one_row() -> void:
	var known: Dictionary = {"brindlewick": WorldAtlas.Known.VISITED, "brackwater_fen": WorldAtlas.Known.SIGHTED}
	var rows: Array[Dictionary] = WorldMapMenu.place_rows(known)
	var sighted: Dictionary = rows[1]
	assert_true(bool(sighted.get("sighted", false)))
	assert_false(str(sighted.text).contains("("), "no cut-off \"(not yet visited)\": " + str(sighted.text))
	assert_eq(str(sighted.hint), "Not yet visited.")
	var f: Font = UITheme.font()
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		var w: float = f.get_string_size(WorldMapMenu._name("brackwater_fen"), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x
		assert_lte(w, 115.0, "%s: the row fits 115 px" % lang)

func test_rift_names_are_translated_in_japanese_and_korean() -> void:
	for lang: String in ["ja", "ko"]:
		var t: Dictionary = Loc.load_table(lang).strings
		for name: String in ["Mist Rift", "Cinder Rift", "Tidewater Rift"]:
			var v: String = str(t.get(name, ""))
			assert_false(v.is_empty(), "%s %s" % [lang, name])
			assert_false(v.contains("Mist") or v.contains("Cinder") or v.contains("Tidewater"), "%s %s fully translated: %s" % [lang, name, v])

func test_map_view_centres_the_known_places() -> void:
	var view := WorldMapView.new()
	view.current = "brindlewick"
	add_child_autofree(view)
	view.known = {"brindlewick": WorldAtlas.Known.VISITED, "fernstair": WorldAtlas.Known.VISITED}
	view.size = Vector2(132, 104)
	view.fit_known()
	assert_eq(view.zoom, 2, "two places fit at 2x")
	var box: Rect2 = view.cell_rect("brindlewick").merge(view.cell_rect("fernstair"))
	assert_almost_eq(box.get_center().x, view.size.x / 2.0, 1.0, "centred, not in a corner")
	var keep: Dictionary = view.state()
	var again := WorldMapView.new()
	again.restore(keep)
	assert_eq(again.zoom, 2, "zoom carries over to the next list")
	again.free()

# --- Item 41: pause menu More ----------------------------------------------------------

func test_more_opens_discord_and_returns_photo() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	await wait_process_frames(1)
	var got: Array[String] = []
	var runner := func() -> void:
		got.append(await menu.run_more(PauseMenu.menu_labels(false, false, false)))
	runner.call()
	await wait_process_frames(2)
	assert_eq(menu.last_title, PauseMenu.MORE)
	menu.picker.picked.emit(PauseMenu.MORE_ENTRIES.find("Join our Discord"))
	await wait_process_frames(2)
	assert_eq(_opened, [MenuHost.DISCORD_URL] as Array[String], "Discord stays one tap under More")
	menu.picker.picked.emit(PauseMenu.MORE_ENTRIES.find("Photo"))
	await wait_process_frames(2)
	assert_eq(got, ["Photo"] as Array[String])

# --- Item 42: Spirlog legend ------------------------------------------------------------

func test_spirlog_legend_explains_every_mark() -> void:
	var text: String = PauseMenu.spirlog_legend()
	for mark: String in ["+  ", "*  ", Collection.STAR, "~  ", GleamRules.STAR, "Seen at", "Wild at", "???"]:
		assert_string_contains(text, mark)
	Loc.set_language("de")
	assert_false(PauseMenu.spirlog_legend().contains("bonded"), "translated")

func test_page_lines_no_longer_contradict() -> void:
	assert_eq(Loc.t("Wild at: %s (%d of %d found)") % ["???", 0, 1], "Wild at: ??? (0 of 1 found)")
	Loc.set_language("de")
	assert_eq(Loc.t("Seen at: %s" % "Fernstair"), "Gesehen in: Fernstair")

# --- Item 44: Welcome back -------------------------------------------------------------

func test_welcome_back_says_where_and_what_next() -> void:
	var keep_map: String = GameState.current_map
	var keep_name: String = GameState.tamer_name
	GameState.current_map = "brindlewick"
	GameState.tamer_name = "Tess"
	var text: String = TitleScreen.welcome_text({"aldo_gift": true})
	GameState.current_map = keep_map
	GameState.tamer_name = keep_name
	assert_string_contains(text, "Welcome back, Tess!")
	assert_string_contains(text, "You are in Brindlewick.")
	assert_string_contains(text, "Goal: Go to the Map House")
