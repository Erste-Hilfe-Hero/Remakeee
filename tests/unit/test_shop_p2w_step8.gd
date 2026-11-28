extends GutTest
## Pay-to-win step 8 (release 1.3.2, Ali 27 Nov 2026: "Noch weitere pay2win Aspekte"): Victory Mend,
## Coin Seal, Wild Purse, Gleam Lens, Rarity Compass, Training Seal, Kinship Bell, Bond Head Start IV-V,
## Crit Seal IV-V, Merchant Discount II, Growth Seal II. Server rules: tools/online/sql_test/test_shop_p2w_step8.sql.

const IDS: Array[String] = ["rg_victory_mend_1", "rg_victory_mend_2", "rg_victory_mend_3", "rg_coin_seal_1",
	"rg_coin_seal_2", "rg_coin_seal_3", "rg_wild_purse", "rg_gleam_lens", "rg_rare_compass", "rg_spark_seal",
	"rg_kinship_bell", "rg_bond_edge_4", "rg_bond_edge_5", "rg_crit_seal_4", "rg_crit_seal_5",
	"rg_merchant_discount_2", "rg_growth_plus_2"]
## Every step 8 unlock at its top.
const ALL: Dictionary = {"victory_mend": 3, "coin_seal": 3, "wild_purse": 1, "gleam_lens": 1, "rare_compass": 1,
	"spark_seal": 1, "kinship_bell": 1, "bond_edge": 5, "crit_seal": 5, "merchant_discount": 1,
	"merchant_discount_2": 1, "growth_plus": 1, "growth_plus_2": 1}

var _state: Dictionary
var _boosts: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_state = Billing.state
	_boosts = GameState.shop_boosts
	GameState.shop_boosts = {}
	Billing.state = {"unlocks": {}}

func after_each() -> void:
	Billing.state = _state
	GameState.shop_boosts = _boosts

func test_offers_are_valid_riftglass_only_and_new() -> void:
	var mine: Array[Dictionary] = []
	for id: String in IDS:
		var o: Dictionary = ShopCatalog.offer(id)
		assert_false(o.is_empty(), id)
		mine.append(o)
		assert_true(bool(o.ready), id)
		assert_true(bool(o.get("rg_only", false)), id + " is Riftglass only")
		assert_eq(str(o.kind), "advantage", id)
		assert_eq(str(o.store_type), "non_consumable", id)
		assert_eq(int(o.eur_cents), int(o.rg_price) - 1, id + " shows the euro equivalent")
		assert_gte(int(o.min_band), 13, id)
		assert_eq(str(o.get("badge", "")), "new", id)
		assert_eq(int(o.limit.n), 1, id)
		assert_eq(str(o.league_scope), "open" if id.begins_with("rg_crit_seal") else "none", id)
		assert_false(str(o.get("explain", "")).is_empty(), id + " has an explanation")
	assert_eq(ShopValidator.check(mine), [] as Array[String])
	assert_eq(ShopCatalog.validate(), [] as Array[String])
	assert_eq(int(ShopCatalog.data().catalog_version), 40)
	var products: Array = JSON.parse_string(FileAccess.get_file_as_string("res://store/products.json")).products
	for p: Dictionary in products:
		assert_false(str(p.offer) in IDS, "no store product for " + str(p.offer))

func test_prices_and_tier_order() -> void:
	var prices: Dictionary = {"rg_victory_mend_1": 500, "rg_victory_mend_2": 1000, "rg_victory_mend_3": 1500,
		"rg_coin_seal_1": 500, "rg_coin_seal_2": 1000, "rg_coin_seal_3": 1500, "rg_wild_purse": 800,
		"rg_gleam_lens": 2000, "rg_rare_compass": 1500, "rg_spark_seal": 1000, "rg_kinship_bell": 800,
		"rg_bond_edge_4": 2000, "rg_bond_edge_5": 2500, "rg_crit_seal_4": 2000, "rg_crit_seal_5": 2500,
		"rg_merchant_discount_2": 1000, "rg_growth_plus_2": 2500}
	for id: String in prices:
		assert_eq(int(ShopCatalog.offer(id).rg_price), int(prices[id]), id)
	for t: int in [1, 2, 3]:
		assert_eq(str(ShopCatalog.offer("rg_victory_mend_%d" % t).requires), "tier:victory_mend:%d" % (t - 1))
		assert_eq(str(ShopCatalog.offer("rg_coin_seal_%d" % t).requires), "tier:coin_seal:%d" % (t - 1))
	for t: int in [4, 5]:
		assert_eq(str(ShopCatalog.offer("rg_bond_edge_%d" % t).requires), "tier:bond_edge:%d" % (t - 1))
		assert_eq(str(ShopCatalog.offer("rg_crit_seal_%d" % t).requires), "tier:crit_seal:%d" % (t - 1))
	assert_eq(str(ShopCatalog.offer("rg_merchant_discount_2").requires), "tier:merchant_discount:1")
	assert_eq(str(ShopCatalog.offer("rg_growth_plus_2").requires), "tier:growth_plus:1")

func test_texts_never_name_the_removed_rules() -> void:
	for id: String in IDS:
		var o: Dictionary = ShopCatalog.offer(id)
		var text: String = (str(o.name) + " " + str(o.desc) + " " + str(o.explain)).to_lower()
		for w: String in ["ring cap", "difficulty", "rift-born", "free", "countdown", "random"]:
			assert_false(text.contains(w), "%s says %s" % [id, w])

func test_victory_mend_heals_the_standing_team_by_tier() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 20)
	var b: Spirling = BattleFixtures.make("Zephlet", 20)
	var c: Spirling = BattleFixtures.make("Mirkmole", 20)
	a.hp = 1
	b.hp = 0
	c.hp = c.max_hp() - 1
	var team: Array = [a, b, c]
	assert_eq(ShopEffects.victory_mend(team), 0, "nothing without the unlock")
	assert_eq(a.hp, 1)
	for t: int in [1, 2, 3]:
		Billing.state = {"unlocks": {"victory_mend": t}}
		a.hp = 1
		assert_eq(ShopEffects.victory_mend(team), 10 * t)
		assert_eq(a.hp, 1 + a.max_hp() * 10 * t / 100, "tier %d" % t)
	assert_eq(b.hp, 0, "a knocked-out Spirling stays down")
	assert_eq(c.hp, c.max_hp(), "never over the maximum")
	Billing.state = {"unlocks": {"victory_mend": 9}}
	assert_eq(ShopEffects.victory_mend_tier(), 3, "clamped to the top tier")

func test_coin_seal_multiplies_story_trainer_coins() -> void:
	assert_almost_eq(ShopEffects.coin_seal_mult(), 1.0, 0.0001)
	for pair: Array in [[1, 1.25], [2, 1.5], [3, 2.0], [7, 2.0]]:
		Billing.state = {"unlocks": {"coin_seal": pair[0]}}
		assert_almost_eq(ShopEffects.coin_seal_mult(), float(pair[1]), 0.0001, "tier %d" % pair[0])

func test_wild_purse_pays_by_the_highest_foe_ring() -> void:
	var foes: Array = [BattleFixtures.make("Zephlet", 12), BattleFixtures.make("Kindlop", 30)]
	assert_eq(ShopEffects.wild_purse_coins(foes), 0)
	Billing.state = {"unlocks": {"wild_purse": 1}}
	assert_eq(ShopEffects.wild_purse_coins(foes), 600)
	assert_eq(ShopEffects.wild_purse_coins([BattleFixtures.make("Zephlet", 5)]), 100)

func test_gleam_lens_and_rarity_compass_multiply_with_the_scents() -> void:
	assert_eq(ShopEffects.gleam_mult(), 1.0)
	assert_eq(ShopEffects.rare_mult(), 1.0)
	Billing.state = {"unlocks": {"gleam_lens": 1, "rare_compass": 1}}
	assert_almost_eq(ShopEffects.gleam_mult(), 2.0, 0.0001)
	assert_almost_eq(ShopEffects.rare_mult(), 1.5, 0.0001)
	GameState.shop_boosts = {"gleam": {"mult": 10.0, "left": 100}, "rare": {"mult": 2.0, "left": 100}}
	assert_almost_eq(ShopEffects.gleam_mult(), 20.0, 0.0001, "on top of a Shimmer Scent")
	assert_almost_eq(ShopEffects.rare_mult(), 3.0, 0.0001, "on top of a Lure Scent")

func test_rarity_compass_raises_only_rarer_kinds() -> void:
	var rare: Dictionary = {}
	var common: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if rare.is_empty() and sd.rarity != "common":
			rare = {"species": sd.species_name, "weight": 10}
		if common.is_empty() and sd.rarity == "common":
			common = {"species": sd.species_name, "weight": 10}
	var none: Array[int] = []
	var before: int = EncounterTable.weight_of(rare, none)
	var plain: int = EncounterTable.weight_of(common, none)
	Billing.state = {"unlocks": {"rare_compass": 1}}
	assert_eq(EncounterTable.weight_of(rare, none), roundi(before * 1.5))
	assert_eq(EncounterTable.weight_of(common, none), plain)

func test_training_seal_and_kinship_bell() -> void:
	assert_eq(ShopEffects.spark_seal_mult(), 1.0)
	assert_eq(ShopEffects.kinship_win_mult(), 1)
	Billing.state = {"unlocks": {"spark_seal": 1, "kinship_bell": 1}}
	assert_almost_eq(ShopEffects.spark_seal_mult(), 2.0, 0.0001)
	assert_eq(ShopEffects.kinship_win_mult(), 2)
	var s: Spirling = BattleFixtures.make("Kindlop", 10)
	var k0: int = s.kinship
	Kinship.after_battle([s], [s], true, 5)
	var plain: int = s.kinship - k0
	assert_gt(plain, 0)
	k0 = s.kinship
	Kinship.after_battle([s], [s], true, 5, ShopEffects.kinship_win_mult())
	assert_eq(s.kinship - k0, plain * 2, "double Kinship")
	k0 = s.kinship
	Kinship.after_battle([s], [s], false, 5, 2)
	assert_eq(s.kinship, k0, "a lost battle gives none")

func test_merchant_discount_two() -> void:
	assert_eq(ShopEffects.merchant_price(1000), 1000)
	Billing.state = {"unlocks": {"merchant_discount": 1}}
	assert_eq(ShopEffects.merchant_price(1000), 800)
	Billing.state = {"unlocks": {"merchant_discount": 1, "merchant_discount_2": 1}}
	assert_eq(ShopEffects.merchant_price(1000), 600)
	assert_eq(ShopEffects.merchant_price(1), 1, "never below 1")

func test_growth_seal_two_doubles_growth_and_counts_as_power() -> void:
	var party: Array[Spirling] = GameState.party.duplicate()
	GameState.party.clear()
	Billing.state = {"unlocks": {"growth_plus": 1}}
	assert_almost_eq(ShopEffects.growth_mult(), 1.5, 0.0001)
	assert_eq(ShopEffects.account_power(), 50)
	Billing.state = {"unlocks": {"growth_plus": 1, "growth_plus_2": 1}}
	assert_almost_eq(ShopEffects.growth_mult(), 2.0, 0.0001)
	assert_eq(ShopEffects.account_power(), 100)
	GameState.party.assign(party)

func test_top_tiers_of_bond_head_start_and_crit_seal() -> void:
	Billing.state = {"unlocks": {"bond_edge": 4, "crit_seal": 4}}
	assert_almost_eq(ShopEffects.bond_edge(), 0.4, 0.0001)
	assert_eq(ShopEffects.amulet_tiers(), [4, 0, 0] as Array[int])
	Billing.state = {"unlocks": {"bond_edge": 5, "crit_seal": 5}}
	assert_almost_eq(ShopEffects.bond_edge(), 0.5, 0.0001)
	assert_almost_eq(ShopEffects.crit_mult(1.0, 5) * DamageCalc.CRIT_CHANCE, DamageCalc.CRIT_CHANCE + 0.25, 0.0001)
	for ctx: String in ["story", "raid", "league_open"]:
		assert_eq(ShopEffects.amulets_for(ctx), [5, 0, 0] as Array[int], ctx)
	for ctx: String in ["league_fair", "echo"]:
		assert_eq(ShopEffects.amulets_for(ctx), [0, 0, 0] as Array[int], ctx + " never gets bought advantages")
	var snap: Dictionary = {"amulets": [9, 0, 0]}
	assert_eq(ShopEffects.amulet_row(snap.amulets), [5, 0, 0], "replays clamp to Crit Seal V")

func test_power_note_never_names_coins_or_healing() -> void:
	var u: Dictionary = {"band": 18, "unlocks": {}}
	for k: String in ShopEffects.POWER_TIER_KINDS:
		u.unlocks[k] = ShopEffects.seal_max(k)
	Billing.state = u
	assert_eq(ShopEffects.next_power_line(), "", "Victory Mend and the Coin Seal are no battle power")

func test_local_server_sells_the_tiers_in_order() -> void:
	var be := LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	be.rng.seed = 1
	var shop: LocalShop = LocalShop.of(be)
	be.switch_user("ann")
	be.call_fn("hello", {"p_version": 1})
	be.call_fn("shop_set_age", {"p_year": 1990, "p_month": 3})
	shop._ledger_add(be.me(), 20000, "store", "test")
	var buy := func(id: String) -> Dictionary:
		return be.call_fn("shop_buy", {"p_offer": id, "p_expected_price": int(ShopCatalog.offer(id).rg_price)}).data
	assert_eq(str(buy.call("rg_victory_mend_2").error), "not_yet", "tier II needs tier I")
	assert_true(bool(buy.call("rg_victory_mend_1").ok))
	assert_true(bool(buy.call("rg_victory_mend_2").ok))
	assert_eq(int(shop._shop(be.me()).unlocks.victory_mend), 2)
	assert_eq(str(buy.call("rg_growth_plus_2").error), "not_yet", "Growth Seal II needs the Growth Seal")
	assert_true(bool(buy.call("rg_growth_plus").ok))
	assert_true(bool(buy.call("rg_growth_plus_2").ok))
	assert_true(bool(buy.call("rg_wild_purse").ok))
	assert_eq(str(buy.call("rg_wild_purse").error), "offer_limit", "once per account")
	shop._shop(be.me()).unlocks["crit_seal"] = 5
	assert_eq(be._league_expect({"seed": 1, "teams": [[], []], "league": LeagueRules.FAIR, "user": be.me()}).amulets, [0, 0, 0])
	assert_eq(be._league_expect({"seed": 1, "teams": [[], []], "league": LeagueRules.OPEN, "user": be.me()}).amulets, [5, 0, 0])

func test_act_sim_plays_the_same_with_every_purchase() -> void:
	var st: String = str(ActSim.route().starters[0])
	Billing.state = {"unlocks": {}}
	var plain: String = JSON.stringify(ActSim.run(st, 2, 77))
	var all: Dictionary = ALL.duplicate()
	for k: String in ["power_seal", "guard_seal", "speed_seal"]:
		all[k] = ShopEffects.seal_max(k)
	Billing.state = {"unlocks": all, "pass_active": true}
	assert_eq(JSON.stringify(ActSim.run(st, 2, 77)), plain, "the balance sim never sees purchases")
