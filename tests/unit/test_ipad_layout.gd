extends GutTest
## Chimora 1.3.2, Apple pre-check incl. iPad: the notes, the title's version line and wordmark, the bond
## minigame's hint stay inside the safe area on iPads (both ways), a 3:4 foldable, tall 19.5:9
## phones with a notch and gesture bar, and a small 720 x 1280 Android phone. Sizes and insets
## are device pixels (tools/adaptive_shots.gd renders the same set for the screenshots).

const BASE := Vector2i(144, 256)
## [window size, top, bottom, left, right] in window pixels.
const SCREENS: Array[Array] = [
	[Vector2i(2048, 2732), 48.0, 40.0, 0.0, 0.0],
	[Vector2i(1640, 2360), 48.0, 40.0, 0.0, 0.0],
	[Vector2i(2732, 2048), 48.0, 40.0, 0.0, 0.0],
	[Vector2i(1800, 2400), 80.0, 48.0, 0.0, 0.0],
	[Vector2i(2400, 1800), 48.0, 48.0, 0.0, 0.0],
	[Vector2i(1179, 2556), 177.0, 102.0, 0.0, 0.0],
	[Vector2i(1080, 2340), 110.0, 63.0, 0.0, 0.0],
	[Vector2i(720, 1280), 48.0, 96.0, 0.0, 0.0],
	[Vector2i(2556, 1179), 0.0, 63.0, 177.0, 177.0],
]

var _win: Window

func before_each() -> void:
	GameState.reduce_motion = true

func after_each() -> void:
	SafeArea.stop_simulating()
	if is_instance_valid(_win):
		_win.queue_free()
	_win = null
	await wait_process_frames(1)

func _open(s: Array, base: Vector2i = BASE) -> Rect2:
	var size: Vector2i = s[0]
	SafeArea.simulate(Vector2(size), s[1], s[2], s[3], s[4])
	_win = Window.new()
	_win.size = size
	_win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_win.content_scale_size = base
	add_child(_win)
	ScreenFit.apply(_win, base)
	return SafeArea.rect(_win.get_visible_rect().size)

func _close() -> void:
	_win.queue_free()
	_win = null
	SafeArea.stop_simulating()
	await wait_process_frames(1)

func _assert_inside(r: Rect2, safe: Rect2, what: String) -> void:
	assert_true(safe.grow(0.5).encloses(r), "%s %s inside the safe area %s" % [what, r, safe])

func test_notes_sit_under_the_notch_and_inside_the_column() -> void:
	for s: Array in SCREENS:
		var safe: Rect2 = _open(s)
		var t := Toast.new()
		_win.add_child(t)
		var panel: Control = t.get("_panel")
		panel.visible = true
		(t.get("_label") as Label).text = "Weekend: battles give double Growth today."
		await wait_process_frames(2)
		_assert_inside(panel.get_global_rect(), safe, "%s note" % s[0])
		var col: Rect2 = SafeArea.column(_win.get_visible_rect().size)
		_assert_inside(panel.get_global_rect(), col, "%s note in the column" % s[0])
		await _close()

func test_title_version_stays_above_the_gesture_bar() -> void:
	for s: Array in SCREENS:
		var safe: Rect2 = _open(s)
		var root := Control.new()
		root.theme = UITheme.get_theme()
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_win.add_child(root)
		var v: Label = TitleScreen.version_label()
		root.add_child(v)
		TitleScreen.place_version(v, _win.get_visible_rect().size)
		await wait_process_frames(2)
		_assert_inside(v.get_global_rect(), safe, "%s version" % s[0])
		assert_almost_eq(v.get_global_rect().end.y, safe.end.y, 0.5, "%s: version on the safe bottom edge" % s[0])
		await _close()

func test_bond_hint_sits_under_the_notch_and_inside_the_column() -> void:
	for s: Array in SCREENS:
		_open(s)
		var game := BondMinigame.new()
		game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_win.add_child(game)
		game.call("_say", "Watch the marks light up, then tap them in the same order.")
		game.visible = true
		await wait_process_frames(2)
		var col: Rect2 = SafeArea.column(_win.get_visible_rect().size)
		_assert_inside((game.get("_hint") as Control).get_global_rect(), col, "%s bond hint" % s[0])
		await _close()

func test_bond_hint_follows_a_resize() -> void:
	_open(SCREENS[7])
	var game := BondMinigame.new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win.add_child(game)
	game.visible = true
	await wait_process_frames(2)
	var size: Vector2i = SCREENS[5][0]
	SafeArea.simulate(Vector2(size), SCREENS[5][1], SCREENS[5][2])
	_win.size = size
	ScreenFit.apply(_win, BASE)
	await wait_process_frames(2)
	var col: Rect2 = SafeArea.column(_win.get_visible_rect().size)
	assert_almost_eq((game.get("_hint") as Control).get_global_rect().position.y, col.position.y + BondMinigame.HINT_MARGIN.y, 0.5,
		"the hint moves under the new notch")

func test_title_wordmark_ends_above_the_status_strip() -> void:
	for s: Array in SCREENS:
		for e: int in range(2, 6):
			var base: Vector2i = EraManager.RESOLUTION[e]
			_open(s, base)
			var vp: Vector2 = _win.get_visible_rect().size
			var art_h: int = EraTitleArt.title_height(Vector2(base), vp.y, EraMenus.layout(e))
			var strip_top: int = 64 * art_h / TitleScreen.ART_HEIGHT
			assert_lt(EraTitleArt.logo_bottom(e, vp.x, art_h), float(strip_top), "%s era %d: wordmark above the online line" % [s[0], e])
			assert_gte(EraTitleArt.fitted_logo_scale(UITheme.font(), e, vp.x, art_h), TitleArt.LOGO_SCALE,
				"%s era %d: never smaller than on a 144 px phone" % [s[0], e])
			await _close()

func test_title_wordmark_shrinks_on_a_wide_low_view() -> void:
	_open(SCREENS[4])
	var vp: Vector2 = _win.get_visible_rect().size
	var art_h: int = EraTitleArt.title_height(Vector2(BASE), vp.y, EraMenus.layout(2))
	assert_lt(EraTitleArt.fitted_logo_scale(UITheme.font(), 2, vp.x, art_h), EraTitleArt.logo_scale(vp.x),
		"the open foldable held sideways: the width alone would draw the wordmark over the online line")
	await _close()
