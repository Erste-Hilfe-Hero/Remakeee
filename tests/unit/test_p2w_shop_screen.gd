extends GutTest
## The new shop screen (pay-to-win shop rebuild, Ali 27.11.2026): icons, tags, Featured page,
## prices, the Starter Pack note rules, the wiring into the old shop paths and that no text is
## cut off on the smallest screen.

var _state: Dictionary
var _prices: Dictionary
var _lang: String
var _host: MenuHost

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_state = Billing.state
	_prices = Billing.prices.duplicate()
	_lang = Loc.language()
	Loc.set_language("en")
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	Billing.state = {"balance": 1250, "band": 18, "open": true, "bought": {}, "unlocks": {}, "rifts": 1,
		"cap_cents": 10000, "spent_cents": 0}

func after_each() -> void:
	Billing.state = _state
	Billing.prices = _prices
	Loc.set_language(_lang)
	if _host != null:
		_host.free()
		_host = null

func test_icons_are_sound() -> void:
	assert_eq(ShopArt.problems(), [] as Array[String])
	for t: String in ShopScreen.TABS:
		assert_not_null(ShopArt.icon(ShopArt.TAB_ICONS[t]), t)
	assert_eq(ShopArt.icon_key(ShopCatalog.offer("rg_power_seal_1")), "sword")
	assert_eq(ShopArt.icon_key(ShopCatalog.offer("rg_starter")), "chest")
	assert_eq(ShopArt.icon_key(ShopCatalog.offer("rg_glass_100")), "gem")

func test_tag_text_is_readable() -> void:
	for k: String in ShopArt.TAG_COLORS:
		var c: Array = ShopArt.TAG_COLORS[k]
		assert_gte(UITheme.contrast(c[0], c[1]), 4.5, k)

func test_tags() -> void:
	var o: Dictionary = {"id": "x", "badge": "best_value", "discount_pct": 40, "bonus_pct": 10, "first_buy_double": true,
		"ends_at": "2030-01-02T18:00:00"}
	var kinds: Array = ShopScreen.tags(o, 0).map(func(t: Array) -> String: return str(t[1]))
	assert_eq(kinds, ["best_value", "discount", "bonus", "double", "time"])
	assert_eq(str(ShopScreen.tags(o, 0)[1][0]), "-40 %")
	Billing.state["bought"] = {"x": 1}
	assert_false("double" in ShopScreen.tags(o, 0).map(func(t: Array) -> String: return str(t[1])), "x2 only before the first buy")
	# Ended offers carry no time tag and are not shown.
	assert_true(ShopScreen.expired(o, ShopScreen.end_time(o) + 1))
	assert_true(ShopScreen.tags({"badge": "unknown"}, 0).is_empty())

func test_end_is_a_date_not_a_countdown() -> void:
	var t: String = ShopScreen.time_text(ShopScreen.end_time({"ends_at": "2030-01-02T00:00:00"}))
	assert_true(t.begins_with("Until "), t)
	assert_false(t.contains("Ends in"))

func test_featured_fallback_and_owned() -> void:
	var list: Array[Dictionary] = ShopScreen.featured_offers()
	assert_false(list.is_empty())
	var marked: bool = false
	for o: Dictionary in ShopCatalog.offers():
		marked = marked or bool(o.get("featured", false))
	if not marked:
		assert_eq(str(list[0].id), "rg_starter", "the Starter Pack is the banner")
		assert_eq(str(list.back().tab), "riftglass", "then the best Riftglass tier")
	Billing.state["bought"] = {"rg_starter": 1}
	for o: Dictionary in ShopScreen.featured_offers():
		assert_ne(str(o.id), "rg_starter", "a bought once-only pack leaves Featured")

func test_card_price() -> void:
	assert_eq(ShopScreen.card_price(ShopCatalog.offer("rg_power_seal_1")), "500")
	Billing.prices = {}
	assert_eq(ShopScreen.card_price(ShopCatalog.offer("rg_glass_500")), "Show", "no made-up euro price without the store")
	Billing.prices = {str(ShopCatalog.offer("rg_glass_500").product_id): "4,99 €"}
	assert_eq(ShopScreen.card_price(ShopCatalog.offer("rg_glass_500")), "4,99 €")
	Billing.state["unlocks"] = {"jacket_moss": 1}
	assert_eq(ShopScreen.card_price(ShopCatalog.offer("rg_jacket_moss")), "Owned")
	assert_eq(ShopScreen.card_price(ShopCatalog.offer("rg_power_seal_2")), "Later", "tier II after tier I")

func test_buy_options_keep_both_ways() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_power_seal_1")
	Billing.prices = {str(o.product_id): "4,99 €"}
	var opts: Array[Array] = ShopScreen.buy_options(o)
	assert_eq(opts.size(), 2)
	assert_true(bool(opts[0][1]), "Riftglass first")
	assert_true(str(opts[0][0]).contains("("), "with its euro value")
	assert_false(bool(opts[1][1]))

func test_starter_note_rules() -> void:
	var f: Dictionary = {GameState.ACT1_END_FLAG: true}
	assert_true(ShopScreen.starter_popup_due(f, 18, "", false))
	assert_false(ShopScreen.starter_popup_due(f, 10, "", false), "never for a kids_locked account")
	assert_false(ShopScreen.starter_popup_due(f, 16, "", false), "never under 18")
	assert_false(ShopScreen.starter_popup_due(f, null, "", false), "not before the age is known")
	assert_false(ShopScreen.starter_popup_due(f, 18, "", true), "never in a battle")
	assert_false(ShopScreen.starter_popup_due(f, 18, "offer_limit", false), "not once bought")
	assert_false(ShopScreen.starter_popup_due({}, 18, "", false), "not before the tutorial act ends")
	f[ShopScreen.STARTER_SEEN_FLAG] = true
	assert_false(ShopScreen.starter_popup_due(f, 18, "", false), "only once")

func test_wiring() -> void:
	var menu_src: String = FileAccess.get_file_as_string("res://scripts/shop/ShopMenu.gd")
	assert_true(menu_src.contains("ShopScreen.open(menu, open_offer)"))
	for row: String in ["My purchases", "Spending limit", "About purchases", "Help with purchases"]:
		assert_true(row in ShopScreen.more_entries(), row)
	assert_true(FileAccess.get_file_as_string("res://scripts/ui/PauseMenu.gd").contains("ShopScreen.run_starter_popup(self)"))
	assert_true(FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd").contains("ShopScreen.starter_popup_now()"))
	var pass_path: String = ShopScreen.pass_screen_path()
	assert_true(pass_path.is_empty() or ResourceLoader.exists(pass_path))

func test_nothing_cut_off_on_the_smallest_screen() -> void:
	for lang: String in ["en", "de"]:
		Loc.set_language(lang)
		_host = MenuHost.new()
		add_child(_host)
		var s := ShopScreen.new()
		s.menu = _host
		_host.add_child(s)
		for t: String in ShopScreen.TABS:
			s.select_tab(t)
			await wait_process_frames(3)
			assert_eq(ShopScreen.fit_problems(s), [] as Array[String], lang + " " + t)
		for id: String in ["rg_starter", "rg_power_seal_1", "rg_glass_1000"]:
			s.show_detail(ShopCatalog.offer(id))
			await wait_process_frames(3)
			assert_eq(ShopScreen.fit_problems(s), [] as Array[String], lang + " " + id)
		_host.free()
		_host = null
