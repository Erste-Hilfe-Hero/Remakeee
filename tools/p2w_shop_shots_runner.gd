extends Node
## The work of tools/p2w_shop_shots.gd, run as a node so the autoloads exist. Prints every
## ShopScreen.fit_problems() it finds; the exit code is 1 when there is one.

var out: String = "user://p2w_shop_shots"
var langs: PackedStringArray = ["de", "en"]
var era: int = 1
var _problems: int = 0

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
	for lang: String in langs:
		setup.call("setup_state")
		GameState.language = lang
		Loc.set_language(lang)
		EraManager.unlocked_era = era
		EraManager.set_retro_filter(0)
		await get_tree().process_frame
		await get_tree().process_frame
		await _screens(lang)
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
	var s := ShopScreen.new()
	s.menu = m
	m.add_child(s)
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
	m.add_child(pop)
	await _picture(t + "_15_starter_note", pop)
	pop.queue_free()
	# A child account: the menu row says locked and the shop says why.
	_state(10)
	m.info(ShopMenu.LOCKED_TEXT)
	await _picture(t + "_16_kids_locked", null)
	m._close_info()
	m.queue_free()
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
