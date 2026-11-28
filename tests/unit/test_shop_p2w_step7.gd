extends GutTest
## Pay-to-win step 7 (Ali, 27 Nov 2026): Riftglass bonus and first purchase double, Monthly Card,
## seal tiers VIII to X, Champion Spirlings, Champion Bundle, rotating daily and weekly deals, badges.
## Server rules: tools/online/sql_test/test_shop_p2w_step7.sql; here the catalog and LocalShop.

const TIERS: Dictionary = {"rg_glass_100": [0, 100], "rg_glass_200": [10, 220], "rg_glass_500": [20, 600],
	"rg_glass_1000": [30, 1300], "rg_glass_2000": [40, 2800], "rg_glass_5000": [50, 7500], "rg_glass_10000": [60, 16000]}
## Monday 30 Nov 2026 12:00 UTC (13:00 in Berlin).
const MONDAY_NOON: int = 1796040000

var _old_backend: OnlineBackend
var _old_state: Online.State
var s: LocalBackend
var shop: LocalShop

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state

func before_each() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	shop = LocalShop.of(s)
	Online.backend = s
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	s.call_fn("shop_set_age", {"p_year": 1990, "p_month": 3})

func _call(fn: String, args: Dictionary = {}) -> Variant:
	return s.call_fn(fn, args).data

func test_catalog_is_valid() -> void:
	assert_eq(ShopCatalog.validate(), [] as Array[String])

func test_riftglass_tiers_grow_and_keep_their_ids() -> void:
	var last: float = 0.0
	for id: String in TIERS:
		var o: Dictionary = ShopCatalog.offer(id)
		assert_eq(int(o.get("bonus_pct", 0)), int(TIERS[id][0]), id)
		assert_eq(int(o.grants[0].n), int(TIERS[id][1]), id + " grant holds base plus bonus")
		assert_true(bool(o.first_buy_double), id)
		assert_string_contains(o.desc, str(TIERS[id][1]))
		assert_string_contains(o.desc, str(TIERS[id][1] + ShopCatalog.rg_base(o)), "the first purchase total is named")
		assert_eq(str(o.product_id), "de.chimora.game.glass.%d" % ShopCatalog.rg_base(o), "product id unchanged")
		var per_euro: float = float(TIERS[id][1]) / float(o.eur_cents)
		assert_gt(per_euro, last - 0.0001, id + " gives at least as much per euro as the smaller tier")
		last = per_euro

func test_first_purchase_doubles_once_per_tier() -> void:
	shop.credit(s.me(), "apple", "A1", "de.chimora.game.glass.1000", 999)
	assert_eq(_call("shop_state").balance, 2300)
	shop.credit(s.me(), "apple", "A2", "de.chimora.game.glass.1000", 999)
	assert_eq(_call("shop_state").balance, 3600, "second purchase: 1300 only")
	shop.credit(s.me(), "apple", "A3", "de.chimora.game.glass.100", 99)
	assert_eq(_call("shop_state").balance, 3800, "every tier has its own first purchase")
	shop.refund("apple", "A3")
	assert_eq(_call("shop_state").balance, 3600, "a refund takes the double back")
	shop.credit(s.me(), "apple", "A4", "de.chimora.game.glass.100", 99)
	assert_eq(_call("shop_state").balance, 3700, "no second double after a refund")
	var x: Dictionary = _call("shop_extras")
	assert_eq(int(x.firsts.rg_glass_1000), 2)
	assert_eq(int(x.firsts.rg_glass_5000), 0)

func test_monthly_card() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_monthly_card")
	assert_eq(ShopCatalog.single_value(o), 3300)
	assert_eq(ShopCatalog.grant_lines(o), ["300 Riftglass", "100 Riftglass every day for 30 days"] as Array[String])
	assert_eq(_call("shop_card_daily").error, "no_card")
	shop.credit(s.me(), "google", "C1", str(o.product_id), 499)
	assert_eq(_call("shop_state").balance, 300)
	var r: Dictionary = _call("shop_card_daily")
	assert_eq([r.added, r.days_left], [100, 29])
	assert_eq(_call("shop_card_daily").added, 0, "once a day")
	s.clock_offset += 9 * 86400
	assert_eq(_call("shop_card_daily").added, 900, "missed days wait")
	s.clock_offset += 100 * 86400
	r = _call("shop_card_daily")
	assert_eq([r.added, r.days_left], [2000, 0], "never more than 30 days")
	assert_eq(_call("shop_state").balance, 3300)
	shop.credit(s.me(), "google", "C2", str(o.product_id), 499)
	r = _call("shop_card_daily")
	assert_eq([r.added, r.days_left], [100, 29], "a new card after the old one ran out")
	shop.refund("google", "C2")
	assert_eq(_call("shop_card_daily").days_left, 0, "a refund removes the unpaid days")

func test_seal_tiers_reach_ten() -> void:
	assert_eq(ShopEffects.seal_max("power_seal"), 10)
	assert_eq(ShopEffects.seal_max("guard_seal"), 10)
	assert_eq(ShopEffects.seal_max("speed_seal"), 7)
	assert_eq(ShopEffects.seal_percent("power_seal", 10), 50)
	assert_eq(str(ShopCatalog.offer("rg_power_seal_8").requires), "tier:power_seal:7")
	assert_eq(str(ShopCatalog.offer("rg_speed_seal_6").requires), "tier:speed_seal:5")
	assert_eq(ShopCatalog.unlock_offer("power_seal", 10).id, "rg_power_seal_10")
	assert_eq(ShopCatalog.single_value(ShopCatalog.offer("rg_seal_set")), 27500, "the set counts tiers I to VII")

func test_champion_spirlings_have_fixed_values() -> void:
	for sp: String in ["Fulgorath", "Ardenthal", "Obelordan"]:
		var o: Dictionary = ShopCatalog.offer("rg_champion_" + sp.to_lower())
		var m: Spirling = ShopEffects.bought_spirling(o.grants[0])
		assert_not_null(m, sp)
		assert_eq(m.level, 50)
		assert_true(m.shop_bought, "never traded")
		assert_eq(m.temper, str(o.grants[0].temper))
		assert_true(ResourceLoader.exists(str(o.icon)), str(o.icon))
		assert_eq(int(o.limit.n), 1)

func test_discounts_are_true() -> void:
	var n: int = 0
	for o: Dictionary in ShopCatalog.offers():
		if o.has("discount_pct"):
			n += 1
			assert_eq(int(o.discount_pct), ShopCatalog.true_discount(o), str(o.id))
	assert_gt(n, 10)
	assert_eq(ShopCatalog.true_discount(ShopCatalog.offer("rg_champion_bundle")), 69)
	var bad: Dictionary = ShopCatalog.offer("rg_deal_mon").duplicate(true)
	bad["discount_pct"] = 60
	bad["badge"] = "cheapest"
	var errs: Array[String] = ShopValidator.check([bad] as Array[Dictionary])
	assert_true(errs.any(func(e: String) -> bool: return e.contains("discount_pct 60 is not true")), str(errs))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("badge must be")), str(errs))

func test_validator_checks_bonus_and_rotation() -> void:
	var t: Dictionary = ShopCatalog.offer("rg_glass_1000").duplicate(true)
	t.grants[0].n = 1200
	var w: Dictionary = ShopCatalog.offer("rg_week_bond").duplicate(true)
	w.rotation = {"per": "week", "index": 4, "cycle": 4}
	w.erase("limit")
	var errs: Array[String] = ShopValidator.check([t, w] as Array[Dictionary])
	assert_true(errs.any(func(e: String) -> bool: return e.contains("base plus bonus")), str(errs))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("rotation is")), str(errs))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("weekly limit")), str(errs))

func test_deals_rotate_by_the_date() -> void:
	var mon: Dictionary = ShopCatalog.offer("rg_deal_mon")
	var tue: Dictionary = ShopCatalog.offer("rg_deal_tue")
	assert_eq(ShopCatalog.weekday_of(ShopCatalog.shop_day(MONDAY_NOON)), 0)
	assert_true(ShopCatalog.deal_active(mon, MONDAY_NOON))
	assert_false(ShopCatalog.deal_active(tue, MONDAY_NOON))
	assert_true(ShopCatalog.deal_active(tue, MONDAY_NOON + 86400))
	# Monday ends at Berlin midnight, 23:00 UTC in winter.
	assert_eq(ShopCatalog.deal_ends_at(mon, MONDAY_NOON), MONDAY_NOON + 11 * 3600)
	var weekly: Array[String] = []
	for o: Dictionary in ShopCatalog.offers():
		if o.has("rotation") and str(o.rotation.per) == "week" and ShopCatalog.deal_active(o, MONDAY_NOON):
			weekly.append(str(o.id))
			assert_eq(ShopCatalog.deal_ends_at(o, MONDAY_NOON), MONDAY_NOON + 6 * 86400 + 11 * 3600, "ends Sunday 24:00")
			assert_true(ShopCatalog.deal_active(o, MONDAY_NOON + 6 * 86400), "still on Sunday")
	assert_eq(weekly.size(), 1, "exactly one weekly deal")
	assert_eq(ShopCatalog.rotation_line(mon), "On sale every Monday.")
	assert_eq(ShopCatalog.berlin_offset(1784894400), 7200, "summer time in July")

func test_local_server_refuses_deals_off_their_day() -> void:
	var off: int = 0
	for o: Dictionary in ShopCatalog.offers():
		if o.has("rotation") and not ShopCatalog.deal_active(o, s.now()):
			assert_eq(shop.offer_block(s.me(), o, null), "not_now", str(o.id))
			off += 1
	assert_eq(off, 9, "7 daily + 4 weekly deals, 2 on sale")
	assert_eq((_call("shop_extras").deals as Array).size(), 2)

func test_featured_and_badges() -> void:
	var featured: Array[String] = []
	for o: Dictionary in ShopCatalog.offers():
		if bool(o.get("featured", false)):
			featured.append(str(o.id))
		if o.has("badge"):
			assert_true(str(o.badge) in ShopCatalog.BADGES)
			assert_ne(str(o.badge), "bestseller", "no sales counts back a bestseller claim")
	assert_eq(featured[0], "rg_starter", "the first featured offer is the banner")
	assert_between(featured.size(), 4, 6)

func test_pass_is_the_premium_row_and_on_sale() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_pass")
	assert_true(bool(o.ready))
	assert_string_contains(str(o.desc), "Premium row of the 30-tier Pass")
	assert_string_contains(str(o.desc), "cancel any time")
	assert_lte(str(o.desc).length(), 200, "fits the store description")
