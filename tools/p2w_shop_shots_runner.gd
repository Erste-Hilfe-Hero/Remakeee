extends Node
## The work of tools/p2w_shop_shots.gd, run as a node so the autoloads exist. Prints every
## ShopScreen.fit_problems() it finds; the exit code is 1 when there is one.
## Besides the shop: the pass track screen (PassScreen.run), the Riftglass menu with "heal
## anywhere" and its dialogs, the "not enough" link to the shop's Riftglass tab, and the continue
## offer after a lost battle (BattleScene._offer_continue).

var out: String = "user://p2w_shop_shots"
var langs: PackedStringArray = ["de", "en"]
var era: int = 1
## Every era to shoot, in order (the command line takes "1", "1,4" or "all").
var eras: Array[int] = []
var _problems: int = 0
var _backend: LocalBackend

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://p2w_shop_shots_settings.json"
	var setup: GDScript = load("res://tools/era_menu_shots_runner.gd")
	# The shots set the shop state themselves; a server answer must not replace it.
	if Online.has_signal("state_changed") and Online.state_changed.is_connected(Billing._on_online_state):
		Online.state_changed.disconnect(Billing._on_online_state)
	demo_fields()
	if eras.is_empty():
		eras = [era]
	for e: int in eras:
		era = e
		for lang: String in langs:
			setup.call("setup_state")
			GameState.language = lang
			Loc.set_language(lang)
			EraManager.unlocked_era = era
			EraManager.set_retro_filter(0)
			await get_tree().process_frame
			await get_tree().process_frame
			await _screens(lang)
			await _pass_screens(lang)
			await _sink_screens(lang)
			await _continue_screen(lang)
	EraManager.unlocked_era = 1
	print("p2w_shop_shots: %d fit problems" % _problems)
	get_tree().quit(1 if _problems > 0 else 0)

## Until the offer data has its new fields (badge, discount, end, bonus, first buy x2,
## featured), the shots show them on a few offers so every tag is seen. The discount is the real
## value against the single prices.
static func demo_fields() -> void:
	for o: Dictionary in ShopCatalog.offers():
		if o.has("featured") or o.has("badge"):
			return
	var demo: Dictionary = {
		"rg_starter": {"featured": true, "badge": "best_value", "ends_at": _in_days(3)},
		"rg_power_seal_1": {"featured": true, "badge": "bestseller"},
		"rg_wayfarer_pack": {"featured": true, "badge": "limited"},
		"rg_glass_1000": {"badge": "hot", "bonus_pct": 10, "first_buy_double": true},
		"rg_glass_5000": {"badge": "best_value", "bonus_pct": 20},
		"rg_growth_plus": {"badge": "new"},
	}
	for id: String in demo:
		var o: Dictionary = ShopCatalog.offer(id)
		o.merge(demo[id], true)
		var worth: int = ShopCatalog.euro_cents(ShopCatalog.single_value(o))
		if str(o.get("tab", "")) == "packs" and worth > int(o.get("eur_cents", 0)):
			o["discount_pct"] = 100 - int(round(100.0 * int(o.eur_cents) / worth))

static func _in_days(d: int) -> String:
	return Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + d * 86400 + 5 * 3600)

func _state(band: int) -> void:
	Billing.state = {"balance": 1250, "band": band, "open": true, "bought": {}, "unlocks": {"jacket_moss": 1},
		"rifts": 1, "cap_cents": 10000, "spent_cents": 0, "withdrawal_ok": true}
	Billing.prices.clear()
	# A pretend store answer, so the euro prices show as on a phone.
	for o: Dictionary in ShopCatalog.offers():
		Billing.prices[str(o.get("product_id", ""))] = ShopCatalog.format_eur(int(o.get("eur_cents", 0)))

func _screens(lang: String) -> void:
	var t: String = "era%d_%s" % [era, lang]
	var m := PauseMenu.new()
	add_child(m)
	await get_tree().process_frame
	_state(18)
	# As in the game: Eras IV and V show the shop twice as large (ShopZoom).
	var h: MenuHost = ShopZoom.enter(m)
	var s := ShopScreen.new()
	s.menu = h
	h.add_child(s)
	for tab: String in ShopScreen.TABS:
		s.select_tab(tab)
		await _picture(t + "_%02d_%s" % [ShopScreen.TABS.find(tab) + 1, tab], s)
		if tab in ["featured", "advantages"]:
			s._scroll.scroll_vertical = 100000
			await _picture(t + "_%02d_%s_end" % [ShopScreen.TABS.find(tab) + 1, tab], s)
	s.show_detail(ShopCatalog.offer("rg_starter"))
	await _picture(t + "_10_detail_starter", s)
	s.show_detail(ShopCatalog.offer("rg_power_seal_1"))
	await _picture(t + "_11_detail_seal", s)
	s.show_detail(ShopCatalog.offer("rg_glass_1000"))
	await _picture(t + "_12_detail_riftglass", s)
	s.show_detail(ShopCatalog.offer("rg_jacket_moss"))
	await _picture(t + "_13_detail_owned_look", s)
	# Under 18: the end shows as a date.
	_state(16)
	s.select_tab("featured")
	await _picture(t + "_14_featured_under18", s)
	s.queue_free()
	_state(18)
	var pop := ShopScreen.StarterPopup.new()
	pop.offer = ShopCatalog.offer("rg_starter")
	h.add_child(pop)
	await _picture(t + "_15_starter_note", pop)
	pop.queue_free()
	# A child account: the menu row says locked and the shop says why.
	_state(10)
	h.info(ShopMenu.LOCKED_TEXT)
	await _picture(t + "_16_kids_locked", null)
	h._close_info()
	ShopZoom.leave(h)
	m.queue_free()
	await get_tree().process_frame

## A local stand-in server for the pass track and the Riftglass dialogs (no network).
func _server(balance: int, band_year: int = 1990) -> void:
	_backend = LocalBackend.new()
	_backend.rng.seed = 1
	Online.backend = _backend
	Online.state = Online.State.ONLINE
	_backend.switch_user("shots")
	_backend.call_fn("hello", {"p_version": 1})
	_backend.call_fn("shop_set_age", {"p_year": band_year, "p_month": 3})
	if balance > 0:
		LocalShop.of(_backend)._ledger_add(_backend.me(), balance, "support", "shots")
	await Billing.refresh_state()

## Waits until [param host] shows a list or a text page (at most [param frames] frames).
func _wait_dialog(host: MenuHost, picks: int, infos: int, frames: int = 120) -> void:
	for i: int in frames:
		await get_tree().process_frame
		if _live(host).picks > picks or _live(host).infos > infos:
			return

## The host that shows the dialogs of [param m]: the zoomed one over it (ShopZoom), else [param m].
static func _live(m: Node) -> MenuHost:
	var v: Node = _zoom_of(m)
	return v.get_child(0).get_child(0) as MenuHost if v != null else m as MenuHost

static func _zoom_of(n: Node) -> Node:
	for c: Node in n.get_children():
		if c is ShopZoom.View:
			return c
	return null

static func _find_shop(n: Node) -> ShopScreen:
	for c: Node in n.get_children():
		if c is ShopScreen:
			return c
		var d: ShopScreen = _find_shop(c)
		if d != null:
			return d
	return null

## The pass track screen without and with the pass: points in step 5, two free rewards taken.
func _pass_screens(lang: String) -> void:
	var t: String = "era%d_%s" % [era, lang]
	for premium: bool in [false, true]:
		await _server(0)
		var lp: LocalPassTrack = LocalPassTrack.of(_backend)
		var row: Dictionary = lp.row(_backend.me())
		row.points = PassTrack.per_tier() * 5 + PassTrack.per_tier() / 2
		row.claimed_free = 3
		if premium:
			LocalShop.of(_backend).sub_set(_backend.me(), "local", "pass-1", "de.chimora.game.pass", _backend.now() + 30 * 86400, "active", true)
			await Billing.refresh_state()
		var m := PauseMenu.new()
		add_child(m)
		await get_tree().process_frame
		PassScreen.run(m)
		await _wait_dialog(m, 0, 0)
		await _picture(t + ("_21_pass_track_premium" if premium else "_20_pass_track"), null)
		if not premium:
			# A step page with the premium row locked.
			_live(m).picker.picked.emit(_first_step_row(_live(m)))
			await _wait_dialog(m, 1, 0)
			await _picture(t + "_22_pass_step", null)
			await _past_page(m, t + "_23_pass_step_choice")
		m.close_all = true
		m.queue_free()
		await get_tree().process_frame

## A long question shows as a page before its list (MenuHost.pick): turn it, shoot the list.
func _past_page(outer: MenuHost, shot: String) -> void:
	var m: MenuHost = _live(outer)
	if not m._info_wait:
		return
	var picks: int = m.picks
	m._close_info()
	await _wait_dialog(outer, picks, m.infos)
	await _picture(shot, null)

func _first_step_row(m: MenuHost) -> int:
	var i: int = 0
	for b: Button in m.picker.buttons():
		if b.text.contains(Loc.t("Step %d") % 6):
			return i
		i += 1
	return 2

## The Riftglass menu (pause menu row): heal anywhere with its price question, and with too
## little Riftglass the line that leads to the shop's Riftglass tab.
func _sink_screens(lang: String) -> void:
	var t: String = "era%d_%s" % [era, lang]
	await _server(1250)
	var m := PauseMenu.new()
	add_child(m)
	await get_tree().process_frame
	RiftglassSinks.run_menu(m)
	await _wait_dialog(m, 0, 0)
	await _picture(t + "_30_rg_menu", null)
	_live(m).picker.picked.emit(0)
	await _wait_dialog(m, 1, 0)
	await _picture(t + "_31_rg_heal_anywhere", null)
	await _past_page(m, t + "_31b_rg_heal_choice")
	m.close_all = true
	m.queue_free()
	await get_tree().process_frame
	await _server(0)
	m = PauseMenu.new()
	add_child(m)
	await get_tree().process_frame
	RiftglassSinks.run_menu(m)
	await _wait_dialog(m, 0, 0)
	_live(m).picker.picked.emit(0)
	await _wait_dialog(m, 1, 0)
	await _picture(t + "_32_rg_not_enough", null)
	await _past_page(m, t + "_32b_rg_not_enough_choice")
	# "Riftglass shop": the shop screen on its Riftglass tab.
	_live(m).picker.picked.emit(0)
	var s: ShopScreen = null
	for i: int in 240:
		await get_tree().process_frame
		s = _find_shop(m)
		if s != null:
			break
	if s == null:
		_problems += 1
		printerr("%s: the Riftglass link opened no shop screen" % t)
	else:
		await _picture(t + "_33_rg_link_to_shop_tab", s)
	m.close_all = true
	m.queue_free()
	await get_tree().process_frame

## The continue offer after the team is beaten in a story battle (no shop window in battle).
func _continue_screen(lang: String) -> void:
	var t: String = "era%d_%s" % [era, lang]
	await _server(1250)
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = BattleScene.DEMO_SEED
	var mine: Array[Spirling] = BattleScene._demo_team(rng, ["Kindlop", "Puddlet"] as Array[String], 14)
	var theirs: Array[Spirling] = BattleScene._demo_team(rng, ["Zippit", "Shalebat"] as Array[String], 14)
	var model := BattleModel.new(mine, theirs, false, BattleScene.DEMO_SEED, 1)
	model.trainer_name = "Rift Mystic Ilka"
	inst.setup(model)
	get_tree().root.add_child(inst)
	for i: int in 1800:
		if inst._menu != null and inst._menu._content != null and inst._menu._content.visible:
			break
		inst._text.advance_now()
		await get_tree().process_frame
	inst._menu._content.visible = false
	inst._offer_continue()
	for i: int in 240:
		await get_tree().process_frame
		if inst._picker.visible or _zoom_of(inst) != null:
			break
		if i % 20 == 19:
			inst._text.advance_now()
	# Zoomed (Eras IV, V): a long question shows as a page first; the shot is the list.
	if _zoom_of(inst) != null:
		var lh: MenuHost = _live(inst)
		for i: int in 60:
			await get_tree().process_frame
			if lh._info_wait:
				lh._close_info()
			elif lh.picker.is_visible_in_tree():
				break
	await _picture(t + "_40_continue_after_defeat", null)
	inst.queue_free()
	await get_tree().process_frame

func _picture(shot: String, s: Control) -> void:
	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if s != null:
		for p: String in ShopScreen.fit_problems(s):
			_problems += 1
			printerr("%s: %s" % [shot, p])
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])
