extends GutTest
## The pass track's list shows every row's whole text (1.3.2 store shots: the "Premium row:
## Wayfarer Pass" row, three lines in Russian, had its first line cut off at the top: the list
## opened scrolled by a few pixels to show the focused step, ListPicker._show_whole_rows).
## Every language, every era, on the iPhone SE's view (ShopZoom): a wrapping row is as tall as
## its wrapped text, no row is cut at the top of the list, every row keeps 44 pt.

var _keep: Dictionary = {}
var _old_backend: OnlineBackend
var _old_state: Online.State
var _billing: Dictionary
var s: LocalBackend

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_keep = {"unlocked": EraManager.unlocked_era, "retro": EraManager.retro_filter, "lang": Loc.language()}

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	EraManager.unlocked_era = _keep.unlocked
	EraManager.set_retro_filter(_keep.retro)
	Loc.set_language(_keep.lang)

func before_each() -> void:
	_billing = Billing.state
	s = LocalBackend.new()
	s.rng.seed = 1
	Online.backend = s
	Online.state = Online.State.ONLINE
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	s.call_fn("shop_set_age", {"p_year": 1990, "p_month": 3})
	await Billing.refresh_state()

func after_each() -> void:
	Billing.state = _billing

## The height a button needs for its text at its own width, wrapped as it wraps.
static func needed_height(b: Button) -> float:
	var sb: StyleBox = b.get_theme_stylebox("normal")
	var f: Font = b.get_theme_font("font")
	var w: float = b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var text_h: float = f.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, w, b.get_theme_font_size("font_size"), -1, flags).y
	return text_h + sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)

## Rows of [param lp] that are cut: too short for their text, cut at the top of the list, or
## below 44 pt.
static func row_problems(lp: ListPicker, pt: float) -> Array[String]:
	var out: Array[String] = []
	var top: int = lp._scroll.scroll_vertical
	for b: Button in lp.buttons():
		var name: String = b.text.replace("\n", " ")
		if b.autowrap_mode != TextServer.AUTOWRAP_OFF and b.size.y + 0.5 < needed_height(b):
			out.append("%s: %.0f px tall, needs %.0f" % [name, b.size.y, needed_height(b)])
		if b.get_parent() is VBoxContainer and b.position.y < top and b.position.y + b.size.y > top:
			out.append("%s: cut at the top (%d of %.0f px hidden)" % [name, top - int(b.position.y), b.size.y])
		if b.size.y * ShopZoom.screen_scale(b) * pt < ShopZoom.MIN_TOUCH_PT - 0.01:
			out.append("%s: below 44 pt" % name)
	return out

func _live(host: MenuHost) -> MenuHost:
	var v: Node = host.get_node_or_null("shop_zoom")
	return v.get_child(0).get_child(0) as MenuHost if v != null else host

func _wait_list(host: MenuHost) -> MenuHost:
	var live: MenuHost = host
	for i: int in 90:
		await wait_process_frames(1)
		live = _live(host)
		if live._info_wait:
			live._close_info()
		elif live.picks > 0 and live.picker.is_visible_in_tree():
			break
	return live

## With the premium row, pass points in step 5 and three free rewards taken (the store shot's
## state: the list opens scrolled to step 6).
func test_pass_rows_whole_in_every_language_and_era() -> void:
	var row: Dictionary = LocalPassTrack.of(s).row(s.me())
	row.points = PassTrack.per_tier() * 5 + PassTrack.per_tier() / 2
	row.claimed_free = 3
	var bad: Array[String] = []
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		for e: int in range(1, 6):
			EraManager.unlocked_era = e
			EraManager.set_retro_filter(0)
			var vp := SubViewport.new()
			vp.size = ShopZoom.phone_view(e)
			add_child_autofree(vp)
			var host := MenuHost.new()
			vp.add_child(host)
			await wait_process_frames(1)
			PassScreen.run(host)
			var live: MenuHost = await _wait_list(host)
			await wait_process_frames(3)
			for p: String in row_problems(live.picker, ShopZoom.pt_per_px(e)):
				bad.append("%s era %d: %s" % [lang, e, p])
			live.close_all = true
			await wait_process_frames(4)
	for b: String in bad:
		print("ROW PROBLEM ", b)
	assert_eq(bad, [] as Array[String])

func test_pass_reward_names_fill_in_every_language() -> void:
	var e: Dictionary = {"t": "spirling", "species": "Kindlop", "level": 30, "n": 1}
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		var t: String = ShopCatalog.entry_name(e)
		assert_true(t.contains("30") and not t.contains("{") and not t.contains("%"), "%s: %s" % [lang, t])
