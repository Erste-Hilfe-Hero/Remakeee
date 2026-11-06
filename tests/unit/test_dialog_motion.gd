extends GutTest
## Dialog box motion (plan area 6, items 2286 to 2288): rises in, sinks out, pages lift,
## the continue marker bobs.

func _box() -> TextBox:
	var t := TextBox.new()
	t.size = Vector2(144, 44)
	add_child_autofree(t)
	return t


func test_box_rises_into_place_when_opened() -> void:
	var saved: bool = GameState.reduce_motion
	GameState.reduce_motion = false
	var t := TextBox.new()
	t.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	t.offset_top = -44
	t.visible = false
	add_child_autofree(t)
	await wait_process_frames(1)
	var home: float = t.position.y
	t.visible = true
	assert_eq(t.position.y, home + TextBox.OPEN_RISE, "starts below its place")
	await wait_seconds(Juice.CURVES["open"].time + 0.1)
	assert_eq(t.rise, 0)
	assert_eq(t.position.y, home, "settles exactly")
	GameState.reduce_motion = saved

func test_continue_arrow_bobs_one_pixel() -> void:
	var t: TextBox = _box()
	t._arrow.visible = true
	var seen: Dictionary = {}
	for i: int in 8:
		t._bob_arrow(TextBox.ARROW_BOB_PERIOD / 8.0)
		seen[int(t._arrow_pad.content_margin_bottom)] = true
	assert_eq(seen.keys().size(), 2, "up and down")
	assert_true(seen.has(0) and seen.has(1))
	t._arrow.visible = false
	t._bob_arrow(0.1)
	assert_eq(int(t._arrow_pad.content_margin_bottom), 0)

func test_page_change_lifts_old_text_first() -> void:
	var t: TextBox = _box()
	t._label.text = "Old page."
	await wait_process_frames(2)
	var home: Vector2 = t._label.position
	var run := t._page_out
	run.call()
	await wait_seconds(TextBox.PAGE_OUT_TIME / 2.0)
	assert_lt(t._label.modulate.a, 1.0, "fading")
	assert_lte(t._label.position.y, home.y)
	await wait_seconds(TextBox.PAGE_OUT_TIME)
	assert_eq(t._label.position, home)
	assert_eq(t._label.modulate.a, 1.0)

func test_box_sinks_and_hides_when_closed() -> void:
	var saved: bool = GameState.reduce_motion
	GameState.reduce_motion = false
	var t := TextBox.new()
	t.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	t.offset_top = -44
	add_child_autofree(t)
	await wait_process_frames(1)
	var home: float = t.position.y
	await t.close()
	assert_false(t.visible)
	assert_eq(t.position.y, home, "back in place for the next opening")
	assert_eq(t.modulate.a, 1.0)
	GameState.reduce_motion = saved
