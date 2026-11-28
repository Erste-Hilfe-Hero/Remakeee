extends GutTest
## Apple pre-check (owner rule, 1.3.2): on a real phone every player text is at least 13 pt and
## every touch target at least 44 pt. The phones are the smallest the game supports, at their
## real pixels and density, with the view ScreenFit gives them: the iPhone SE (375 x 667 pt at
## 2x), a 3x iPhone (375 x 812 pt), a small 2x Android (360 x 640 dp) and a small 1.5x Android.
## A text's size is its line height (the font the control draws with); a button's its shorter side.
## Every era, every screen: title, pause, settings, Spirlog, map, friends, shop, a talk box, an
## info page, a toast, the battle's command rows, the Mine! button and the touch buttons.

const BF = preload("res://tests/helpers/BattleFixtures.gd")
## Name, screen pixels, pixels per point.
const PHONES: Array = [
	["iPhone SE", Vector2i(750, 1334), 2.0],
	["iPhone 3x", Vector2i(1125, 2436), 3.0],
	["Android 360dp 2x", Vector2i(720, 1280), 2.0],
	["Android 360dp 1.5x", Vector2i(540, 960), 1.5],
]
const MAX_FRAMES: int = 200

var _win: Window
var _keep: Array = []

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter, Online.state, GameState.language]
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.reduce_motion = true
	GameState.tips_enabled = false
	GameState.one_hand = false
	GameState.add_item("tonic", 2)
	GameState.mark_seen("Kindlop", true)
	Loc.set_language("en")

func after_each() -> void:
	ScreenFit.density_override = 0.0
	if is_instance_valid(_win):
		_win.queue_free()
	_win = null
	UITheme.set_large_text(false)
	EraManager.unlocked_era = _keep[0]
	EraManager.set_retro_filter(_keep[1])
	Online.state = _keep[2]
	Loc.set_language("en")
	await wait_process_frames(1)

func _era(e: int) -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.set_retro_filter(e)

## A window of [param phone]'s pixels at its density, fitted for the active era.
func _phone(phone: Array) -> Window:
	ScreenFit.density_override = float(phone[2])
	if not is_instance_valid(_win):
		_win = Window.new()
		_win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		_win.content_scale_size = EraManager.RESOLUTION[EraManager.active_era()]
		add_child(_win)
	_win.size = phone[1]
	ScreenFit.apply(_win, EraManager.RESOLUTION[EraManager.active_era()])
	return _win

## Points per view pixel of the phone window.
func _pt() -> float:
	return ScreenFit.px_scale(_win) / ScreenFit.density()

## Everything too small under [param root]: texts below 13 pt, buttons below 44 pt.
func _too_small(root: Node) -> Array[String]:
	var out: Array[String] = []
	var pt: float = _pt()
	for n: Node in root.find_children("*", "Control", true, false):
		var c: Control = n as Control
		if not c.is_visible_in_tree() or c.size.x <= 0.0 or c.size.y <= 0.0:
			continue
		var k: float = ShopZoom.screen_scale(c) * pt
		var text: String = _text(c)
		if not text.strip_edges().is_empty():
			var rich: bool = c is RichTextLabel
			var f: Font = c.get_theme_font("normal_font" if rich else "font")
			var h: float = f.get_height(c.get_theme_font_size("normal_font_size" if rich else "font_size")) * k
			if h < ScreenFit.TEXT_PT - 0.01:
				out.append("text %.1f pt: %s '%s'" % [h, c.get_class(), text.left(30)])
		var b: BaseButton = c as BaseButton
		if b != null and not b.disabled and b.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			var side: float = minf(c.size.x, c.size.y) * k
			if side < ScreenFit.TOUCH_PT - 0.01:
				out.append("button %.1f pt: %s '%s'" % [side, c.name, text.left(30)])
	return out

func _assert_fits(root: Node, where: String) -> void:
	var small: Array[String] = _too_small(root)
	assert_eq(small.size(), 0, "%s: %s" % [where, ", ".join(small)])

func _text(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is LineEdit:
		return (c as LineEdit).text
	return ""

func _where(phone: Array, e: int, what: String) -> String:
	return "%s era %d %s" % [phone[0], e, what]

## Runs [param start] on [param menu], audits the first list or info page it shows, then backs
## out of everything. Returns what was too small and whether anything showed.
func _open(menu: PauseMenu, start: Callable) -> Dictionary:
	var state: Dictionary = {"done": false, "seen": false, "small": [] as Array[String]}
	var runner := func() -> void:
		await start.call()
		state.done = true
	var picks: int = menu.picks
	runner.call()
	var frames: int = 0
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		var shown: bool = menu._info_wait or (menu.picks > picks and menu.picker.visible)
		if shown and not state.seen:
			await wait_process_frames(3)
			state.seen = true
			state.small = _too_small(_win)
		for name: String in ["era_summary", "era_card"]:
			var n: Node = menu.get_node_or_null(name)
			if n != null:
				n.emit_signal("closed")
		if menu._info_wait:
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > picks and menu.picker.visible:
			menu.close_all = true
			menu.picker.picked.emit(-1)
	menu.close_all = false
	return state

# --- The scale itself -------------------------------------------------------------------------------

func test_every_phone_and_era_draws_text_at_13_pt_and_rows_at_44_pt() -> void:
	for phone: Array in PHONES:
		for e: int in range(1, 6):
			_era(e)
			for large: bool in [false, true]:
				UITheme.set_large_text(large)
				var line: float = UITheme.font().get_height(UITheme.FONT_SIZE)
				var s: float = ScreenFit.view_scale(Vector2(phone[1]), EraManager.RESOLUTION[e], line, phone[2])
				var view: Vector2i = ScreenFit.content_size(Vector2(phone[1]), EraManager.RESOLUTION[e], line, phone[2])
				var where: String = _where(phone, e, "large" if large else "")
				assert_gte(line * s / float(phone[2]), ScreenFit.TEXT_PT, "%s: text %.1f pt" % [where, line * s / float(phone[2])])
				assert_gte(view.x, EraManager.RESOLUTION[e].x, "%s: the era's whole width shows (%s)" % [where, view])
				assert_gte(view.y, EraManager.RESOLUTION[e].y, "%s: the era's whole height shows (%s)" % [where, view])
				assert_lte(view.x * s, float(phone[1].x) + s, "%s: drawn inside the screen" % where)

func test_whole_scale_stays_where_text_is_large_enough() -> void:
	# Eras I to III on every phone, and the 3x iPhone in every era: the whole-number scale.
	for phone: Array in PHONES:
		for e: int in [1, 2, 3]:
			_era(e)
			var line: float = UITheme.font().get_height(UITheme.FONT_SIZE)
			assert_eq(ScreenFit.view_scale(Vector2(phone[1]), EraManager.RESOLUTION[e], line, phone[2]),
				float(ScreenFit.pixel_scale(Vector2(phone[1]), EraManager.RESOLUTION[e])), _where(phone, e, "whole scale"))
	# Eras IV and V on the iPhone SE: 12 px lines at scale 2 were 12 pt; a half step, 2.5, is 15 pt.
	_era(4)
	var l4: float = UITheme.font().get_height(UITheme.FONT_SIZE)
	assert_eq(ScreenFit.view_scale(Vector2(750, 1334), EraManager.RESOLUTION[4], l4, 2.0), 2.5)
	assert_eq(ScreenFit.content_size(Vector2(750, 1334), EraManager.RESOLUTION[4], l4, 2.0), Vector2i(300, 534))
	assert_eq(ScreenFit.content_size(Vector2(750, 1334), EraManager.RESOLUTION[4]), Vector2i(375, 667), "no line given: as before")

func test_a_phone_window_follows_the_era() -> void:
	for phone: Array in PHONES:
		for e: int in range(1, 6):
			_era(e)
			_phone(phone)
			await wait_process_frames(1)
			var line: float = UITheme.font().get_height(UITheme.FONT_SIZE)
			assert_gte(line * _pt(), ScreenFit.TEXT_PT - 0.05, "%s: %.1f pt" % [_where(phone, e, "window"), line * _pt()])
			var touch: int = ScreenFit.touch_px(_win)
			assert_gte(touch * _pt(), ScreenFit.TOUCH_PT - 0.05, _where(phone, e, "touch floor"))

# --- Every screen -----------------------------------------------------------------------------------

func test_menus_on_every_phone_and_era() -> void:
	Online.state = Online.State.OFFLINE
	for phone: Array in PHONES:
		for e: int in range(1, 6):
			_era(e)
			_phone(phone)
			var menu := PauseMenu.new()
			menu.current_map = "fernstair"
			_win.add_child(menu)
			await wait_process_frames(2)
			var screens: Dictionary = {
				"pause": menu.run,
				"settings": menu.run_settings,
				"spirlog": menu.run_spirlog,
				"map": func() -> void: await WorldMapMenu.run(menu, "fernstair"),
				"friends": func() -> void: await FriendsMenu.run(menu),
				"info": func() -> void: await menu.info("Saved. You can close the game now."),
			}
			for s: String in screens:
				var st: Dictionary = await _open(menu, screens[s])
				assert_true(st.seen, _where(phone, e, s + " shows"))
				assert_eq((st.small as Array).size(), 0, "%s: %s" % [_where(phone, e, s), ", ".join(st.small)])
			menu.queue_free()
			await wait_process_frames(1)

func test_spirlog_page_on_every_phone_and_era() -> void:
	var kind: SpirlingData = Database.species("Kindlop")
	for phone: Array in PHONES:
		for e: int in range(1, 6):
			_era(e)
			_phone(phone)
			var host := Control.new()
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			host.theme = UITheme.get_theme()
			_win.add_child(host)
			SpirlogPage.show_pages(host, [kind] as Array[SpirlingData], 0)
			await wait_process_frames(3)
			_assert_fits(_win, _where(phone, e, "Spirlog page"))
			var page: SpirlogPage = host.get_child(0) as SpirlogPage
			page._closed.emit()
			host.queue_free()
			await wait_process_frames(1)

func test_shop_on_every_phone_and_era() -> void:
	var keep: Dictionary = Billing.state.duplicate(true)
	Billing.state = {"balance": 1250, "band": 18, "open": true, "bought": {}, "unlocks": {}, "rifts": 1,
		"cap_cents": 10000, "spent_cents": 0, "withdrawal_ok": true}
	for o: Dictionary in ShopCatalog.offers():
		Billing.prices[str(o.get("product_id", ""))] = ShopCatalog.format_eur(int(o.get("eur_cents", 0)))
	for phone: Array in PHONES:
		for e: int in range(1, 6):
			_era(e)
			_phone(phone)
			var host := PauseMenu.new()
			_win.add_child(host)
			await wait_process_frames(1)
			ShopScreen.open(host)
			await wait_process_frames(3)
			var screen: ShopScreen = host.find_children("*", "ShopScreen", true, false).front() if not host.find_children("*", "ShopScreen", true, false).is_empty() else null
			assert_not_null(screen, _where(phone, e, "shop"))
			if screen != null:
				for t: String in ShopScreen.TABS:
					screen.select_tab(t)
					await wait_process_frames(2)
					_assert_fits(_win, _where(phone, e, "shop " + t))
				screen.closed.emit()
			host.queue_free()
			await wait_process_frames(2)
	Billing.state = keep
	Billing.prices.clear()

func test_talk_box_and_toast_on_every_phone_and_era() -> void:
	for phone: Array in PHONES:
		for e: int in range(1, 6):
			_era(e)
			_phone(phone)
			var host := Control.new()
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			host.theme = UITheme.get_theme()
			_win.add_child(host)
			var tb := TextBox.new()
			host.add_child(tb)
			var toast := Toast.new()
			_win.add_child(toast)
			await wait_process_frames(1)
			tb.show_text("Mira: The lake is calm today. Shall we go on?")
			toast.show_note("Badge: First steps", null, "")
			await wait_process_frames(3)
			_assert_fits(_win, _where(phone, e, "talk box and toast"))
			host.queue_free()
			toast.queue_free()
			await wait_process_frames(1)

## A battle on the phone window, waiting for orders: one on one, or two on two ([param pair]),
## with the Auto tab shown.
func _battle(phone: Array, e: int, pair: bool) -> BattleScene:
	var m := BattleModel.new([BF.make("Kindlop", 8), BF.make("Puddlet", 8)] as Array[Spirling],
		[BF.make("Zippit", 6), BF.make("Mossling", 6)] as Array[Spirling], not pair, 5, 0)
	if pair:
		m.front_size = [2, 2]
	var scene: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	scene.setup(m)
	scene.auto_kind = BattleComfort.auto_kind(false, {"story": true})
	_win.add_child(scene)
	for i: int in 600:
		if scene._waiting_orders:
			break
		scene._text.advance_now()
		await wait_process_frames(1)
	assert_true(scene._waiting_orders, _where(phone, e, "battle asks for orders"))
	await wait_process_frames(2)
	return scene

func test_formation_battle_on_every_phone_and_era() -> void:
	GameState.battle_speed = 2
	for phone: Array in PHONES:
		for e: int in range(1, 6):
			_era(e)
			_phone(phone)
			var scene: BattleScene = await _battle(phone, e, true)
			assert_true(scene._auto_button.visible, _where(phone, e, "Auto shows"))
			_assert_fits(scene, _where(phone, e, "two on two"))
			# The finger-sized buttons stand above the foes' rank.
			for b: Button in [scene._ff_button, scene._auto_button, scene._log_button]:
				for sp: SpirlingSprite in scene._slot_sprites[BattleModel.Side.FOE]:
					assert_false(b.get_rect().intersects(sp.get_rect()), "%s: %s %s over a foe %s field %s" % [_where(phone, e, "two on two"), b.text, b.get_rect(), sp.get_rect(), scene._field.size])
			# Aiming: a tap on a foe, and Back.
			scene._pick_target("Aim at")
			await wait_process_frames(2)
			assert_eq(scene._target_buttons.size(), 2, _where(phone, e, "two foes to aim at"))
			assert_true(scene._back_button.visible, _where(phone, e, "Back shows"))
			_assert_fits(scene, _where(phone, e, "aiming"))
			scene._target_picked.emit(-1)
			await wait_process_frames(1)
			scene.queue_free()
			await wait_process_frames(1)

func test_battle_commands_mine_and_touch_buttons_on_every_phone_and_era() -> void:
	GameState.battle_speed = 2
	for phone: Array in PHONES:
		for e: int in range(1, 6):
			_era(e)
			_phone(phone)
			var scene: BattleScene = await _battle(phone, e, false)
			assert_true(scene._auto_button.visible, _where(phone, e, "Auto shows"))
			_assert_fits(scene, _where(phone, e, "battle"))
			# Mine!: the button and its word (the whole minigame takes the tap).
			var g: BondMinigame = scene._bond_game
			assert_gte(BondMinigame.MINE_SIZE * _pt(), ScreenFit.TOUCH_PT, _where(phone, e, "Mine! button"))
			var mine_line: float = g.get_theme_default_font().get_height(UITheme.FONT_SIZE) * _pt()
			assert_gte(mine_line, ScreenFit.TEXT_PT, "%s: %.1f pt" % [_where(phone, e, "Mine! word"), mine_line])
			scene.queue_free()
			var pad: CanvasLayer = load("res://scripts/ui/VirtualPad.gd").new()
			_win.add_child(pad)
			await wait_process_frames(2)
			for b: TouchScreenButton in pad.get("_buttons"):
				var side: float = (b.shape as RectangleShape2D).size.x * _pt()
				assert_gte(side, ScreenFit.TOUCH_PT - 0.5, "%s: %.1f pt" % [_where(phone, e, str(b.action)), side])
			pad.free()
			await wait_process_frames(1)

func test_title_on_every_phone() -> void:
	Online.state = Online.State.OFFLINE
	EraBoot.shown = true
	for phone: Array in PHONES:
		_era(1)
		_phone(phone)
		var title: TitleScreen = load("res://scenes/ui/Title.tscn").instantiate()
		_win.add_child(title)
		var host: MenuHost = title._menu
		for i: int in MAX_FRAMES:
			await wait_process_frames(1)
			if host.picker.visible or host._info_wait:
				break
		await wait_process_frames(3)
		assert_true(host.picker.visible or host._info_wait, "%s: the title shows its list" % phone[0])
		_assert_fits(_win, "%s: title" % phone[0])
		title.queue_free()
		await wait_process_frames(2)
