extends GutTest
## Plan area 5 (controls, menus, accessibility): tap safety, settings by key, the back button.

func _click(pressed: bool, at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	return e

func _scripts_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out

# --- 2062 settings rows by key ------------------------------------------------------

func _settings_keys(in_game: bool) -> Array[String]:
	var was: bool = GameState.in_game
	GameState.in_game = in_game
	var keys: Array[String] = []
	for g: String in ["game", "sound"]:
		for r: Array in MenuHost.settings_rows(g):
			keys.append(str(r[0]))
	GameState.in_game = was
	return keys

func test_every_settings_row_has_its_own_action() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/MenuHost.gd")
	var body: String = src.substr(src.find("func _settings_action"))
	body = body.substr(0, body.find("\nconst "))
	var seen: Dictionary[String, bool] = {}
	for key: String in _settings_keys(true):
		assert_false(seen.has(key), "duplicate settings key " + key)
		seen[key] = true
		assert_eq(body.count("\"%s\":" % key), 1, "exactly one action for " + key)
		assert_true(MenuHost.SETTING_HINTS.has(key), "explanation line for " + key)
	assert_true(seen.has("difficulty") and seen.has("iron_oath"), "Difficulty and Iron Oath are reachable")
	var groups: Array[String] = []
	for g: Array in MenuHost.SETTINGS_GROUPS:
		groups.append(str(g[0]))
		assert_true(MenuHost.SETTING_HINTS.has(str(g[0])))
	assert_true("account" in groups, "Account opens the account menu, not the Iron Oath")
	assert_lte(groups.size(), 7, "the main settings list has at most seven rows")
	var run: String = src.substr(src.find("func run_settings"), 800)
	for g: String in groups:
		assert_true(run.contains("\"%s\": " % g), "group %s has an action" % g)

func test_difficulty_and_iron_oath_only_during_a_journey() -> void:
	var keys: Array[String] = _settings_keys(false)
	assert_false("difficulty" in keys)
	assert_false("iron_oath" in keys)
	assert_true("volume" in keys)

func test_volume_steps_by_ten_and_never_wraps() -> void:
	assert_almost_eq(MenuHost.step_volume(1.0, 1), 1.0, 0.001, "no jump from 100 to 0")
	assert_almost_eq(MenuHost.step_volume(1.0, -1), 0.9, 0.001)
	assert_almost_eq(MenuHost.step_volume(0.0, -1), 0.0, 0.001)
	assert_almost_eq(MenuHost.step_volume(0.45, 1), 0.6, 0.001)

func test_text_colours_reach_contrast() -> void:
	var was: bool = UITheme.high_contrast
	for hc: bool in [false, true]:
		var p: Array[Color] = UITheme.HIGH_CONTRAST_PALETTE if hc else UITheme.NORMAL_PALETTE
		var bg: Color = p[0]
		var ink: Color = p[1]
		var mid: Color = p[2]
		var accent: Color = p[3]
		var dis: Color = p[4]
		var tag: String = "high contrast" if hc else "normal"
		assert_gte(UITheme.contrast(ink, bg), 4.5, tag + ": ink on paper")
		assert_gte(UITheme.contrast(bg, ink), 4.5, tag + ": focused row")
		assert_gte(UITheme.contrast(mid, bg), 4.5, tag + ": mid text on paper")
		assert_gte(UITheme.contrast(bg, mid), 4.5, tag + ": pressed row")
		assert_gte(UITheme.contrast(ink, accent), 4.5, tag + ": text fields and toasts")
		assert_gte(UITheme.contrast(dis, bg), 3.0, tag + ": greyed-out rows")
	UITheme.set_high_contrast(was)

func test_high_contrast_applies_to_open_menus() -> void:
	var was: bool = UITheme.high_contrast
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	UITheme.set_high_contrast(true)
	MenuHost.refresh_all_themes(get_tree())
	assert_eq(host.theme, UITheme.get_theme(), "the open menu took the new theme")
	UITheme.set_high_contrast(was)
	MenuHost.refresh_all_themes(get_tree())

func test_slider_rows_move_both_ways_and_rows_explain_themselves() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var res: Array = []
	_open(host, [{"text": "Volume: 50%", "slider": true, "hint": "All sound."}, {"text": "Other"}] as Array[Dictionary], res)
	await wait_process_frames(2)
	assert_true(host.picker._hint.visible)
	assert_eq(host.picker._hint.text, "All sound.")
	var left := InputEventAction.new()
	left.action = &"ui_left"
	left.pressed = true
	host.picker._row_input(left, 0, 0)
	await wait_process_frames(1)
	assert_eq(res, [0])
	assert_eq(host.picker.last_dir, -1)

func test_fixed_back_button_and_more_arrows() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var many: Array[Dictionary] = []
	for i: int in 30:
		many.append({"text": "Row %d" % i})
	var res: Array = []
	_open(host, many, res)
	await wait_process_frames(3)
	assert_true(host.picker._back.visible, "a back button sits next to the title")
	assert_false(host.picker.more_above())
	assert_true(host.picker.more_below(), "an arrow says more rows wait below")
	host.picker._opened_ms -= 1000
	host.picker._back.pressed.emit()
	await wait_process_frames(1)
	assert_eq(res, [-1])

# --- 1781, 1782, 1785, 2088, 2211 list picker -----------------------------------------

func _open(host: MenuHost, entries: Array[Dictionary], result: Array) -> void:
	result.append(await host.pick("Test", entries))

func test_pick_focuses_exactly_one_enabled_row() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var res: Array = []
	_open(host, [{"text": "Locked", "disabled": true}, {"text": "Open"}, {"text": "Also"}] as Array[Dictionary], res)
	await wait_process_frames(2)
	var focused: int = 0
	for b: Button in host.picker.buttons():
		if b.has_focus():
			focused += 1
			assert_false(b.disabled, "focus never sits on a greyed-out row")
		assert_eq(b.action_mode, BaseButton.ACTION_MODE_BUTTON_RELEASE, "rows fire on release")
		assert_false(b.accessibility_name.is_empty(), "rows tell screen readers what they are")
	assert_eq(focused, 1)
	assert_true(host.picker.buttons()[1].has_focus())
	assert_eq(host.picker._scroll.scroll_deadzone, 6)
	assert_eq(host._info_scroll.scroll_deadzone, 6)
	host.picker.picked.emit(-1)
	await wait_process_frames(1)
	assert_eq(res, [-1])

func test_drag_or_early_tap_does_not_pick_a_row() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var res: Array = []
	_open(host, [{"text": "One"}, {"text": "Two"}] as Array[Dictionary], res)
	await wait_process_frames(1)
	var p: ListPicker = host.picker
	# A finger that went down right as the list opened (second tap of a double tap).
	p._opened_ms = Time.get_ticks_msec()
	p._input(_click(true, Vector2(40, 30)))
	p._input(_click(false, Vector2(40, 30)))
	p._on_row(0)
	assert_eq(res.size(), 0, "a tap inside the guard time is ignored")
	# A swipe that scrolls the list.
	p._opened_ms = Time.get_ticks_msec() - 1000
	p._input(_click(true, Vector2(40, 60)))
	p._input(_click(false, Vector2(40, 30)))
	p._on_row(0)
	assert_eq(res.size(), 0, "scrolling never picks a row")
	# A calm tap after the guard.
	p._input(_click(true, Vector2(40, 30)))
	p._input(_click(false, Vector2(42, 32)))
	p._on_row(1)
	await wait_process_frames(1)
	assert_eq(res, [1])

func test_keyboard_press_is_never_blocked() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var res: Array = []
	_open(host, [{"text": "One"}] as Array[Dictionary], res)
	await wait_process_frames(1)
	host.picker._opened_ms = Time.get_ticks_msec()
	host.picker._on_row(0)
	await wait_process_frames(1)
	assert_eq(res, [0], "no pointer release this frame: the press came from keys or a pad")

func test_list_remembers_the_last_row_per_title() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var entries: Array[Dictionary] = [{"text": "A"}, {"text": "B"}, {"text": "C"}]
	var res: Array = []
	_open(host, entries, res)
	await wait_process_frames(1)
	host.picker.picked.emit(2)
	await wait_process_frames(1)
	_open(host, entries, res)
	await wait_process_frames(2)
	assert_true(host.picker.buttons()[2].has_focus(), "coming back keeps your place")
	host.picker.picked.emit(-1)
	await wait_process_frames(1)

func test_danger_question_starts_on_no_and_marks_yes() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var res: Array = []
	var run := func() -> void:
		res.append(await host.confirm_danger("Delete?", "Delete", "Keep"))
	run.call()
	await wait_process_frames(2)
	var rows: Array[Button] = host.picker.buttons()
	assert_true(rows[0].has_focus(), "focus starts on the safe answer")
	assert_eq(rows[0].text, "Keep")
	assert_true(rows[1].text.begins_with("! "), "yes carries a warning mark")
	assert_eq(host.picker._guard_ms, ListPicker.DANGER_GUARD_MS)
	host.picker.picked.emit(1)
	await wait_process_frames(1)
	assert_eq(res, [true])

# --- 1783 text box read guard ---------------------------------------------------------

func test_double_tap_does_not_skip_a_line_unread() -> void:
	var tb := TextBox.new()
	add_child_autofree(tb)
	var count: Array[int] = [0]
	tb.advanced.connect(func() -> void: count[0] += 1)
	tb._typing = true
	tb._skip_or_advance(true)
	tb._waiting = true
	tb._skip_or_advance(true)
	assert_eq(count[0], 0, "the second tap right after the line appeared is ignored")
	tb._shown_ms -= TextBox.READ_GUARD_MS + 1
	tb._skip_or_advance(true)
	assert_eq(count[0], 1)

# --- 1784 every handler uses TapInput -------------------------------------------------

func test_ui_and_overworld_read_taps_only_through_tap_input() -> void:
	var files: Array[String] = _scripts_in("res://scripts/ui") + _scripts_in("res://scripts/overworld")
	assert_gt(files.size(), 10)
	for path: String in files:
		if path.ends_with("TapInput.gd"):
			continue
		var src: String = FileAccess.get_file_as_string(path)
		assert_false(src.contains("InputEventScreenTouch"), path + " reads raw touches; use TapInput")
		assert_false(src.contains("InputEventMouseButton"), path + " reads raw clicks; use TapInput")

# --- 1787 Android back button ---------------------------------------------------------

func test_back_button_does_not_quit_the_game() -> void:
	assert_false(bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)))
	for path: String in ["res://scripts/overworld/Overworld.gd", "res://scripts/ui/TitleScreen.gd"]:
		assert_true(FileAccess.get_file_as_string(path).contains("NOTIFICATION_WM_GO_BACK_REQUEST"), path)

func test_back_button_works_like_b_in_menus() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var res: Array = []
	_open(host, [{"text": "One"}] as Array[Dictionary], res)
	await wait_process_frames(1)
	for ev: InputEventAction in BackButton.cancel_events():
		host.picker._unhandled_input(ev)
	await wait_process_frames(1)
	assert_eq(res, [-1])

# --- 1889-1892 team, 1914-1915 satchel, 1934-1936 Spirlog -----------------------------

func _a_spirling() -> Spirling:
	Database.load_all()
	return Spirling.new(Database.species("Mossling"), 5)

func test_team_row_shows_sprite_bar_and_worn_out_word() -> void:
	var s: Spirling = _a_spirling()
	var e: Dictionary = MenuHost.party_entry(s)
	assert_true(e.decorate is Callable, "Vigor bar and element icons are drawn on the row")
	assert_false(str(e.text).contains("(out)"))
	s.hp = 0
	var worn: Dictionary = MenuHost.party_entry(s)
	assert_string_contains(str(worn.hint), "worn out", "the hint says it")
	assert_eq(str(worn.say), "worn out", "the screen reader says it")
	assert_lt(PixelFont.get_font().get_string_size(str(worn.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 70.0,
		"the name fits beside sprite, bar and element icon")
	assert_false(MenuHost.party_line(s).contains("(out)"))

func test_summary_has_pages_with_full_words() -> void:
	var pages: Array[String] = MenuHost.summary_pages(_a_spirling())
	assert_eq(pages.size(), 4, "values, arts, gift and keepsake, temperament")
	assert_string_contains(pages[0], "Might")
	assert_string_contains(pages[0], "Pace")
	assert_false(pages[0].contains("MGT"), "no short forms")
	assert_string_contains(pages[3], "Temperament")

func test_info_pages_turn_with_left_and_right() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var done: Array[bool] = [false]
	var run := func() -> void:
		await host.info_pages(["Page A", "Page B"] as Array[String])
		done[0] = true
	run.call()
	await wait_process_frames(1)
	assert_string_contains(host._info_label.text, "Page A")
	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	host._unhandled_input(right)
	await wait_process_frames(1)
	assert_string_contains(host._info_label.text, "Page B")
	assert_string_contains(host._info_label.text, "2/2")
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	host._unhandled_input(back)
	await wait_process_frames(1)
	assert_true(done[0])

func test_satchel_sorts_items_into_tabs() -> void:
	assert_eq(PauseMenu.bag_tab({"gear": true}), 3)
	assert_eq(PauseMenu.bag_tab({"teaches": "x"}), 2)
	assert_eq(PauseMenu.bag_tab({"held": true}), 1)
	assert_eq(PauseMenu.bag_tab({"heal": 20}), 0)
	assert_eq(PauseMenu.bag_tab({"evolves": true}), 4)

func test_tabs_switch_with_left_and_right() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var res: Array = []
	var run := func() -> void:
		res.append(await host.pick("Satchel", [{"text": "Salve"}] as Array[Dictionary], true, -1, ListPicker.TAP_GUARD_MS, ["Care", "Gear"] as Array[String], 0))
	run.call()
	await wait_process_frames(1)
	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	host.picker._row_input(right, 0, 0)
	await wait_process_frames(1)
	assert_eq(ListPicker.tab_of(res[0]), 1)

func test_spirlog_uses_marks_and_map_names() -> void:
	assert_not_null(SpirlogMarks.seen())
	assert_not_null(SpirlogMarks.bonded())
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/PauseMenu.gd")
	assert_false(src.contains("\"*\" if is_bonded"), "no * and + marks")
	for sd: SpirlingData in Database.spirlings.values():
		for place: String in PauseMenu.found_on(sd.species_name):
			assert_false(place.contains("_"), "a real place name: " + place)

# --- Dialogues: speaker line, three lines, fast-forward, questions above the pad ---------

func _box() -> TextBox:
	var t := TextBox.new()
	t.size = Vector2(144, 44)
	add_child_autofree(t)
	return t

func test_npc_without_prefix_gets_a_name() -> void:
	var n := NPC.new()
	n.setup({"id": "fisher", "x": 0, "y": 0})
	assert_eq(Speakers.name_for(n), "Fisher")
	n.setup({"id": "lio", "x": 0, "y": 0, "trainer": "Wanderer Lio"})
	assert_eq(Speakers.name_for(n), "Wanderer Lio")
	n.setup({"id": "kestra_dock", "x": 0, "y": 0})
	assert_eq(Speakers.name_for(n), "Kestra")
	assert_eq(Speakers.name_for(null), "", "signs have no speaker")
	n.free()

func test_long_text_splits_into_three_line_windows() -> void:
	var font: Font = PixelFont.get_font()
	var long: String = "The fish stopped jumping the night the Rift opened. Even the reeds sound quieter. That's the Hush, they say, and nobody knows how long it stays."
	var pages: Array[String] = TextBox.split_lines(long, 120.0, font, 8, TextBox.MAX_LINES)
	assert_gt(pages.size(), 1, "the text goes on in a second window")
	var words: PackedStringArray = []
	for p: String in pages:
		var lines: PackedStringArray = p.split("\n")
		assert_lte(lines.size(), TextBox.MAX_LINES)
		for l: String in lines:
			assert_lte(font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 120.0, l)
			words.append_array(l.split(" ", false))
	assert_eq(" ".join(words), long, "no word is lost")

func test_box_shows_speaker_and_fast_forwards() -> void:
	var t: TextBox = _box()
	t.allow_fast_forward = true
	t.show_text("Good.", "Fisher")
	await wait_process_frames(1)
	assert_eq(t.speaker(), "Fisher", "the role shows when the line names no one")
	t.start_fast_forward()
	await wait_process_frames(1)
	t.show_text("Aldo: Good.", "Fisher")
	await wait_process_frames(1)
	assert_eq(t.speaker(), "Aldo", "a name in the line wins")
	assert_eq(t._label.text, "Good.")
	t.start_fast_forward()
	var done: Array = []
	var run := func() -> void:
		await t.show_text("Next line.")
		await t.show_text("And another.")
		done.append(true)
	run.call()
	await wait_process_frames(4)
	assert_eq(done, [true], "fast-forward does not wait for taps")
	t.visible = false
	assert_false(t.fast_forward, "a question (box hidden) stops fast-forward")

func test_fast_forward_needs_permission() -> void:
	var t: TextBox = _box()
	t.start_fast_forward()
	assert_false(t.fast_forward, "battles keep every line")

func test_questions_end_above_the_pad() -> void:
	var c := Control.new()
	add_child_autofree(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var h: float = c.get_viewport_rect().size.y
	MenuHost.keep_above_pad(c, h - 70.0)
	assert_lte(c.get_viewport_rect().size.y + c.offset_bottom, h - 70.0, "no row under the pad")
	var before: float = c.offset_bottom
	MenuHost.keep_above_pad(c, -1.0)
	assert_eq(c.offset_bottom, before, "hidden pad changes nothing")

# --- Pad field, always run, pause order, goals list -------------------------------------

func test_dpad_field_presses_one_direction_by_angle() -> void:
	var side: float = 60.0
	assert_eq(VirtualPad.dir_for(Vector2(30, 2), side), "ui_up")
	assert_eq(VirtualPad.dir_for(Vector2(30, 58), side), "ui_down")
	assert_eq(VirtualPad.dir_for(Vector2(2, 30), side), "ui_left")
	assert_eq(VirtualPad.dir_for(Vector2(58, 30), side), "ui_right")
	assert_eq(VirtualPad.dir_for(Vector2(57, 50), side), "ui_right", "a corner still presses a direction")
	assert_eq(VirtualPad.dir_for(Vector2(36, 29), side), "ui_right", "near the middle too")
	assert_eq(VirtualPad.dir_for(Vector2(30, 30), side), "", "the very middle keeps what is held")

func test_dpad_touch_presses_and_releases_actions() -> void:
	VirtualPad.force_visible = true
	VirtualPad.set_wanted(true)
	VirtualPad.apply_settings()
	var r: Rect2 = VirtualPad.dpad_rect()
	var t := InputEventScreenTouch.new()
	t.index = 3
	t.pressed = true
	t.position = r.position + Vector2(r.size.x - 2, r.size.y - 4)
	VirtualPad._input(t)
	assert_eq(VirtualPad.held_dir(), "ui_right")
	assert_true(Input.is_action_pressed("ui_right"))
	var d := InputEventScreenDrag.new()
	d.index = 3
	d.position = r.position + Vector2(r.size.x / 2.0, 1)
	VirtualPad._input(d)
	assert_eq(VirtualPad.held_dir(), "ui_up", "sliding the thumb changes direction")
	assert_false(Input.is_action_pressed("ui_right"))
	t.pressed = false
	VirtualPad._input(t)
	assert_eq(VirtualPad.held_dir(), "")
	assert_false(Input.is_action_pressed("ui_up"))
	assert_true(VirtualPad.covers(r.get_center()), "taps on the field do not walk")
	VirtualPad.set_wanted(false)
	VirtualPad.force_visible = false

func test_menu_button_is_larger_and_clear_of_b() -> void:
	VirtualPad.force_visible = true
	VirtualPad.set_wanted(true)
	for one: bool in [false, true]:
		GameState.one_hand = one
		VirtualPad.apply_settings()
		var menu: Rect2
		var b: Rect2
		for btn: TouchScreenButton in VirtualPad._buttons:
			var rect := Rect2(btn.position, (btn.shape as RectangleShape2D).size)
			if btn.action == &"menu":
				menu = rect
			elif btn.action == &"ui_cancel":
				b = rect
		assert_eq(menu.size, Vector2(16, 16))
		assert_gte(b.position.y - menu.end.y, 8.0, "gap to B")
	GameState.one_hand = false
	VirtualPad.apply_settings()
	VirtualPad.set_wanted(false)
	VirtualPad.force_visible = false

func test_always_run_setting_is_kept() -> void:
	var before: bool = GameState.always_run
	GameState.always_run = true
	var d: Dictionary = GameState.settings_to_dict()
	GameState.always_run = false
	GameState.settings_from_dict(d)
	assert_true(GameState.always_run)
	var keys: Array = []
	for r: Array in MenuHost.controls_rows():
		keys.append(r[0])
	assert_has(keys, "always_run")
	GameState.always_run = before

func test_pause_menu_order_is_fixed() -> void:
	assert_eq(PauseMenu.menu_labels(true, true, false),
		["Goals", "Map", "Team", "Satchel", "Spirlog", "Travel", "Friends", "Records", "Storage", "Save", "Save and to title", "Photo", "Settings"] as Array[String])
	var short: Array[String] = PauseMenu.menu_labels(false, false, false)
	assert_eq(short.find("Satchel"), 3, "places do not move when Travel is missing")
	assert_false("Storage" in short)
	assert_false("Leagues" in short)
	var league: Array[String] = PauseMenu.menu_labels(false, false, false, true)
	assert_eq(league.find("Leagues"), league.find("Friends") + 1, "Leagues sits right after Friends")

func test_goals_are_a_list_with_main_goal_first() -> void:
	var rows: Array[Dictionary] = PauseMenu.goal_rows({"aldo_gift": true}, "Today: a rare visitor stirs in Fernstair.")
	assert_gte(rows.size(), 3, "main goal, a side goal and the visitor")
	assert_true(rows[0].icon is Texture2D, "the main goal has its mark")
	var texts: Array[String] = []
	for r: Dictionary in rows:
		texts.append(str(r.text))
	assert_has(texts, "Today's visitor")
	for r: Dictionary in rows:
		assert_false(str(r.detail).is_empty(), "every row opens details")

# --- 2029 a mark shows where A does something ------------------------------------------

class FakeWorld extends Node:
	var map: MapData
	var npc_cell: Vector2i = Vector2i(-99, -99)
	var npc: NPC = NPC.new()
	func npc_at(c: Vector2i) -> NPC:
		return npc if c == npc_cell else null
	func _exit_tree() -> void:
		npc.free()

func test_interaction_mark_kinds() -> void:
	var w := FakeWorld.new()
	add_child_autofree(w)
	w.map = MapData.load_map("brindlewick")
	var s: Dictionary = w.map.signs[0]
	var sc := Vector2i(int(s.x), int(s.y))
	assert_eq(InteractHint.kind_at(w, sc + Vector2i.DOWN, sc), InteractHint.Kind.READ, "sign")
	w.npc_cell = Vector2i(3, 3)
	assert_eq(InteractHint.kind_at(w, Vector2i(3, 4), Vector2i(3, 3)), InteractHint.Kind.TALK, "person")
	assert_eq(InteractHint.kind_at(w, Vector2i(0, 1), Vector2i(-5, -5)), InteractHint.Kind.NONE, "nothing")

# --- Tips and onboarding (1982-1988) ---------------------------------------------------

func test_new_tips_exist_short_and_without_battle_words() -> void:
	for id: String in ["menu", "save", "team_order", "rest_spot", "travel", "satchel", "keepsake",
			"unfurl", "friends", "storage", "map_page"]:
		assert_true(Tips.LINES.has(id), id)
		assert_true(Tips.TOPICS.has(id), id + " is in the Guide")
		for touch: bool in [true, false]:
			var lines: Array[String] = Tips.lines_of(id, touch)
			assert_between(lines.size(), 1, 2, id)
			for l: String in lines:
				assert_false(l.is_empty(), id)
				for w: String in ["battle", "Battle", "damage", "Energy"]:
					assert_false(l.contains(w), id + ": " + l)

func test_tips_follow_the_input_device() -> void:
	assert_string_contains(Tips.lines_of("menu", true)[0], "Tap")
	assert_string_contains(Tips.lines_of("menu", false)[0], "Press")
	assert_string_contains(Tips.lines_of("gear", false)[0], "press A")
	assert_false(Tips.lines_of("gear", true)[0].contains("press A"))

func test_guide_lists_seen_tips_only() -> void:
	var before: Dictionary = GameState.flags.duplicate()
	var tips_on: bool = GameState.tips_enabled
	GameState.tips_enabled = true
	GameState.flags.clear()
	assert_eq(Tips.seen(), [] as Array[String])
	Tips.take("save")
	Tips.take("menu")
	assert_eq(Tips.seen(), ["menu", "save"] as Array[String], "in Guide order")
	assert_eq(Tips.take("save"), [] as Array[String], "each tip shows once")
	GameState.flags = before
	GameState.tips_enabled = tips_on

func test_menu_button_hint_until_first_menu() -> void:
	var before: Dictionary = GameState.flags.duplicate()
	GameState.flags.erase(VirtualPad.MENU_SEEN_FLAG)
	assert_true(VirtualPad.menu_hinted())
	GameState.set_flag(VirtualPad.MENU_SEEN_FLAG)
	assert_false(VirtualPad.menu_hinted())
	GameState.flags = before

func test_walk_hint_points_at_the_pad() -> void:
	VirtualPad.force_visible = true
	VirtualPad.set_wanted(true)
	VirtualPad.apply_settings()
	var h := WalkHint.new()
	h.text = "Walk: D-pad or tap a tile"
	add_child_autofree(h)
	await wait_process_frames(2)
	var tip: Vector2 = h.arrow_tip()
	assert_true(VirtualPad.dpad_rect().grow(2).has_point(tip + Vector2(0, 2)), "arrow ends at the D-pad")
	assert_lt(h._label.position.y + h._label.size.y, VirtualPad.dpad_rect().position.y, "note sits above the pad")
	VirtualPad.set_wanted(false)
	VirtualPad.force_visible = false

func test_new_game_to_first_step_is_short() -> void:
	# Fast text: every line types at TEXT_CPS[FAST], plus about 1 s to read and tap, plus the
	# partner pick and the fades. Must stay under 90 s (item 1986).
	var cps: float = GameState.TEXT_CPS[GameState.TextSpeed.FAST]
	var seconds: float = 0.6 + 12.0
	var flags: Dictionary = {}
	for ref: String in ["story/prologue", "lighthouse/morning", "lighthouse/aldo"]:
		for l: String in Dialogue.lines_for(Dialogue.get_entry(ref), flags):
			seconds += l.length() / cps + 1.0
		flags["got_starter"] = true
	seconds += Tips.lines_of("save").size() * 2.0
	assert_lt(seconds, 90.0, "about %d s from new game to walking" % int(seconds))

func _key(code: Key, uni: int = 0) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.unicode = uni
	k.pressed = true
	return k

func test_browser_keys_walk_confirm_back_and_menu() -> void:
	for pair: Array in [[KEY_W, "ui_up"], [KEY_A, "ui_left"], [KEY_S, "ui_down"], [KEY_D, "ui_right"],
			[KEY_UP, "ui_up"], [KEY_ENTER, "ui_accept"], [KEY_SPACE, "ui_accept"],
			[KEY_ESCAPE, "ui_cancel"], [KEY_BACKSPACE, "ui_cancel"], [KEY_M, "menu"]]:
		assert_true(_key(pair[0]).is_action(pair[1]), "%s -> %s" % [OS.get_keycode_string(pair[0]), pair[1]])
	assert_true("W A S D" in MenuHost.KEYS_HELP and "M: menu" in MenuHost.KEYS_HELP)
	var keys: Array = []
	for r: Array in MenuHost.controls_rows():
		keys.append(r[0])
	assert_has(keys, "keys_help")

func test_typed_letters_go_into_the_name_not_the_focus() -> void:
	var edit := LineEdit.new()
	add_child_autofree(edit)
	var k := NameKeyboard.new()
	k.target = edit
	add_child_autofree(k)
	assert_true(k.type_key(_key(KEY_W, "w".unicode_at(0))))
	assert_true(k.type_key(_key(KEY_A, "a".unicode_at(0))))
	assert_true(k.type_key(_key(KEY_SEMICOLON, "ö".unicode_at(0))))
	assert_eq(edit.text, "Waö")
	assert_true(k.type_key(_key(KEY_BACKSPACE)))
	assert_eq(edit.text, "Wa", "Backspace deletes instead of going back")
	assert_false(k.type_key(_key(KEY_UP)), "arrows still move between keys")
	k.set_mode(NameKeyboard.Mode.CODE)
	edit.text = ""
	assert_true(k.type_key(_key(KEY_7, "7".unicode_at(0))))
	assert_false(k.type_key(_key(KEY_MINUS, "-".unicode_at(0))), "codes take letters and digits only")
	assert_eq(edit.text, "7")

func test_gamepad_a_and_b_can_swap() -> void:
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	assert_true(a.is_action("ui_accept") and b.is_action("ui_cancel"))
	GameState.apply_pad_swap(true)
	assert_true(a.is_action("ui_cancel") and b.is_action("ui_accept"), "A goes back, B confirms")
	assert_false(a.is_action("ui_accept"))
	GameState.swap_ab_pad = true
	assert_true("swapped" in MenuHost.pad_help())
	GameState.swap_ab_pad = false
	GameState.apply_pad_swap(false)
	assert_true(a.is_action("ui_accept") and not a.is_action("ui_cancel"))
	assert_eq(MenuHost.pad_help(), MenuHost.PAD_HELP)

func _ab_spots() -> Dictionary:
	var out: Dictionary = {}
	for btn: TouchScreenButton in VirtualPad._buttons:
		out[str(btn.action)] = btn.position
	return out

func test_touch_a_and_b_swap_places_apart_from_the_gamepad() -> void:
	VirtualPad.force_visible = true
	VirtualPad.set_wanted(true)
	for one: bool in [false, true]:
		GameState.one_hand = one
		GameState.swap_ab_touch = false
		VirtualPad.apply_settings()
		var before: Dictionary = _ab_spots()
		GameState.swap_ab_touch = true
		VirtualPad.apply_settings()
		var after: Dictionary = _ab_spots()
		assert_eq(after["ui_accept"], before["ui_cancel"])
		assert_eq(after["ui_cancel"], before["ui_accept"])
		assert_eq(after["menu"], before["menu"], "the menu button stays")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	assert_true(a.is_action("ui_accept"), "the gamepad keeps its own setting")
	GameState.swap_ab_touch = false
	GameState.one_hand = false
	VirtualPad.apply_settings()
	VirtualPad.set_wanted(false)
	VirtualPad.force_visible = false

func test_swap_settings_are_kept() -> void:
	var d: Dictionary = GameState.settings_to_dict()
	d["swap_ab_touch"] = true
	d["swap_ab_pad"] = false
	GameState.settings_from_dict(d)
	assert_true(GameState.swap_ab_touch)
	assert_true(GameState.settings_to_dict()["swap_ab_touch"])
	GameState.swap_ab_touch = false

func test_startup_time_is_logged_once_per_stage() -> void:
	StartupLog.reset()
	var line: String = StartupLog.mark("title menu ready", 1840)
	assert_eq(line, "Startup: title menu ready after 1840 ms (goal 3000 ms)")
	assert_eq(StartupLog.mark("title menu ready", 2500), "", "only the first time counts")
	assert_eq(StartupLog.at("title menu ready"), 1840)
	assert_string_contains(StartupLog.line_for("title menu ready", 4200), "slower than the goal")
	StartupLog.reset()

func test_goals_list_ends_with_the_wider_tabs() -> void:
	var rows: Array[Dictionary] = PauseMenu.goal_tab_rows()
	assert_eq(rows.size(), 3, "Today, week and collection; the story is the list itself")
	assert_eq(str(rows[0].text), "Today...")
	for r: Dictionary in rows:
		assert_ne(str(r.detail), "")

func test_map_book_sits_after_goals_once_given() -> void:
	assert_false("Map book" in PauseMenu.menu_labels(false, false, false))
	var labels: Array[String] = PauseMenu.menu_labels(false, false, false, false, true)
	assert_eq(labels.find("Map book"), 1)

func test_one_hand_menus_sit_low_with_back_on_the_thumb_side() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var vp_h: float = host.get_viewport_rect().size.y
	for left: bool in [false, true]:
		GameState.one_hand = true
		GameState.left_handed = left
		var res: Array = []
		_open(host, [{"text": "One"}, {"text": "Two"}] as Array[Dictionary], res)
		await wait_process_frames(2)
		var list: Rect2 = host.picker.get_global_rect()
		assert_gte(list.position.y, vp_h * MenuHost.ONE_HAND_TOP - 0.5, "the list starts in the lower 60 percent")
		var back: Rect2 = host.picker.back_button().get_global_rect()
		assert_gt(back.get_center().y, list.get_center().y, "Back is at the bottom")
		if left:
			assert_lt(back.get_center().x, list.get_center().x, "left thumb: Back on the left")
		else:
			assert_gt(back.get_center().x, list.get_center().x, "right thumb: Back on the right")
		host.picker.picked.emit(-1)
		await wait_process_frames(1)
	GameState.one_hand = false
	GameState.left_handed = false
	var res2: Array = []
	_open(host, [{"text": "One"}] as Array[Dictionary], res2)
	await wait_process_frames(2)
	assert_lt(host.picker.get_global_rect().position.y, vp_h * MenuHost.ONE_HAND_TOP, "two hands: the list uses the whole height")
	var back2: Rect2 = host.picker.back_button().get_global_rect()
	assert_lt(back2.position.y, host.picker.get_global_rect().position.y + 24.0, "Back is back in the top corner")
	host.picker.picked.emit(-1)
	await wait_process_frames(1)

func test_large_text_uses_its_own_7x12_glyphs() -> void:
	for ch: String in PixelFont.GLYPHS:
		var g: Array[String] = PixelFont.large_glyph(ch)
		assert_eq(g.size(), PixelFont.LARGE_H, ch)
		for row: String in g:
			assert_eq(row.length(), PixelFont.LARGE_W, ch)
	var small: FontFile = PixelFont.get_font()
	var large: FontFile = PixelFont.get_large_font()
	assert_eq(large.font_name, "Chimora Pixel Groß")
	var w_small: float = small.get_string_size("Spirlog", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x
	var w_large: float = large.get_string_size("Spirlog", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x
	assert_gt(w_large, w_small * 1.2, "the same size number draws bigger letters")
	assert_gt(large.get_height(UITheme.FONT_SIZE), small.get_height(UITheme.FONT_SIZE))

func test_large_text_setting_switches_the_theme_and_wraps_rows() -> void:
	var d: Dictionary = GameState.settings_to_dict()
	d["large_text"] = true
	GameState.settings_from_dict(d)
	GameState.apply_display()
	assert_true(GameState.settings_to_dict()["large_text"])
	assert_eq(UITheme.get_theme().default_font, PixelFont.get_large_font())
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var res: Array = []
	_open(host, [{"text": "Battery saver: Off and a long tail"}] as Array[Dictionary], res)
	await wait_process_frames(2)
	var b: Button = host.picker.buttons()[0]
	assert_false(b.clip_text, "long rows wrap instead of being cut")
	assert_eq(b.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	host.picker.picked.emit(-1)
	d["large_text"] = false
	GameState.settings_from_dict(d)
	GameState.apply_display()
	assert_eq(UITheme.get_theme().default_font, PixelFont.get_font())
	var keys: Array = []
	for r: Array in MenuHost.display_rows():
		keys.append(r[0])
	assert_has(keys, "large_text")
