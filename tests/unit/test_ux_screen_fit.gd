extends GutTest
## iPhone Duo and other screen shapes (update 1.2.0): the pixel-art view fits every shape,
## and opening or closing a foldable while the game runs moves menus with the new safe area.
## Sizes are device pixels from Apple's spec pages: outer display 1398 x 2034, inner display
## 1878 x 2670; the inner display may also show the app on its side.

const BASE := Vector2i(144, 256)
const IPHONE := Vector2(1179, 2556)
const DUO_OUTER := Vector2(1398, 2034)
const DUO_INNER := Vector2(1878, 2670)
const DUO_INNER_SIDEWAYS := Vector2(2670, 1878)
const SQUARE := Vector2(2000, 2000)
const NARROW_SPLIT := Vector2(880, 1878)
const TABLET_SIDEWAYS := Vector2(2732, 2048)
const MONITOR := Vector2(2560, 1440)
const SHAPES: Array[Vector2] = [IPHONE, DUO_OUTER, DUO_INNER, DUO_INNER_SIDEWAYS, SQUARE, NARROW_SPLIT, TABLET_SIDEWAYS, MONITOR]

var _win: Window

func after_each() -> void:
	SafeArea.stop_simulating()
	if is_instance_valid(_win):
		_win.queue_free()
	_win = null

func _window(size: Vector2) -> Window:
	_win = Window.new()
	_win.size = Vector2i(size)
	_win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	add_child(_win)
	ScreenFit.apply(_win, BASE)
	return _win

func _resize(size: Vector2) -> void:
	_win.size = Vector2i(size)
	ScreenFit.apply(_win, BASE)

func test_phone_duo_and_tablet_shapes_expand_and_only_a_monitor_keeps_three_to_two() -> void:
	for s: Vector2 in [IPHONE, DUO_OUTER, DUO_INNER, NARROW_SPLIT, DUO_INNER_SIDEWAYS, SQUARE, TABLET_SIDEWAYS]:
		assert_eq(ScreenFit.aspect_mode(s), Window.CONTENT_SCALE_ASPECT_EXPAND, "%s expands" % s)
		assert_eq(ScreenFit.content_size(s, BASE), BASE, "%s keeps the era size" % s)
	assert_eq(ScreenFit.aspect_mode(MONITOR), Window.CONTENT_SCALE_ASPECT_KEEP, "16:9 keeps 3:2")
	assert_eq(ScreenFit.content_size(MONITOR, BASE), Vector2i(384, 256), "16:9 shows a 3:2 view")

func test_duo_inner_display_on_its_side_is_filled_without_bars() -> void:
	_window(DUO_INNER_SIDEWAYS)
	await wait_process_frames(1)
	var vp: Vector2 = _win.get_visible_rect().size
	assert_almost_eq(vp.x / vp.y, DUO_INNER_SIDEWAYS.x / DUO_INNER_SIDEWAYS.y, 0.03, "view %s has the screen's shape" % vp)

func test_no_size_falls_back_to_expand() -> void:
	assert_eq(ScreenFit.aspect_mode(Vector2.ZERO), Window.CONTENT_SCALE_ASPECT_EXPAND)
	assert_eq(ScreenFit.content_size(Vector2.ZERO, BASE), BASE)

func test_every_era_size_scales_with_the_cap() -> void:
	for base: Vector2i in EraManager.RESOLUTION.values():
		var c: Vector2i = ScreenFit.content_size(MONITOR, base)
		assert_eq(c.y, base.y, "height kept for %s" % base)
		assert_almost_eq(float(c.x) / c.y, ScreenFit.MAX_ASPECT, 0.01, "3:2 for %s" % base)

func test_view_is_never_smaller_than_the_era_size_nor_wider_than_three_to_two() -> void:
	_window(IPHONE)
	for s: Vector2 in SHAPES:
		_resize(s)
		await wait_process_frames(1)
		var vp: Vector2 = _win.get_visible_rect().size
		assert_gte(vp.x, float(BASE.x), "%s: view %s at least the era width" % [s, vp])
		assert_gte(vp.y, float(BASE.y), "%s: view %s at least the era height" % [s, vp])
		assert_lte(vp.x / vp.y, ScreenFit.MAX_ASPECT + 0.02, "%s: view %s no wider than 3:2" % [s, vp])

func test_apply_reports_a_change_only_once() -> void:
	_window(DUO_OUTER)
	_win.size = Vector2i(MONITOR)
	assert_true(ScreenFit.apply(_win, BASE), "turning wide changes the fit")
	assert_false(ScreenFit.apply(_win, BASE), "the same size again changes nothing")

func test_unfolding_moves_menus_into_the_new_safe_area() -> void:
	# Folded: Dynamic Island at the top. Unfolded and on its side: the cut-out is at the left.
	SafeArea.simulate(DUO_OUTER, 160.0, 100.0)
	_window(DUO_OUTER)
	var host := MenuHost.new()
	_win.add_child(host)
	await wait_process_frames(2)
	_assert_panels_inside(host, "folded")
	for step: Array in [[DUO_INNER, 140.0, 60.0, 0.0], [DUO_INNER_SIDEWAYS, 0.0, 60.0, 180.0], [DUO_OUTER, 160.0, 100.0, 0.0]]:
		var s: Vector2 = step[0]
		SafeArea.simulate(s, step[1], step[2], step[3])
		_resize(s)
		# A resize that leaves the view size alone still reaches the panels through size_changed.
		_win.size_changed.emit()
		await wait_process_frames(2)
		_assert_panels_inside(host, "after %s" % s)

func _assert_panels_inside(host: MenuHost, when: String) -> void:
	var safe: Rect2 = SafeArea.rect(_win.get_visible_rect().size).grow(0.5)
	for c: Control in [host.picker, host._info_panel] as Array[Control]:
		var r := Rect2(c.position + host.position, c.size)
		assert_true(safe.encloses(r), "%s: %s inside the safe area %s" % [when, r, safe])
		assert_gt(r.size.x, 0.0, "%s: panel keeps a width" % when)
