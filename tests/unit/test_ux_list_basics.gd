extends GutTest
## Area 5 list items: focus wraps (1847), title tap scrolls up (1797), empty lists explain
## themselves (1856), confirm takes own words (1855), no focus sound after a tap (1849).

func _host() -> MenuHost:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	return host

func _rows(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in n:
		out.append({"text": "Row %d" % i})
	return out

func test_focus_wraps_around() -> void:
	var host: MenuHost = await _host()
	var p: ListPicker = host.picker
	p.pick("Wrap", _rows(4))
	await wait_process_frames(2)
	var b: Array[Button] = p.buttons()
	var first: Button = b[0]
	var last: Button = b[b.size() - 1]
	assert_eq(first.get_node(first.focus_neighbor_top), last, "up on the first row goes to Back")
	assert_eq(last.get_node(last.focus_neighbor_bottom), first, "down on Back goes to the first row")
	p.picked.emit(-1)

func test_title_tap_scrolls_to_top() -> void:
	var host: MenuHost = await _host()
	var p: ListPicker = host.picker
	p.pick("Long", _rows(30))
	await wait_process_frames(2)
	p._scroll.scroll_vertical = 120
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	p._title.gui_input.emit(up)
	assert_eq(p._scroll.scroll_vertical, 0)
	p.picked.emit(-1)

func test_empty_list_shows_a_sentence() -> void:
	var host: MenuHost = await _host()
	var p: ListPicker = host.picker
	p.pick("Empty", [] as Array[Dictionary])
	await wait_process_frames(1)
	assert_true(p.empty_label().visible)
	assert_eq(p.empty_label().text, ListPicker.EMPTY_TEXT)
	p.picked.emit(-1)
	p.pick("Full", _rows(2))
	await wait_process_frames(1)
	assert_false(p.empty_label().visible)
	p.picked.emit(-1)

func test_confirm_uses_own_words() -> void:
	var host: MenuHost = await _host()
	var answer: Array = []
	var run := func() -> void: answer.append(await host.confirm("Throw it away?", "Delete", "Keep"))
	run.call()
	await wait_process_frames(2)
	var texts: Array[String] = []
	for b: Button in host.picker.buttons():
		texts.append(b.text)
	assert_has(texts, "Delete")
	assert_has(texts, "Keep")
	host.picker.picked.emit(0)
	await wait_process_frames(1)
	assert_eq(answer, [true])

func test_tap_marks_pointer_input_and_keys_clear_it() -> void:
	var host: MenuHost = await _host()
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	host.picker._input(tap)
	assert_true(ListPicker.pointer_used, "after a tap the focus sound stays off")
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	host.picker._input(key)
	assert_false(ListPicker.pointer_used, "keys bring the focus sound back")
	ListPicker.last_device = "touch"
	ListPicker.pointer_used = false

func test_scroll_position_is_kept_per_list() -> void:
	var host: MenuHost = await _host()
	var p: ListPicker = host.picker
	p.pick("Deep", _rows(30), true, 20)
	await wait_process_frames(3)
	var at: int = p._scroll.scroll_vertical
	assert_gt(at, 0, "row 20 is further down")
	p.picked.emit(20)
	await wait_process_frames(1)
	p.pick("Other", _rows(3))
	await wait_process_frames(2)
	p.picked.emit(-1)
	p.pick("Deep", _rows(30))
	await wait_process_frames(5)
	assert_eq(p._scroll.scroll_vertical, at, "item 1853: back where it was")
	p.picked.emit(-1)

func test_list_fades_in_unless_reduce_motion() -> void:
	var host: MenuHost = await _host()
	var p: ListPicker = host.picker
	var before: bool = GameState.reduce_motion
	GameState.reduce_motion = false
	p.pick("Fade", _rows(2))
	assert_lt(p.modulate.a, 1.0, "starts see-through")
	await wait_seconds(ListPicker.FADE_IN + 0.1)
	assert_eq(p.modulate.a, 1.0)
	p.picked.emit(-1)
	GameState.reduce_motion = true
	p.pick("Still", _rows(2))
	assert_eq(p.modulate.a, 1.0, "Reduce motion: no fade")
	p.picked.emit(-1)
	GameState.reduce_motion = before

func test_long_info_shows_a_thin_scroll_bar() -> void:
	var host: MenuHost = await _host()
	var long_text: String = ""
	for i: int in 40:
		long_text += "Line %d of a long text.\n" % i
	host.info(long_text)
	await wait_process_frames(3)
	var r: Rect2 = host.info_bar_rect()
	assert_eq(r.size.x, float(MenuHost.INFO_BAR_W), "item 1840: 2 px wide")
	assert_gt(r.size.y, 0.0)
	host._close_info()
	await wait_process_frames(1)
	host.info("Short.")
	await wait_process_frames(3)
	assert_eq(host.info_bar_rect().size.y, 0.0, "no bar when the text fits")
	host._info_closed.emit()

func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e

func test_shoulder_buttons_jump_eight_rows() -> void:
	var host: MenuHost = await _host()
	var p: ListPicker = host.picker
	p.pick("Pages", _rows(30), true, 0)
	await wait_process_frames(2)
	p._input(_joy(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(p.focused_index(), ListPicker.PAGE_ROWS, "item 1846: R jumps down eight rows")
	p._input(_joy(JOY_BUTTON_LEFT_SHOULDER))
	p._input(_joy(JOY_BUTTON_LEFT_SHOULDER))
	assert_eq(p.focused_index(), 0, "L stops at the top")
	p.picked.emit(-1)
	ListPicker.last_device = "touch"

func test_held_pad_direction_repeats() -> void:
	var host: MenuHost = await _host()
	var p: ListPicker = host.picker
	p.pick("Hold", _rows(30), true, 0)
	await wait_process_frames(2)
	ListPicker.last_device = "pad"
	Input.action_press("ui_down")
	p._process(0.01)
	p._process(ListPicker.REPEAT_DELAY - 0.02)
	assert_eq(p.focused_index(), 0, "no repeat before 350 ms")
	p._process(0.02)
	assert_eq(p.focused_index(), 1, "first repeat at 350 ms")
	p._process(ListPicker.REPEAT_EVERY * 2.0 + 0.001)
	assert_eq(p.focused_index(), 3, "then every 80 ms")
	Input.action_release("ui_down")
	p._process(0.01)
	p.picked.emit(-1)
	ListPicker.last_device = "touch"

func test_continue_hint_follows_the_device() -> void:
	ListPicker.last_device = "touch"
	assert_eq(MenuHost.continue_hint(), "(tap to continue)")
	ListPicker.note_device(_joy(JOY_BUTTON_A))
	assert_eq(MenuHost.continue_hint(), "(A: continue)")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	ListPicker.note_device(key)
	assert_eq(MenuHost.continue_hint(), "(Enter: continue)")
	ListPicker.last_device = "touch"

func test_tapping_a_greyed_row_tells_why() -> void:
	var host: MenuHost = await _host()
	var p: ListPicker = host.picker
	var rows: Array[Dictionary] = [{"text": "Open"}, {"text": "Locked", "disabled": true, "why": "Opens after the second rift."}]
	p.pick("Why", rows)
	await wait_process_frames(3)
	var b: Button = p.buttons()[1]
	var at: Vector2 = b.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		get_viewport().push_input(e)
	await wait_process_frames(1)
	assert_eq(p.hint_text(), "Opens after the second rift.", "item 1842")
	assert_true(p.visible, "the list stays open")
	p.picked.emit(-1)
	ListPicker.last_device = "touch"
	ListPicker.pointer_used = false

func test_tap_buzz_only_when_switched_on() -> void:
	var host: MenuHost = await _host()
	var p: ListPicker = host.picker
	var before_vib: int = GameState.vibration
	var before_rm: bool = GameState.reduce_motion
	GameState.vibration = 2
	GameState.reduce_motion = false
	ListPicker.pointer_used = true
	Haptics.sent.clear()
	p.pick("Buzz", _rows(2))
	await wait_process_frames(1)
	p._opened_ms = -10000
	p._on_row(0)
	assert_eq(Haptics.sent.size(), 0, "off by default")
	GameState.tap_vibration = true
	p.pick("Buzz", _rows(2))
	await wait_process_frames(1)
	p._opened_ms = -10000
	p._on_row(0)
	assert_eq(Haptics.sent.size(), 1, "item 1791: one short buzz per tapped choice")
	assert_eq(int(Haptics.sent[0][0]), 15)
	GameState.tap_vibration = false
	GameState.vibration = before_vib
	GameState.reduce_motion = before_rm
	ListPicker.pointer_used = false
