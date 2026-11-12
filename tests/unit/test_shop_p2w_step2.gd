extends GutTest
## Pay-to-win step 2 (Ali, 11 Nov 2026): Spirlings for sale with fixed values, bond lures in four
## tiers, the Seal Set. Plan points 7, 22, 61, 69, 70, 78, 79.

func before_all() -> void:
	Database.load_all()

func test_every_ancient_spirling_is_for_sale_once() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		if sd.rarity != "ancient":
			continue
		var found: Dictionary = {}
		for o: Dictionary in ShopCatalog.offers():
			for g: Variant in o.grants:
				if str((g as Dictionary).get("t", "")) == "spirling" and str(g.species) == sd.species_name:
					found = o
		assert_false(found.is_empty(), "%s is for sale" % sd.species_name)
		assert_eq(int(found.get("limit", {}).get("n", 0)), 1, "once per account")
		assert_eq(str(found.get("store_type", "")), "non_consumable")
		assert_false(found.has("rg_only"), "a store product, listed in store/products.json")

func test_bought_spirling_has_fixed_top_values() -> void:
	var g: Dictionary = ShopCatalog.offer("rg_spirling_velahra").grants[0]
	var a: Spirling = ShopEffects.bought_spirling(g)
	var b: Spirling = ShopEffects.bought_spirling(g)
	assert_eq(a.level, 40)
	assert_eq(a.data.species_name, "Velahra")
	assert_true(a.shop_bought)
	for key: String in Spirling.STAT_KEYS:
		assert_eq(a.spark[key], Spirling.SPARK_MAX, key)
		assert_eq(a.spark[key], b.spark[key], "no chance in the values")
	assert_eq(a.temper, "even", "no random temperament either")
	assert_eq(a.max_hp(), b.max_hp())
	assert_eq(a.atk(), b.atk())
	assert_eq(a.hp, a.max_hp())
	assert_null(ShopEffects.bought_spirling({"t": "spirling", "species": "Nobody", "level": 5}))

func test_bought_spirling_is_saved_and_never_traded() -> void:
	var s: Spirling = ShopEffects.bought_spirling({"t": "spirling", "species": "Vorlucent", "level": 40})
	var back: Spirling = Spirling.from_dict(s.to_dict())
	assert_true(back.shop_bought, "the mark survives a save")
	assert_eq(TradeMenu.mon_why(back), "shop_boosted")
	var wild: Spirling = Spirling.new(Database.species("Vorlucent"), 40)
	assert_false(Spirling.from_dict(wild.to_dict()).shop_bought)

func test_bond_lures_rise_in_four_tiers() -> void:
	var last: float = 0.0
	for n: int in range(1, 5):
		var it: Dictionary = Database.item("rg_bond_lure_%d" % n)
		assert_gt(float(it.get("bond_bonus", 0.0)), last, "tier %d is stronger" % n)
		last = float(it.bond_bonus)
		assert_true(bool(ShopCatalog.offer("rg_bond_lure_%d" % n).get("rg_only", false)))
	assert_has(BattleScene.bond_charms({"rg_bond_lure_4": 1}), "rg_bond_lure_4", "offered in the bond menu")

func test_seal_set_is_every_top_tier_for_less() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_seal_set")
	var counts: Dictionary = {}
	for g: Dictionary in o.grants:
		counts[str(g.id)] = int(counts.get(str(g.id), 0)) + 1
	var single: int = 0
	for kind: String in ShopEffects.SEAL_KINDS:
		assert_eq(counts.get(kind, 0), ShopEffects.seal_max(kind), kind)
		for t: int in range(1, ShopEffects.seal_max(kind) + 1):
			single += int(ShopCatalog.offer("rg_%s_%d" % [kind, t]).rg_price)
	assert_lt(int(o.rg_price), single, "a discount on the tiers one by one")

func test_seal_set_only_without_any_seal() -> void:
	var req: String = str(ShopCatalog.offer("rg_seal_set").requires)
	assert_true(ShopEffects.none_ok(req, func(_k: String) -> int: return 0))
	assert_false(ShopEffects.none_ok(req, func(k: String) -> int: return 1 if k == "speed_seal" else 0))
