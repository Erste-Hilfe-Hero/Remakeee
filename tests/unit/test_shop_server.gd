extends GutTest
## Shop on the local stand-in server (same rules as supabase/migrations/20261110000020_shop.sql)
## and the Billing flow with the local test store: age gate, limits, Riftglass purchases, store
## receipts credited once and finished only afterwards, refunds, pass, moving phones.

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_store: BillingStore
var _old_inventory: Dictionary
var _old_money: int
var _old_in_game: bool
var s: LocalBackend
var shop: LocalShop
var store: LocalBilling

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_store = Billing.store
	_old_inventory = GameState.inventory.duplicate()
	_old_money = GameState.money
	_old_in_game = GameState.in_game

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Billing.store = _old_store
	Billing.state = {}
	GameState.inventory = _old_inventory
	GameState.money = _old_money
	GameState.in_game = _old_in_game

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	shop = LocalShop.of(s)
	Online.backend = s
	Online.state = Online.State.ONLINE
	store = LocalBilling.new()
	Billing.store = store
	Billing.state = {}
	Billing.prices = {}
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	GameState.inventory = {}
	GameState.money = 0
	# No journey is open: deliveries go into the bag without saving to the test server.
	GameState.in_game = false

func _call(fn: String, args: Dictionary = {}) -> Variant:
	return s.call_fn(fn, args).data

func _year(age: int) -> int:
	return int(Time.get_date_dict_from_unix_time(s.now()).year) - age - 1

## A ready offer that costs Riftglass (most real ones get ready with their effects).
func _ready_offer(id: String) -> Dictionary:
	var o: Dictionary = ShopCatalog.offer(id)
	o["ready"] = true
	return o

func after_each() -> void:
	for id: String in ["rg_ring_tonic", "rg_team_slot_6", "rg_rift_pack_1", "rg_pass", "rg_gleam_prism"]:
		ShopCatalog.offer(id)["ready"] = false

func test_age_bands() -> void:
	var today: Dictionary = {"year": 2026, "month": 11, "day": 6}
	assert_eq(LocalShop.band_for(2016, 1, today).band, 0)
	assert_eq(LocalShop.band_for(2013, 11, today).band, 13)
	assert_eq(LocalShop.band_for(2013, 12, today).band, 0, "13 only from next month")
	assert_eq(LocalShop.band_for(2010, 6, today).band, 16)
	assert_eq(LocalShop.band_for(1990, 1, today).band, 18)

func test_children_cannot_shop_or_switch() -> void:
	assert_eq(_call("shop_state").band, null)
	assert_eq(_call("shop_buy", {"p_offer": "rg_ring_tonic", "p_expected_price": 100}).error, "age_needed")
	assert_eq(_call("shop_set_age", {"p_year": _year(9), "p_month": 1}).band, 0)
	assert_eq(_call("shop_set_age", {"p_year": 1980, "p_month": 1}).error, "age_locked", "no jump to adult")
	assert_eq(_call("shop_state").cap_cents, 0)
	await Billing.refresh_state()
	assert_true(Billing.kids_locked(), "the pause menu shows Shop (locked)")

func test_band_rises_on_the_day() -> void:
	var y: int = int(Time.get_date_dict_from_unix_time(s.now()).year) - 13
	_call("shop_set_age", {"p_year": y + 1, "p_month": 1})
	assert_eq(_call("shop_state").band, 0)
	s.clock_offset += 400 * 86400
	assert_eq(_call("shop_state").band, 13, "turned 13: the shop opens by itself")

func test_teen_limit_is_fixed() -> void:
	_call("shop_set_age", {"p_year": _year(14), "p_month": 1})
	assert_eq(_call("shop_state").cap_cents, 1500)
	assert_eq(_call("shop_set_limit", {"p_cap_cents": 9000}).error, "fixed_limit")

func test_adult_limit_raise_waits() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	assert_eq(_call("shop_state").cap_cents, 10000)
	assert_eq(_call("shop_set_limit", {"p_cap_cents": 2500}).cap_cents, 2500, "lower at once")
	var r: Dictionary = _call("shop_set_limit", {"p_cap_cents": 30000})
	assert_eq(r.cap_cents, 2500)
	assert_eq(r.raise_to_cents, 30000)
	assert_eq(_call("shop_set_limit", {"p_cap_cents": 30100}).error, "bad_limit")
	s.clock_offset += 7 * 86400 + 1
	assert_eq(_call("shop_state").cap_cents, 30000, "raised after 7 days")

func test_store_purchase_flow() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	await Billing.refresh_state()
	await Billing.query_products(["de.chimora.game.glass.500"] as Array[String])
	var o: Dictionary = ShopCatalog.offer("rg_glass_500")
	assert_eq(Billing.price_text(o), "4,99 €", "price text from the store")
	var r: Dictionary = await Billing.buy_in_store(o)
	assert_true(r.get("ok", false), str(r))
	assert_eq(Billing.balance(), 500)
	assert_eq(store.finished.size(), 1, "finished in the store after the server credited it")
	assert_eq(Billing.step, Billing.Step.CREDITED)
	# The same receipt again counts once.
	var again: Dictionary = shop.credit(s.me(), "local", store.finished[0], "de.chimora.game.glass.500", 499)
	assert_true(again.get("duplicate", false))
	assert_eq(_call("shop_state").balance, 500)

func test_cancelled_and_failed_purchases() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	var o: Dictionary = ShopCatalog.offer("rg_glass_100")
	store.cancel_next = true
	assert_eq((await Billing.buy_in_store(o)).error, "cancelled")
	assert_eq(Billing.step, Billing.Step.CANCELLED)
	# The server is unreachable after the store took the money: the purchase stays open and is
	# sent again after reconnecting (item 4098).
	var p: Dictionary = await store.purchase(str(o.product_id), "", s.me().sha256_text())
	assert_eq(store.unfinished().size(), 1)
	s.offline = true
	await Billing._verify(p.receipt)
	assert_eq(Billing.step, Billing.Step.FAILED)
	assert_eq(store.finished.size(), 0, "not finished before it was credited")
	s.offline = false
	Online.state = Online.State.ONLINE
	assert_eq(await Billing.resume_pending(), 1)
	assert_eq(store.unfinished().size(), 0)
	assert_eq(_call("shop_state").balance, 100)

func test_second_tap_starts_nothing() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	Billing._buying = true
	assert_eq((await Billing.buy_in_store(ShopCatalog.offer("rg_glass_100"))).error, "busy")
	assert_true(Billing.busy())
	Billing._buying = false
	assert_true((await Billing.buy_in_store(ShopCatalog.offer("rg_glass_100"))).get("ok", false))
	assert_false(Billing.busy(), "free again after the purchase")
	assert_eq(store.finished.size(), 1, "only one purchase")

func test_limit_checked_before_store() -> void:
	_call("shop_set_age", {"p_year": _year(14), "p_month": 1})
	await Billing.refresh_state()
	assert_true((await Billing.buy_in_store(ShopCatalog.offer("rg_glass_1000"))).get("ok", false))
	var r: Dictionary = await Billing.buy_in_store(ShopCatalog.offer("rg_glass_1000"))
	assert_eq(r.error, "limit", "9,99 + 9,99 > 15 EUR: the store sheet does not even open")
	assert_eq(store.finished.size(), 1)

func test_over_limit_store_purchase_locks_shop() -> void:
	_call("shop_set_age", {"p_year": _year(14), "p_month": 1})
	_ready_offer("rg_ring_tonic")
	shop.credit(s.me(), "google", "G1", "de.chimora.game.glass.1000", 999)
	var r: Dictionary = shop.credit(s.me(), "google", "G2", "de.chimora.game.glass.1000", 999)
	assert_true(r.ok and r.locked, "credited but locked (item 4251)")
	assert_eq(_call("shop_buy", {"p_offer": "rg_ring_tonic", "p_expected_price": 100}).error, "limit_reached")
	s.clock_offset += 32 * 86400
	assert_true(_call("shop_buy", {"p_offer": "rg_ring_tonic", "p_expected_price": 100}).ok, "open again next month")

func test_riftglass_purchase_delivers_items() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	_ready_offer("rg_ring_tonic")
	shop.credit(s.me(), "apple", "A1", "de.chimora.game.glass.200", 199)
	await Billing.refresh_state()
	var o: Dictionary = ShopCatalog.offer("rg_ring_tonic")
	var r: Dictionary = await Billing.buy_with_riftglass(o)
	assert_true(r.get("ok", false), str(r))
	assert_eq(Billing.balance(), 100)
	assert_eq(GameState.item_count("rg_ring_tonic"), 1, "delivered into the bag by the server")
	assert_eq(_call("shop_claim"), [], "only once")
	assert_eq(_call("shop_buy", {"p_offer": "rg_ring_tonic", "p_expected_price": 50}).error, "price_changed")
	assert_eq(_call("shop_buy", {"p_offer": "rg_team_slot_6", "p_expected_price": 1500}).error, "not_available", "only ready offers")

func test_once_per_account_and_choice() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	_ready_offer("rg_team_slot_6")
	_ready_offer("rg_rift_pack_1")
	shop.credit(s.me(), "apple", "A1", "de.chimora.game.glass.2000", 1999)
	assert_true(_call("shop_buy", {"p_offer": "rg_team_slot_6", "p_expected_price": 1500}).ok)
	assert_eq(_call("shop_buy", {"p_offer": "rg_team_slot_6", "p_expected_price": 1500}).error, "offer_limit")
	assert_eq(_call("shop_state").unlocks, {"team_slot_6": 1})
	# A Rift pack needs a sealed Rift and a choice made before buying; a store purchase without one
	# gets the first choice instead of a random one.
	assert_eq(shop.offer_block(s.me(), ShopCatalog.offer("rg_rift_pack_1"), "rg_prism_tide"), "not_yet")
	s.call_fn("save_put", {"p_slot": 1, "p_data": {"schema": 1, "rifts": ["ashfall"], "party": []}, "p_summary": "", "p_base_rev": 0})
	assert_eq(shop.offer_block(s.me(), ShopCatalog.offer("rg_rift_pack_1"), null), "choice_needed")
	assert_true(shop.credit(s.me(), "apple", "A2", "de.chimora.game.consumable.rift_pack_1", 499, "rg_prism_tide").ok)
	var got: Array = _call("shop_claim")
	assert_eq(got[0].grants[1], {"t": "item", "id": "rg_prism_tide", "n": 1})
	assert_eq(shop.credit(s.me(), "apple", "A3", "de.chimora.game.consumable.rift_pack_1", 499).ok, true, "the money is taken: still credited")

func test_refund_takes_back() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	_ready_offer("rg_team_slot_6")
	shop.credit(s.me(), "apple", "A1", "de.chimora.game.glass.2000", 1999)
	_call("shop_buy", {"p_offer": "rg_team_slot_6", "p_expected_price": 1500})
	assert_true(shop.refund("apple", "A1").ok)
	assert_eq(_call("shop_state").balance, -1500, "spent Riftglass is taken back too")
	assert_true(_call("shop_state").locked)
	assert_true(shop.refund("apple", "A1").get("duplicate", false))
	var h: Array = _call("shop_history")
	assert_eq(h[1].status, "refunded")

func test_pass_daily_riftglass() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	assert_eq(_call("shop_pass_daily").error, "no_pass")
	shop.sub_set(s.me(), "apple", "P1", "de.chimora.game.pass", s.now() + 30 * 86400, "active", true)
	assert_true(_call("shop_state").pass_active)
	assert_eq(_call("shop_pass_daily").added, 30)
	assert_eq(_call("shop_pass_daily").added, 0, "once a day")
	s.clock_offset += 20 * 86400
	assert_eq(_call("shop_pass_daily").added, 210, "missed days paid, at most 7")
	s.clock_offset += 11 * 86400
	assert_false(_call("shop_state").pass_active, "benefits end with the pass")

func test_pass_page_lists_every_benefit() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	await Billing.refresh_state()
	var o: Dictionary = ShopCatalog.offer("rg_pass")
	var t: String = ShopMenu.detail_text(o)
	for part: String in ["+50% growth", "30 Riftglass every day", "900 in 30 days", "11 of 10", "Rift Breath",
			"bond try", "not in the Fair League", "echo duels", "renews automatically", "Cancel any time", "No pass right now."]:
		assert_string_contains(t, part)
	assert_string_contains(t, ShopCatalog.format_eur(499))
	shop.sub_set(s.me(), "apple", "P1", "de.chimora.game.pass", s.now() + 30 * 86400, "active", true)
	await Billing.refresh_state()
	assert_string_contains(ShopMenu.detail_text(o), "Your pass runs until")

func test_refresh_claims_the_pass_riftglass_once() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	shop.sub_set(s.me(), "apple", "P1", "de.chimora.game.pass", s.now() + 30 * 86400, "active", true)
	watch_signals(Billing)
	await Billing.refresh_state()
	assert_true(ShopEffects.pass_active())
	assert_signal_emitted_with_parameters(Billing, "pass_paid", [30])
	assert_eq(Billing.balance(), 30, "the shown balance includes it")
	await Billing.refresh_state()
	assert_signal_emit_count(Billing, "pass_paid", 1, "once a day")

func test_transfer_keeps_purchases() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	shop.credit(s.me(), "apple", "A1", "de.chimora.game.glass.500", 499)
	var code: String = _call("transfer_create").code
	s.switch_user("ann_new_phone")
	s.call_fn("hello", {"p_version": 1})
	assert_true(_call("transfer_claim", {"p_code": code}).ok)
	assert_eq(_call("shop_state").balance, 500)
	assert_eq(_call("shop_state").band, 18)

func test_shop_menu_texts() -> void:
	Loc.set_language("de")
	Billing.state = {"balance": 500}
	assert_eq(ShopMenu.title(), "Shop\n500 Rissglas (≈ 4,95 €)")
	var o: Dictionary = ShopCatalog.offer("rg_ring_tonic")
	assert_true(ShopMenu.row_text(o).begins_with("+ Ring-Trank"), ShopMenu.row_text(o))
	var d: String = ShopMenu.detail_text(o)
	assert_string_contains(d, "Vorteil im Spiel")
	assert_string_contains(d, "100 Rissglas (≈ 0,99 €)")
	assert_string_contains(d, "Offenen Liga")
	var jacket: String = ShopMenu.detail_text(ShopCatalog.offer("rg_jacket_moss"))
	assert_false("Vorteil im Spiel" in jacket, "cosmetics are not marked as advantage")
	assert_string_contains(ShopMenu.history_text([{"offer": "rg_glass_500", "store": "apple", "eur_cents": 499, "rg": 0,
		"status": "refunded", "at": 1793900000}]), "4,99 €  (erstattet)")
	Loc.set_language("en")
	Billing.state = {}

## Item 4148: at most 30 Riftglass purchases per hour, like the server.
func test_riftglass_buys_are_rate_limited() -> void:
	_call("shop_set_age", {"p_year": 1990, "p_month": 3})
	_ready_offer("rg_ring_tonic")
	var st: Dictionary = shop._shop(s.me())
	for i: int in LocalShop.BUYS_PER_HOUR:
		st.purchases.append({"id": 900 + i, "store": "riftglass", "txn": "", "product": "", "offer": "rg_ring_tonic",
			"eur_cents": 0, "rg": 100, "choice": null, "status": "credited", "at": s.now()})
	assert_eq(_call("shop_buy", {"p_offer": "rg_ring_tonic", "p_expected_price": 100}).error, "slow_down")
	s.clock_offset += 3601
	assert_ne(str(_call("shop_buy", {"p_offer": "rg_ring_tonic", "p_expected_price": 100}).get("error", "")), "slow_down")
