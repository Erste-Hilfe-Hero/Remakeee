extends GutTest
## Update 1.3.2, Google Play adaptive quality tier 3: the game fills phones, tablets, foldables
## and Chromebook windows with no bars, keeps its UI inside the screen and the safe area, keeps
## text whole and touch targets finger sized (44 pt), and follows a live resize without losing
## what is open. Sizes are window pixels as a 1x screen would have them (the lowest pixel scale
## each shape gets, so the strictest case for touch targets): phones 360 x 640, 360 x 800,
## 412 x 915, a 7" tablet 600 x 960, iPad 768 x 1024 both ways, a 16:10 Chromebook 1280 x 800,
## a foldable's inner screen 1812 x 2176 and an unfolded book foldable on its side 2208 x 1768.

const BF = preload("res://tests/helpers/BattleFixtures.gd")
const BASE := Vector2i(144, 256)
const SIZES: Array[Vector2i] = [Vector2i(360, 640), Vector2i(360, 800), Vector2i(412, 915), Vector2i(600, 960),
	Vector2i(768, 1024), Vector2i(1024, 768), Vector2i(1280, 800), Vector2i(1812, 2176), Vector2i(2208, 1768)]
## Notch / Dynamic Island and gesture bar (portrait) or a side cut-out (landscape), in window px.
const CUTOUT_TOP: float = 48.0
const CUTOUT_BOTTOM: float = 32.0
const CUTOUT_SIDE: float = 64.0

var _win: Window

func before_each() -> void:
	GameState.tips_enabled = false
	GameState.reduce_motion = true
	GameState.one_hand = false

func after_each() -> void:
	SafeArea.stop_simulating()
	if is_instance_valid(_win):
		_win.queue_free()
	_win = null
	await wait_process_frames(1)

func _window(size: Vector2i) -> Window:
	_win = Window.new()
	_win.size = size
	_win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_win.content_scale_size = BASE
	add_child(_win)
	ScreenFit.apply(_win, BASE)
	return _win

func _resize(size: Vector2i) -> void:
	_win.size = size
	ScreenFit.apply(_win, BASE)

func _cutouts(size: Vector2i) -> void:
	if size.x > size.y:
		SafeArea.simulate(Vector2(size), 0.0, 0.0, CUTOUT_SIDE, 0.0)
	else:
		SafeArea.simulate(Vector2(size), CUTOUT_TOP, CUTOUT_BOTTOM)

func _view() -> Rect2:
	return Rect2(Vector2.ZERO, _win.get_visible_rect().size)

## Points per view pixel at this window (1x screen: a window pixel is a point).
func _pt(px: float) -> float:
	return px * ScreenFit.px_scale(_win) / ScreenFit.density()

# --- Filling the screen -------------------------------------------------------------------------

func test_every_size_is_filled_edge_to_edge_at_a_whole_pixel_scale() -> void:
	for size: Vector2i in SIZES:
		var k: int = ScreenFit.pixel_scale(Vector2(size), BASE)
		assert_gte(k, 2, "%s: scale %d" % [size, k])
		var c: Vector2i = ScreenFit.content_size(Vector2(size), BASE)
		assert_gte(c.x, BASE.x, "%s: view at least the base width" % size)
		assert_gte(c.y, BASE.y, "%s: view at least the base height" % size)
		# The view times the scale is the window to within one view pixel: no bar on any side.
		assert_lte(absf(c.x * k - size.x), float(k), "%s: width filled (%s at %d)" % [size, c, k])
		assert_lte(absf(c.y * k - size.y), float(k), "%s: height filled (%s at %d)" % [size, c, k])

func test_a_real_window_has_no_bars_and_a_near_whole_scale() -> void:
	_window(SIZES[0])
	for size: Vector2i in SIZES:
		_resize(size)
		await wait_process_frames(1)
		var t: Transform2D = _win.get_final_transform()
		var k: float = float(ScreenFit.pixel_scale(Vector2(size), BASE))
		assert_almost_eq(t.origin, Vector2.ZERO, Vector2(0.5, 0.5), "%s: no offset, so no bar" % size)
		assert_almost_eq(t.x.x, k, k * 0.006, "%s: x scale %f is the whole scale %d" % [size, t.x.x, k])
		assert_almost_eq(t.y.y, k, k * 0.006, "%s: y scale %f is the whole scale %d" % [size, t.y.y, k])
		var drawn: Vector2 = _win.get_visible_rect().size * Vector2(t.x.x, t.y.y)
		assert_almost_eq(drawn, Vector2(size), Vector2(1, 1), "%s: the view covers the window" % size)

func test_every_era_base_fills_every_size() -> void:
	for base: Vector2i in EraManager.RESOLUTION.values():
		for size: Vector2i in SIZES:
			var k: int = ScreenFit.pixel_scale(Vector2(size), base)
			var c: Vector2i = ScreenFit.content_size(Vector2(size), base)
			if k < 1:
				assert_eq(c, base, "%s below %s: the base, scaled down" % [size, base])
				continue
			assert_lte(absf(c.x * k - size.x), float(k), "%s on %s: width filled" % [base, size])
			assert_lte(absf(c.y * k - size.y), float(k), "%s on %s: height filled" % [base, size])

func test_the_pixel_scale_is_the_one_the_old_integer_stretch_picked() -> void:
	# The fill never makes anything smaller on screen than before 1.3.2.
	for size: Vector2i in SIZES:
		var s := Vector2(size)
		var old_view: Vector2 = Vector2(BASE)
		if s.x / s.y > float(BASE.x) / BASE.y:
			old_view.x = BASE.y * s.x / s.y
		else:
			old_view.y = BASE.x * s.y / s.x
		var old_k: int = int(floorf(minf(s.x / old_view.x, s.y / old_view.y) + 0.0001))
		assert_eq(ScreenFit.pixel_scale(s, BASE), old_k, "%s keeps scale %d" % [size, old_k])

func test_ui_column_is_the_safe_area_upright_and_centred_when_wide() -> void:
	for size: Vector2i in SIZES:
		var vp := Vector2(ScreenFit.content_size(Vector2(size), BASE))
		var col: Rect2 = ScreenFit.column(vp, Rect2(Vector2.ZERO, vp))
		assert_true(Rect2(Vector2.ZERO, vp).encloses(col), "%s: column inside the view" % size)
		assert_gte(col.size.x, float(BASE.x), "%s: column at least the base width" % size)
		if vp.x / vp.y <= ScreenFit.COLUMN_ASPECT:
			assert_eq(col.size.x, vp.x, "%s: upright, the column is the whole width" % size)
		else:
			assert_almost_eq(col.get_center().x, vp.x / 2.0, 1.0, "%s: wide, the column is centred" % size)

# --- Menus, shop, battle, touch buttons at every size ---------------------------------------------

func test_pause_menu_list_fits_every_size_with_finger_sized_rows() -> void:
	for size: Vector2i in SIZES:
		_cutouts(size)
		_window(size)
		var host := PauseMenu.new()
		_win.add_child(host)
		await wait_process_frames(2)
		var labels: Array[String] = ["Goals", "Map", "Team", "Satchel", "Spirlog", "Friends", "Leagues", "Records",
			"Storage", "Save", "Save and to title", "Settings", "More", "Shop", "Riftglass"]
		host.pick_strings("Menu", labels)
		await wait_process_frames(3)
		_assert_panel_inside(host.picker, size)
		_assert_controls(host.picker, size, true)
		host.queue_free()
		_win.queue_free()
		await wait_process_frames(1)
		SafeArea.stop_simulating()

func test_shop_fits_every_size() -> void:
	ShopTestState.fill()
	for size: Vector2i in SIZES:
		_cutouts(size)
		_window(size)
		var host := PauseMenu.new()
		_win.add_child(host)
		await wait_process_frames(1)
		var s := ShopScreen.new()
		s.menu = host
		host.add_child(s)
		for tab: String in ["featured", "riftglass"]:
			s.select_tab(tab)
			await wait_process_frames(3)
			assert_eq(ShopScreen.fit_problems(s), [] as Array[String], "%s %s: shop fits" % [size, tab])
			# Child 0 is the full-screen paper behind the shop; child 1 its content in the safe column.
			_assert_panel_inside(s.get_child(1) as Control, size)
			_assert_controls(s, size, false)
		s.show_detail(ShopCatalog.offer("rg_starter"))
		await wait_process_frames(3)
		assert_eq(ShopScreen.fit_problems(s), [] as Array[String], "%s detail: shop fits" % size)
		_assert_controls(s, size, false)
		_win.queue_free()
		await wait_process_frames(1)
		SafeArea.stop_simulating()
	ShopTestState.clear()

func test_battle_fits_every_size_and_its_scenery_reaches_both_edges() -> void:
	GameState.battle_speed = 2
	for size: Vector2i in SIZES:
		_cutouts(size)
		_window(size)
		var mine: Array[Spirling] = [BF.make("Kindlop", 8), BF.make("Puddlet", 8)]
		var theirs: Array[Spirling] = [BF.make("Zippit", 6)]
		var m := BattleModel.new(mine, theirs, true, 5, 0)
		var scene: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
		scene.setup(m)
		_win.add_child(scene)
		for i: int in 600:
			if scene._waiting_orders:
				break
			scene._text.advance_now()
			await wait_process_frames(1)
		assert_true(scene._waiting_orders, "%s: the battle asks for orders" % size)
		await wait_process_frames(2)
		var view: Rect2 = _view()
		var col: Rect2 = scene._field.get_parent().get_global_rect()
		assert_true(SafeArea.column(view.size).grow(0.5).encloses(col), "%s: battle column %s in the safe column" % [size, col])
		if col.size.x < view.size.x - 1.0:
			var wide: Rect2 = scene._wide_backdrop.get_global_rect()
			assert_true(scene._wide_backdrop.visible, "%s: scenery beside the column" % size)
			assert_almost_eq(wide.position.x, 0.0, 0.5, "%s: scenery from the left edge" % size)
			assert_almost_eq(wide.end.x, view.size.x, 0.5, "%s: scenery to the right edge" % size)
			assert_almost_eq(wide.position.y, scene._field.get_global_rect().position.y, 0.5, "%s: same horizon" % size)
		# Battle rows reach 44 pt out of the height above the era's base screen; the field never
		# gets shorter than on the base screen. Where that height is too little (a 16:9 or
		# landscape view), every spare pixel goes to the rows.
		var touch: int = ScreenFit.touch_px(_win)
		var art: int = BattleComfort.art_h(1)
		var cmd: int = BattleComfort.command_h(1)
		var spare: float = view.size.y - EraManager.RESOLUTION[1].y
		var need: int = Spirling.MAX_MOVES * maxi(0, touch - art) + CommandMenu.TOUCH_COMMAND_ROWS * maxi(0, touch - cmd)
		_assert_controls(scene._menu, size, spare >= need)
		if spare < need:
			var rows: Vector2i = CommandMenu.touch_rows(art, cmd, touch, spare)
			var used: int = Spirling.MAX_MOVES * (rows.x - art) + CommandMenu.TOUCH_COMMAND_ROWS * (rows.y - cmd)
			assert_lte(used, int(spare), "%s: the rows take no height from the field" % size)
			assert_gte(used, int(spare) - Spirling.MAX_MOVES - CommandMenu.TOUCH_COMMAND_ROWS, "%s: the spare height goes to the rows" % size)
			gut.p("%s: battle rows %.0f / %.0f pt (%d px of height to spare, %d needed)" % [size, _pt(rows.x), _pt(rows.y), int(spare), need])
		scene.queue_free()
		_win.queue_free()
		await wait_process_frames(1)
		SafeArea.stop_simulating()

func test_touch_buttons_fit_the_safe_area_without_overlap_at_every_size() -> void:
	for size: Vector2i in SIZES:
		_cutouts(size)
		_window(size)
		var pad: CanvasLayer = load("res://scripts/ui/VirtualPad.gd").new()
		_win.add_child(pad)
		await wait_process_frames(2)
		var safe: Rect2 = SafeArea.rect(_view().size).grow(0.5)
		var rects: Array[Rect2] = []
		for b: TouchScreenButton in pad.get("_buttons"):
			var side: float = (b.shape as RectangleShape2D).size.x
			var r := Rect2(b.position, Vector2(side, side))
			assert_true(safe.encloses(r), "%s: %s %s inside the safe area %s" % [size, b.action, r, safe])
			assert_gte(_pt(side), ScreenFit.TOUCH_PT - 0.5, "%s: %s is %.1f pt" % [size, b.action, _pt(side)])
			if b.action in [&"ui_accept", &"ui_cancel", &"menu"]:
				for o: Rect2 in rects:
					assert_false(o.intersects(r.grow(-0.5)), "%s: %s does not overlap another button" % [size, b.action])
				rects.append(r)
		pad.free()
		_win.queue_free()
		await wait_process_frames(1)
		SafeArea.stop_simulating()

# --- Live resize: fold, unfold, turn, drag a window --------------------------------------------------

func test_live_resize_keeps_the_open_list_and_fits_each_step() -> void:
	_window(SIZES[2])
	var host := PauseMenu.new()
	_win.add_child(host)
	await wait_process_frames(2)
	host.pick_strings("Menu", ["Team", "Satchel", "Spirlog", "Settings"] as Array[String])
	await wait_process_frames(2)
	var before: Array[String] = host.last_rows.duplicate()
	for size: Vector2i in [SIZES[7], SIZES[8], SIZES[6], SIZES[0], SIZES[4], SIZES[5], SIZES[2]]:
		_cutouts(size)
		_resize(size)
		await wait_process_frames(3)
		assert_true(host.picker.is_visible_in_tree(), "%s: the list is still open" % size)
		assert_eq(host.last_rows, before, "%s: the same rows" % size)
		_assert_panel_inside(host.picker, size)
		_assert_controls(host.picker, size, true)

func test_map_surround_covers_any_view_and_keeps_edges() -> void:
	var m := MapData.load_map("brindlewick")
	for size: Vector2i in SIZES:
		var vp := Vector2(ScreenFit.content_size(Vector2(size), BASE))
		var ring: int = MapSurround.ring_for(vp)
		assert_gte(ring * TilesetFactory.TILE * 2, int(maxf(vp.x, vp.y)), "%s: ring of %d cells reaches the screen edge" % [size, ring])
	for x: int in m.width:
		var top: int = MapSurround.kind_outside(m, Vector2i(x, -3))
		assert_true(top in MapSurround.CARRY, "outside cell above column %d is plain land, water or woods" % x)
		assert_ne(top, TilesetFactory.Kind.TALL_GRASS, "no encounter grass outside")

func test_phones_stay_upright_and_large_screens_turn() -> void:
	# Device pixels and density (px per dp / pt).
	for phone: Array in [[Vector2(1080, 2400), 3.0], [Vector2(1080, 2400), 2.625], [Vector2(1170, 2532), 3.0], [Vector2(720, 1280), 2.0],
			[Vector2(1080, 1080), 2.625]]:
		assert_eq(ScreenFit.orientation_for(phone[0], phone[1]), DisplayServer.SCREEN_SENSOR_PORTRAIT, "%s @%s is a phone" % phone)
	for large: Array in [[Vector2(1812, 2176), 2.625], [Vector2(2208, 1768), 2.625], [Vector2(1536, 2048), 2.0],
			[Vector2(2560, 1600), 2.0], [Vector2(1366, 768), 1.0], [Vector2(1200, 1920), 2.0]]:
		assert_eq(ScreenFit.orientation_for(large[0], large[1]), DisplayServer.SCREEN_SENSOR, "%s @%s turns freely" % large)

func test_touch_floor_follows_the_pixel_scale() -> void:
	_window(Vector2i(360, 640))
	await wait_process_frames(1)
	assert_eq(ScreenFit.touch_px(_win), 22, "scale 2: 22 px are 44 pt")
	_resize(Vector2i(1280, 800))
	await wait_process_frames(1)
	assert_eq(ScreenFit.touch_px(_win), 15, "scale 3: 15 px")
	_resize(Vector2i(100, 120))
	await wait_process_frames(1)
	assert_eq(ScreenFit.touch_px(_win), 0, "a view drawn below its size gets no floor")

# --- Checks ----------------------------------------------------------------------------------------

func _assert_panel_inside(c: Control, size: Vector2i) -> void:
	var view: Rect2 = _view()
	var safe: Rect2 = SafeArea.column(view.size).grow(0.5)
	var r: Rect2 = c.get_global_rect()
	assert_true(safe.encloses(r), "%s: %s %s inside the safe column %s (view %s)" % [size, c.get_class(), r, safe, view.size])
	assert_gte(r.size.x, float(BASE.x) - 2.0 * MenuHost.PANEL_MARGIN - 1.0, "%s: panel keeps its width" % size)

## Every visible button: on screen, its text whole, and (when [param touch]) finger sized.
func _assert_controls(root: Control, size: Vector2i, touch: bool) -> void:
	var view: Rect2 = _view().grow(0.5)
	var buttons: int = 0
	for n: Node in root.find_children("*", "Control", true, false):
		var c: Control = n as Control
		if not c.is_visible_in_tree() or c.size.x <= 0.0 or c.size.y <= 0.0 or _scrolled(c, root):
			continue
		var r: Rect2 = c.get_global_rect()
		assert_true(view.encloses(r), "%s: %s '%s' %s on screen %s" % [size, c.get_class(), _text(c), r, view])
		if c is Label:
			assert_true(_label_whole(c as Label), "%s: label '%s' whole" % [size, (c as Label).text])
		var b: Button = c as Button
		if b == null or b.disabled or b.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		buttons += 1
		assert_true(_button_whole(b), "%s: button '%s' text whole" % [size, b.text])
		if touch:
			assert_gte(_pt(minf(r.size.y, r.size.x)), ScreenFit.TOUCH_PT - 0.5,
				"%s: button '%s' is %.1f pt" % [size, b.text, _pt(minf(r.size.y, r.size.x))])
	assert_gt(buttons, 0, "%s: buttons found" % size)

## True for a control inside a scroll box below [param root] (it may scroll out of view).
func _scrolled(c: Control, root: Control) -> bool:
	var p: Node = c.get_parent()
	while p != null and p != root:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func _text(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	return c.name

func _label_whole(l: Label) -> bool:
	if l.text.is_empty() or l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return true
	if l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and not l.clip_text:
		return true
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	var sb: StyleBox = l.get_theme_stylebox("normal")
	var room: float = l.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
	for line: String in l.text.split("\n"):
		if f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 0.5:
			return false
	return true

func _button_whole(b: Button) -> bool:
	if b.text.is_empty() or b.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return true
	if b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		return true
	var f: Font = b.get_theme_font("font")
	var fs: int = b.get_theme_font_size("font_size")
	var sb: StyleBox = b.get_theme_stylebox("normal")
	var room: float = b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT) - (b.icon.get_width() + 2 if b.icon != null else 0)
	return f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room + 0.5

## The shop state the shop screen shows (adult account, open, prices from the store).
class ShopTestState:
	static var _state: Dictionary = {}

	static func fill() -> void:
		_state = Billing.state.duplicate(true)
		Billing.state = {"balance": 1250, "band": 18, "open": true, "bought": {}, "unlocks": {}, "rifts": 1,
			"cap_cents": 10000, "spent_cents": 0, "withdrawal_ok": true}
		for o: Dictionary in ShopCatalog.offers():
			Billing.prices[str(o.get("product_id", ""))] = ShopCatalog.format_eur(int(o.get("eur_cents", 0)))

	static func clear() -> void:
		Billing.state = _state
		Billing.prices.clear()
