extends GutTest
## Shop catalog rules (items 4021-4024, 4217-4223, 4278, 4323, 4324): data/shop.json is complete,
## nothing is random, prices fit the tiers and Riftglass packs, 2/3 of the offers are advantages.

func before_all() -> void:
	Database.load_all()

func test_catalog_is_valid() -> void:
	var errs: Array[String] = ShopCatalog.validate()
	assert_eq(errs, [] as Array[String], "\n".join(errs))

func test_two_thirds_are_advantages() -> void:
	var all: int = ShopCatalog.offers().size()
	var adv: int = 0
	for o: Dictionary in ShopCatalog.offers():
		if ShopCatalog.is_advantage(o):
			adv += 1
	assert_gt(all, 100)
	assert_almost_eq(float(adv), all * 2.0 / 3.0, 2.0, "Ali: 2/3 of the shop gives an advantage (%d of %d)" % [adv, all])

func test_validator_finds_random_content() -> void:
	var bad: Dictionary = ShopCatalog.offer("rg_ring_tonic").duplicate(true)
	bad["grants"] = [{"t": "item", "id": "rg_ring_tonic", "n": 1, "chance": 0.5}]
	var errs: Array[String] = ShopValidator.check([bad] as Array[Dictionary])
	assert_true(errs.any(func(e: String) -> bool: return "random" in e), str(errs))
	bad = ShopCatalog.offer("rg_jacket_moss").duplicate(true)
	bad["stats"] = {"speed": 5}
	errs = ShopValidator.check([bad] as Array[Dictionary])
	assert_true(errs.any(func(e: String) -> bool: return "value fields" in e), "cosmetics have no values: %s" % str(errs))

func test_validator_bans_spirlings() -> void:
	Database.load_all()
	var some: String = str(Database.spirlings.keys()[0])
	var bad: Dictionary = ShopCatalog.offer("rg_ring_tonic").duplicate(true)
	bad["grants"] = [{"t": "item", "id": some, "n": 1}]
	var errs: Array[String] = ShopValidator.check([bad] as Array[Dictionary])
	assert_true(errs.any(func(e: String) -> bool: return "never sold" in e), str(errs))

func test_validator_finds_bad_prices() -> void:
	var bad: Dictionary = ShopCatalog.offer("rg_ring_tonic").duplicate(true)
	bad["rg_price"] = 150
	assert_false(ShopValidator.check([bad] as Array[Dictionary]).is_empty(), "Riftglass prices are multiples of 100")
	bad = ShopCatalog.offer("rg_ring_tonic").duplicate(true)
	bad["eur_cents"] = 250
	assert_false(ShopValidator.check([bad] as Array[Dictionary]).is_empty(), "store tiers end in 99")
	bad = ShopCatalog.offer("rg_ring_tonic").duplicate(true)
	bad["min_band"] = 0
	assert_false(ShopValidator.check([bad] as Array[Dictionary]).is_empty(), "never under 13")

func test_riftglass_packs_have_fixed_rate() -> void:
	var packs: Dictionary = {}
	for o: Dictionary in ShopCatalog.offers():
		if o.kind == "currency":
			packs[int(o.grants[0].n)] = int(o.eur_cents)
	assert_eq(packs, {100: 99, 200: 199, 500: 499, 1000: 999, 2000: 1999, 5000: 4999, 10000: 9999}, "no bonus amounts (item 4218)")

func test_euro_hint_rounds_down() -> void:
	assert_eq(ShopCatalog.euro_cents(100), 99)
	assert_eq(ShopCatalog.euro_cents(300), 297)
	assert_eq(ShopCatalog.euro_cents(150), 148, "148.5 cents round down")
	Loc.set_language("de")
	assert_eq(ShopCatalog.rg_text(300), "300 Rissglas (≈ 2,97 €)")
	Loc.set_language("en")
	assert_eq(ShopCatalog.rg_text(300), "300 Riftglass (≈ €2.97)")

func test_every_offer_has_german_text() -> void:
	Loc.set_language("de")
	for o: Dictionary in ShopCatalog.offers():
		assert_ne(Loc.t(str(o.name)), str(o.name), "German name for %s" % o.id)
		assert_ne(Loc.t(str(o.desc)), str(o.desc), "German text for %s" % o.id)
	Loc.set_language("en")

func test_shop_goods_never_at_merchants() -> void:
	# Shop goods carry the rg_ prefix and have no coin price, so merchants cannot list them (item 4968).
	for id: String in Database.items:
		if id.begins_with("rg_"):
			assert_false(Database.items[id].has("price"), "%s has no coin price" % id)
	for o: Dictionary in ShopCatalog.offers():
		assert_true(str(o.id).begins_with("rg_"))

func test_no_purchase_prompts() -> void:
	var banned: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop_banned_phrases.json"))
	var words: Array = banned.de + banned.en
	for o: Dictionary in ShopCatalog.offers():
		for text: String in [str(o.name), str(o.desc), Loc.t(str(o.name))]:
			for w: Variant in words:
				assert_false(str(w) in text.to_lower(), "'%s' in %s" % [w, o.id])

func test_products_file_matches_catalog() -> void:
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://store/products.json"))
	assert_true(p is Dictionary)
	assert_eq((p.products as Array).size(), ShopCatalog.offers().size(), "run tools/shop/build_offers_sql.py")
	var sub: int = 0
	for row: Dictionary in p.products:
		if row.apple_type == "AUTO_RENEWABLE_SUBSCRIPTION":
			sub += 1
	assert_eq(sub, 1, "one subscription: the Wayfarer Pass")
