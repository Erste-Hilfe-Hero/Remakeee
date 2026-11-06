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

func test_every_settings_row_has_its_own_action() -> void:
	var was: bool = GameState.in_game
	GameState.in_game = true
	var rows: Array[Array] = MenuHost.settings_rows()
	GameState.in_game = was
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/MenuHost.gd")
	var body: String = src.substr(src.find("func _settings_action"))
	body = body.substr(0, body.find("\nconst "))
	var keys: Dictionary[String, bool] = {}
	for r: Array in rows:
		var key: String = str(r[0])
		assert_false(keys.has(key), "duplicate settings key " + key)
		keys[key] = true
		assert_eq(body.count("\"%s\":" % key), 1, "exactly one action for " + key)
	assert_true(keys.has("account") and keys.has("difficulty") and keys.has("iron_oath"),
		"Account, Difficulty and Iron Oath are all reachable")

func test_difficulty_and_iron_oath_only_during_a_journey() -> void:
	var was: bool = GameState.in_game
	GameState.in_game = false
	var keys: Array[String] = []
	for r: Array in MenuHost.settings_rows():
		keys.append(str(r[0]))
	GameState.in_game = was
	assert_false("difficulty" in keys)
	assert_false("iron_oath" in keys)
	assert_true("account" in keys)

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
