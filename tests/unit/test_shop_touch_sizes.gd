extends GutTest
## Apple review (27.11.2026): on the smallest supported phone (iPhone SE, ShopZoom) every button of
## the shop, the pass track and the Riftglass questions is at least 44 pt tall and every text at
## least 13 pt, in all five eras.

var _keep: Dictionary = {}
var _old_backend: OnlineBackend
var _old_state: Online.State
var _billing: Dictionary
var _lang: String
var s: LocalBackend

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state

func before_each() -> void:
	_keep = {"unlocked": EraManager.unlocked_era, "retro": EraManager.retro_filter}
	_billing = Billing.state
	_lang = Loc.language()
	Loc.set_language("en")
	s = LocalBackend.new()
	s.rng.seed = 1
	Online.backend = s
	Online.state = Online.State.ONLINE
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	s.call_fn("shop_set_age", {"p_year": 1990, "p_month": 3})
	LocalShop.of(s)._ledger_add(s.me(), 1250, "support", "test")
	await Billing.refresh_state()

func after_each() -> void:
	EraManager.unlocked_era = _keep.unlocked
	EraManager.set_retro_filter(_keep.retro)
	Billing.state = _billing
	Loc.set_language(_lang)

func _era(e: int) -> void:
	EraManager.unlocked_era = e
	EraManager.set_retro_filter(0)

## A menu host on the iPhone SE's view of era [param e].
func _host(e: int) -> MenuHost:
	var vp := SubViewport.new()
	vp.size = ShopZoom.phone_view(e)
	add_child_autofree(vp)
	var host := MenuHost.new()
	vp.add_child(host)
	return host

## Everything too small under [param root]: buttons below 44 pt, texts below 13 pt.
func _too_small(root: Node, e: int) -> Array[String]:
	var out: Array[String] = []
	_walk(root, ShopZoom.pt_per_px(e), out)
	return out

func _walk(n: Node, pt: float, out: Array[String]) -> void:
	for c: Node in n.get_children():
		if c is SubViewport:
			_walk(c, pt, out)
			continue
		var ctl: Control = c as Control
		if ctl == null or not ctl.is_visible_in_tree():
			continue
		var k: float = ShopZoom.screen_scale(ctl) * pt
		if ctl is Button and ctl.size.y * k < ShopZoom.MIN_TOUCH_PT - 0.01:
			out.append("button %.0f pt: %s %s" % [ctl.size.y * k, ctl.name, (ctl as Button).text.left(30)])
		var text: String = (ctl as Label).text if ctl is Label else ((ctl as Button).text if ctl is Button else "")
		if not text.strip_edges().is_empty():
			var f: Font = ctl.get_theme_font("font")
			var h: float = f.get_height(ctl.get_theme_font_size("font_size")) * k
			if h < ShopZoom.MIN_TEXT_PT - 0.01:
				out.append("text %.1f pt: %s" % [h, text.left(30)])
		_walk(ctl, pt, out)

func _find(root: Node, cls: Variant) -> Node:
	for c: Node in root.get_children():
		if is_instance_of(c, cls):
			return c
		var d: Node = _find(c, cls)
		if d != null:
			return d
	return null

## The host whose list shows now: a zoomed one over [param host], else [param host].
func _live_host(host: MenuHost) -> MenuHost:
	var v: Node = host.get_node_or_null("shop_zoom")
	return v.get_child(0).get_child(0) as MenuHost if v != null else host

## Waits until the list of [param host] (or of its zoomed host) shows; a long question shows as a
## page first (MenuHost.pick), which is turned.
func _wait_list(host: MenuHost) -> MenuHost:
	var live: MenuHost = host
	for i: int in 90:
		await wait_process_frames(1)
		live = _live_host(host)
		if live._info_wait:
			live._close_info()
		elif live.picks > 0 and live.picker.is_visible_in_tree():
			break
	return live

func test_phone_views() -> void:
	assert_eq(ShopZoom.phone_view(1), Vector2i(144, 256))
	assert_eq(ShopZoom.phone_view(3), Vector2i(180, 320))
	assert_eq(ShopZoom.phone_view(4), Vector2i(270, 480))
	assert_eq(ShopZoom.device_pt_per_px(), 0.0, "no phone here: the iPhone SE model counts")

func test_factor_and_touch_per_era() -> void:
	var want: Dictionary = {1: [1, 18], 2: [1, 18], 3: [1, 22], 4: [2, 22], 5: [2, 22]}
	for e: int in want:
		_era(e)
		assert_eq([ShopZoom.factor(), ShopZoom.touch_px()], want[e], "era %d" % e)
		var k: int = ShopZoom.factor()
		assert_gte(k * ShopZoom.line_px() * ShopZoom.pt_per_px(e), ShopZoom.MIN_TEXT_PT, "text, era %d" % e)
		assert_gte(k * ShopZoom.touch_px() * ShopZoom.pt_per_px(e), ShopZoom.MIN_TOUCH_PT, "touch, era %d" % e)

## Every tab and a detail page of the shop screen, in every era. Eras I to III keep their layout
## (no zoomed view); IV and V draw the shop twice as large.
func test_shop_screen_sizes_every_era() -> void:
	for e: int in range(1, 6):
		_era(e)
		var host: MenuHost = _host(e)
		await wait_process_frames(1)
		ShopScreen.open(host)
		await wait_process_frames(3)
		var screen: ShopScreen = _find(host, ShopScreen)
		assert_not_null(screen, "era %d" % e)
		if screen == null:
			continue
		assert_eq(host.get_node_or_null("shop_zoom") != null, e >= 4, "zoomed only in Eras IV and V (era %d)" % e)
		for t: String in ShopScreen.TABS:
			screen.select_tab(t)
			await wait_process_frames(2)
			assert_eq(_too_small(host.get_viewport(), e), [] as Array[String], "era %d, tab %s" % [e, t])
		screen.show_detail(ShopCatalog.offer("rg_glass_1000"))
		await wait_process_frames(2)
		assert_eq(_too_small(host.get_viewport(), e), [] as Array[String], "era %d, detail" % e)
		assert_eq(ShopScreen.fit_problems(screen), [] as Array[String], "era %d fits" % e)
		screen.closed.emit()
		await wait_process_frames(2)
		assert_null(host.get_node_or_null("shop_zoom"), "the zoomed view closes with the shop")

## The Riftglass question (heal anywhere) and the pass track's list, in every era.
func test_sink_and_pass_sizes_every_era() -> void:
	for e: int in range(1, 6):
		_era(e)
		var host: MenuHost = _host(e)
		await wait_process_frames(1)
		RiftglassSinks.pay_in_menu(host, "heal", "", 100, "Heal the whole team now? Full Vigor, Energy, no states.")
		var live: MenuHost = await _wait_list(host)
		assert_true(live.picker.is_visible_in_tree(), "era %d: the question shows" % e)
		assert_eq(_too_small(host.get_viewport(), e), [] as Array[String], "era %d, Riftglass question" % e)
		live.picker.picked.emit(-1)
		await wait_process_frames(2)
		assert_null(host.get_node_or_null("shop_zoom"), "era %d: closed" % e)
		assert_eq(host.min_row, 0, "era %d: the host's own rows come back" % e)
		PassScreen.run(host)
		live = await _wait_list(host)
		assert_true(live.picker.is_visible_in_tree(), "era %d: the pass track shows" % e)
		assert_eq(_too_small(host.get_viewport(), e), [] as Array[String], "era %d, pass track" % e)
		live.close_all = true
		await wait_process_frames(4)

## The battle's Riftglass questions (continue, bond boost) are a finger's size too.
func test_battle_question_sizes_every_era() -> void:
	for e: int in range(1, 6):
		_era(e)
		var vp := SubViewport.new()
		vp.size = ShopZoom.phone_view(e)
		add_child_autofree(vp)
		var scene := Control.new()
		scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scene.theme = UITheme.get_theme()
		vp.add_child(scene)
		var picker := ListPicker.new()
		picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scene.add_child(picker)
		await wait_process_frames(1)
		var answer: Array[int] = [-2]
		var run := func() -> void: answer[0] = await ShopZoom.ask(scene, picker, BattleScene.continue_title(200),
			[{"text": "Continue"}, {"text": BattleScene.bond_boost_row(100)}] as Array[Dictionary], false)
		run.call()
		await wait_process_frames(3)
		var zoom: Node = scene.get_node_or_null("shop_zoom")
		var live: ListPicker = picker
		if zoom != null:
			live = (await _wait_list(zoom.get_child(0).get_child(0) as MenuHost)).picker
		assert_true(live.is_visible_in_tree(), "era %d: the list shows" % e)
		assert_eq(_too_small(vp, e), [] as Array[String], "era %d" % e)
		live.picked.emit(1)
		await wait_process_frames(2)
		assert_eq(answer[0], 1, "era %d" % e)
		assert_true(picker.layout.is_empty(), "the battle list keeps its own layout")

## The bond boost answer shows its euro value (docs/MONETIZATION.md rule 3).
func test_bond_boost_row_has_euro_value() -> void:
	var t: String = BattleScene.bond_boost_row(100)
	assert_true(t.contains(ShopCatalog.euro_hint(100)), t)

## The pass track's premium row opens the shop screen on the pass's detail page; Back returns.
func test_pass_premium_row_opens_shop_detail() -> void:
	_era(1)
	var host: MenuHost = _host(1)
	await wait_process_frames(1)
	PassScreen._open_pass_offer(host)
	await wait_process_frames(3)
	var screen: ShopScreen = _find(host, ShopScreen)
	assert_not_null(screen)
	if screen == null:
		return
	assert_eq(str(screen.detail.get("id", "")), PassTrack.PASS_OFFER)
	screen.go_back()
	await wait_process_frames(2)
	assert_null(_find(host, ShopScreen), "Back closes it, back to the track")

## "du hast 0." never stands alone: the number keeps the word before it.
func test_not_enough_keeps_its_last_word() -> void:
	Loc.set_language("de")
	Billing.state = {"balance": 0}
	var t: String = RiftglassSinks.error_text("not_enough", 200)
	assert_true(t.contains(Loc.NO_BREAK + "0."), t)

## The gift card set's card says what it is, not a list of "1x Gift Card: ..." lines.
func test_gift_card_set_contents() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_gift_cards")
	assert_true(ShopScreen.gift_card_set(o))
	var t: String = ShopScreen.short_contents(o)
	assert_false(t.contains("1x"), t)
	assert_eq(t, ShopScreen.first_sentence(Loc.t(str(o.desc))))
	assert_false(ShopScreen.gift_card_set(ShopCatalog.offer("rg_glass_1000")))

## When a Riftglass question is too long for the list title, the list keeps its last line: the
## price with its euro value.
func test_price_stays_on_the_list() -> void:
	Billing.state = {"balance": 1250}
	var host: MenuHost = _host(4)
	await wait_process_frames(1)
	for title: String in [RiftglassSinks.price_question(Loc.t("Heal the whole team now? Full Vigor, Energy, no states."), 100),
			BattleScene.continue_title(200)]:
		var short: String = host.short_title(title)
		assert_true(short.contains(ShopCatalog.euro_hint(100)) or short.contains(ShopCatalog.euro_hint(200)), short)
