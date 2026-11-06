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
