extends GutTest
## Area 5 pad items: only A in a talk box (1818), notice when a gamepad goes (1819), the held
## direction lights up while the finger slides (1824).

func before_each() -> void:
	VirtualPad.force_visible = true
	VirtualPad.apply_settings()
	VirtualPad.set_wanted(true)

func after_each() -> void:
	VirtualPad.set_wanted(false)
	VirtualPad.force_visible = false

func _shown() -> Array[String]:
	var out: Array[String] = []
	for b: TouchScreenButton in VirtualPad._buttons:
		if b.visible:
			out.append(str(b.action) if b.action != &"" else str(b.get_meta("dir", "")))
	return out

func test_talk_mode_shows_only_a() -> void:
	assert_eq(_shown().size(), 7, "walking: D-pad, A, B and menu")
	VirtualPad.set_talk(true)
	assert_true(VirtualPad.visible)
	assert_eq(_shown(), ["ui_accept"] as Array[String], "item 1818: only A in a talk box")
	assert_false(VirtualPad.covers(VirtualPad.dpad_rect().get_center()), "the hidden D-pad takes no taps")
	VirtualPad.set_wanted(true)
	assert_eq(_shown().size(), 7, "after the talk everything is back")

func test_talk_mode_ignores_dpad_touches() -> void:
	VirtualPad.set_talk(true)
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.index = 0
	t.position = VirtualPad.dpad_rect().position + Vector2(VirtualPad._dpad * 1.5, 2)
	VirtualPad._input(t)
	assert_eq(VirtualPad.held_dir(), "", "no walking during a talk")

func test_gamepad_gone_shows_a_notice() -> void:
	VirtualPad._on_joy_changed(0, false)
	assert_eq(VirtualPad.notice_text(), VirtualPad.PAD_GONE_TEXT, "item 1819")
	VirtualPad._process(VirtualPad.NOTICE_SECONDS + 0.1)
	assert_eq(VirtualPad.notice_text(), "", "gone after 2 s")

func test_held_direction_lights_while_sliding() -> void:
	var r: Rect2 = VirtualPad.dpad_rect()
	var side: float = r.size.x
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.index = 0
	t.position = r.position + Vector2(side / 2.0, 2)
	VirtualPad._input(t)
	assert_eq(VirtualPad.held_dir(), "ui_up")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = r.position + Vector2(side - 2, side / 2.0)
	VirtualPad._input(drag)
	assert_eq(VirtualPad.held_dir(), "ui_right", "item 1824: sliding changes the direction")
	for b: TouchScreenButton in VirtualPad._buttons:
		var own: String = str(b.get_meta("dir", ""))
		if own == "ui_right":
			assert_eq(b.texture_normal, b.get_meta("down_tex"), "the held arrow is drawn pressed")
		elif not own.is_empty():
			assert_eq(b.texture_normal, b.get_meta("up_tex"))
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.index = 0
	up.position = drag.position
	VirtualPad._input(up)
	assert_eq(VirtualPad.held_dir(), "")
