extends GutTest
## Plan item 2212: on a phone with a notch (47 px at the top) and a gesture bar (34 px at the
## bottom), no menu and no pad button may sit under them. The screen is the iPhone size in
## points, 390 x 844, so the insets are the device's own numbers.

const SCREEN := Vector2(390, 844)
const TOP: float = 47.0
const BOTTOM: float = 34.0

func before_each() -> void:
	SafeArea.simulate(SCREEN, TOP, BOTTOM)

func after_each() -> void:
	SafeArea.stop_simulating()
	GameState.one_hand = false
	GameState.left_handed = false
	VirtualPad.apply_settings()
	VirtualPad.set_wanted(false)
	VirtualPad.force_visible = false

func _safe() -> Rect2:
	return SafeArea.rect(get_viewport().get_visible_rect().size)

func _assert_inside(r: Rect2, what: String) -> void:
	var safe: Rect2 = _safe().grow(0.5)
	assert_true(safe.encloses(r), "%s %s stays inside the safe area %s" % [what, r, _safe()])

func test_simulated_insets_shrink_the_safe_rect() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var r: Rect2 = _safe()
	var scale: float = vp.y / SCREEN.y
	assert_almost_eq(r.position.y, TOP * scale, 0.01)
	assert_almost_eq(vp.y - r.end.y, BOTTOM * scale, 0.01)
	assert_gt(r.position.y, 0.0)
	SafeArea.stop_simulating()
	assert_eq(SafeArea.rect(vp), Rect2(Vector2.ZERO, vp), "headless without simulation: the full screen")

func test_menus_and_info_stay_clear_of_notch_and_bar() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(2)
	_assert_inside(host.picker.get_global_rect(), "list")
	_assert_inside(host._info_panel.get_global_rect(), "info window")
	var res: Array = []
	var run := func() -> void:
		res.append(await host.pick_strings("Title", ["One", "Two", "Three"] as Array[String]))
	run.call()
	await wait_process_frames(2)
	for b: Button in host.picker.buttons():
		_assert_inside(b.get_global_rect(), "row " + b.text)
	host.picker.picked.emit(-1)
	await wait_process_frames(1)

func test_pad_buttons_stay_clear_in_every_layout() -> void:
	VirtualPad.force_visible = true
	VirtualPad.set_wanted(true)
	for one: bool in [false, true]:
		for left: bool in [false, true]:
			GameState.one_hand = one
			GameState.left_handed = left
			VirtualPad.apply_settings()
			var tag: String = "one-hand=%s left=%s" % [one, left]
			_assert_inside(VirtualPad.dpad_rect(), "D-pad " + tag)
			for btn: TouchScreenButton in VirtualPad._buttons:
				var r := Rect2(btn.position, (btn.shape as RectangleShape2D).size)
				_assert_inside(r, "%s %s" % [btn.action, tag])
