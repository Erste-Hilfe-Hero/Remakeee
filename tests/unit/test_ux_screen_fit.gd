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
	add_child(_win)
	ScreenFit.apply(_win, BASE)
	return _win

func _resize(size: Vector2) -> void:
	_win.size = Vector2i(size)
	ScreenFit.apply(_win, BASE)

## Update 1.3.2 (Google Play adaptive quality tier 3): every shape expands, a 16:9 monitor
## included, and the view is the window at the whole pixel scale, so no shape shows a bar.
func test_every_shape_expands_and_is_filled_at_its_whole_scale_monitor_included() -> void:
	for s: Vector2 in SHAPES:
		assert_eq(ScreenFit.aspect_mode(s), Window.CONTENT_SCALE_ASPECT_EXPAND, "%s expands" % s)
		var k: int = ScreenFit.pixel_scale(s, BASE)
		var c: Vector2i = ScreenFit.content_size(s, BASE)
		assert_lte(absf(c.x * k - s.x), float(k), "%s: width filled by %s at %d" % [s, c, k])
		assert_lte(absf(c.y * k - s.y), float(k), "%s: height filled by %s at %d" % [s, c, k])
	assert_eq(ScreenFit.content_size(MONITOR, BASE), Vector2i(512, 288), "16:9 shows a wide view at scale 5")

func test_duo_inner_display_on_its_side_is_filled_without_bars() -> void:
	_window(DUO_INNER_SIDEWAYS)
	await wait_process_frames(1)
	var vp: Vector2 = _win.get_visible_rect().size
	assert_almost_eq(vp.x / vp.y, DUO_INNER_SIDEWAYS.x / DUO_INNER_SIDEWAYS.y, 0.03, "view %s has the screen's shape" % vp)

func test_no_size_falls_back_to_expand() -> void:
	assert_eq(ScreenFit.aspect_mode(Vector2.ZERO), Window.CONTENT_SCALE_ASPECT_EXPAND)
	assert_eq(ScreenFit.content_size(Vector2.ZERO, BASE), BASE)

func test_every_era_size_takes_the_monitor_shape() -> void:
	for base: Vector2i in EraManager.RESOLUTION.values():
		var c: Vector2i = ScreenFit.content_size(MONITOR, base)
		assert_gte(c.y, base.y, "at least the era height for %s" % base)
		assert_gte(c.x, base.x, "at least the era width for %s" % base)
		assert_almost_eq(float(c.x) / c.y, MONITOR.x / MONITOR.y, 0.01, "16:9 for %s" % base)

func test_view_is_never_smaller_than_the_era_size_and_always_has_the_screen_shape() -> void:
	_window(IPHONE)
	for s: Vector2 in SHAPES:
		_resize(s)
		await wait_process_frames(1)
		var vp: Vector2 = _win.get_visible_rect().size
		assert_gte(vp.x, float(BASE.x), "%s: view %s at least the era width" % [s, vp])
		assert_gte(vp.y, float(BASE.y), "%s: view %s at least the era height" % [s, vp])
		assert_almost_eq(vp.x / vp.y, s.x / s.y, 0.01, "%s: view %s has the screen's shape (no bars)" % [s, vp])
		assert_almost_eq(_win.get_final_transform().origin, Vector2.ZERO, Vector2(0.5, 0.5), "%s: no offset" % s)

func test_apply_reports_a_change_only_once() -> void:
	_window(DUO_OUTER)
	_win.size = Vector2i(MONITOR)
	assert_true(ScreenFit.apply(_win, BASE), "a new size changes the fit")
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
