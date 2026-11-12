extends GutTest
## Pay-to-win step 5 (plan section 2 "Bindung und Sammeln" plus point 15): Lure Scent I-III,
## Shimmer Scent, Bond Head Start I-III, Second Try Charm, Unfurl Spark, Grand Tonic.
## Values come from data/shop.json and data/items.json.

const IDS: Array[String] = ["rg_lure_scent_1", "rg_lure_scent_2", "rg_lure_scent_3", "rg_shimmer_scent",
	"rg_bond_edge_1", "rg_bond_edge_2", "rg_bond_edge_3", "rg_bond_retry", "rg_unfurl_spark", "rg_grand_tonic"]

var _state: Dictionary
var _boosts: Dictionary
var _inv: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_state = Billing.state.duplicate(true)
	_boosts = GameState.shop_boosts.duplicate(true)
	_inv = GameState.inventory.duplicate(true)
	GameState.shop_boosts = {}

func after_each() -> void:
	Billing.state = _state
	GameState.shop_boosts = _boosts
	GameState.inventory = _inv

func test_offers_are_fixed_riftglass_only_and_for_13_plus() -> void:
	var mine: Array[Dictionary] = []
	for id: String in IDS:
		var o: Dictionary = ShopCatalog.offer(id)
		assert_false(o.is_empty(), id)
		assert_eq(str(o.kind), "advantage", id)
		assert_true(bool(o.rg_only), id)
		assert_eq(int(o.min_band), 13, id)
		assert_eq(int(o.eur_cents), int(o.rg_price) - 1, "euro equivalent shown for " + id)
		mine.append(o)
	for t: int in 3:
		var o: Dictionary = ShopCatalog.offer("rg_bond_edge_%d" % (t + 1))
		assert_eq(str(o.requires), "tier:bond_edge:%d" % t, "tiers in order")
		assert_eq(int(o.limit.n), 1, "once per account")
		assert_eq(str(o.league_scope), "none", "bonding is story only")
	assert_eq(ShopValidator.check(mine), [] as Array[String])
	var products: Array = JSON.parse_string(FileAccess.get_file_as_string("res://store/products.json")).products
	for p: Dictionary in products:
		assert_false(str(p.offer) in IDS, "no store product for " + str(p.offer))

func test_lure_scent_multiplies_rarer_kinds_only() -> void:
	var rare: Dictionary = {"species": "Mossling", "weight": 10}
	var common: Dictionary = {"species": "Zippit", "weight": 10}
	assert_eq(Database.species("Mossling").rarity, "uncommon")
	assert_eq(Database.species("Zippit").rarity, "common")
	var plain_rare: int = EncounterTable.weight_of(rare, [] as Array[int])
	var plain_common: int = EncounterTable.weight_of(common, [] as Array[int])
	GameState.inventory["rg_lure_scent_3"] = 1
	assert_eq(ShopEffects.start_boost("rg_lure_scent_3"), "Works for the next 100 steps.")
	assert_eq(ShopEffects.rare_mult(), 5.0)
	assert_eq(EncounterTable.weight_of(rare, [] as Array[int]), plain_rare * 5)
	assert_eq(EncounterTable.weight_of(common, [] as Array[int]), plain_common, "common kinds stay")
	assert_eq(ShopEffects.boost_lines(), ["Lure Scent x5: 100 steps left"] as Array[String])
	for i: int in 99:
		assert_eq(ShopEffects.step_kinds_done(), [] as Array[String])
	assert_eq(ShopEffects.step_kinds_done(), ["rare"] as Array[String])
	assert_eq(ShopEffects.rare_mult(), 1.0)
	assert_eq(str(ShopEffects.STEP_END_NOTES["rare"]), "The Lure Scent fades.")

func test_shimmer_scent_gives_ten_times_the_gleam_chance() -> void:
	assert_almost_eq(GleamRules.chance(0, 10.0), 10.0 / GleamRules.one_in(), 1e-12)
	assert_almost_eq(GleamRules.chance(0), 1.0 / GleamRules.one_in(), 1e-12, "plain chance unchanged")
	assert_eq(ShopEffects.gleam_mult(), 1.0)
	GameState.inventory["rg_shimmer_scent"] = 1
	ShopEffects.start_boost("rg_shimmer_scent")
	assert_eq(ShopEffects.gleam_mult(), 10.0)
	ShopEffects.battle_done()
	assert_eq(ShopEffects.boost_left("gleam"), 100, "battles do not use up steps")

func test_bond_head_start_tiers_come_from_data() -> void:
	assert_eq(ShopEffects.seal_max("bond_edge"), 3)
	Billing.state = {"unlocks": {}}
	assert_eq(ShopEffects.bond_edge(), 0.0)
	var before: int = ShopEffects.account_power()
	Billing.state = {"unlocks": {"bond_edge": 9}}
	assert_eq(ShopEffects.bond_edge_tier(), 3, "clamped to the top tier")
	assert_almost_eq(ShopEffects.bond_edge(), 0.3, 0.0001)
	assert_eq(ShopEffects.account_power(), before + 30)

func _bond_once(seed_value: int, timing: float, edge: float, item: String = "") -> bool:
	var foe := BattleFixtures.make("Zephlet", 5)
	foe.hp = 1
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [foe] as Array[Spirling], true, seed_value)
	m.bond_edge = edge
	if not item.is_empty():
		m.inventory[item] = 1
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_bond(BattleModel.Side.PLAYER, timing, item), BattleAction.make_rest(BattleModel.Side.FOE))
	return bool(BattleFixtures.first_of(ev, BattleEvent.Type.BOND_RESULT).data.success)

func test_bond_head_start_counts_as_better_timing() -> void:
	for seed_value: int in 60:
		assert_eq(_bond_once(seed_value, 0.5, 0.5), _bond_once(seed_value, 1.0, 0.0), "seed %d" % seed_value)
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Zephlet", 5)] as Array[Spirling])
	m.bond_edge = 0.2
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "")
	assert_almost_eq(float(snap.bond_edge), 0.2, 0.0001, "replays carry it")
	assert_almost_eq(BattleReplay.build_model(snap).bond_edge, 0.2, 0.0001)
	snap.bond_edge = 5.0
	assert_almost_eq(BattleReplay.build_model(snap).bond_edge, 0.3, 0.0001, "clamped to the top tier")

func test_second_try_charm_only_adds_bonds() -> void:
	var extra: int = 0
	for seed_value: int in 200:
		var plain: bool = _bond_once(seed_value, 1.0, 0.0)
		var charm: bool = _bond_once(seed_value, 1.0, 0.0, "rg_bond_retry")
		if plain:
			assert_true(charm, "a bond that works alone still works with the charm (seed %d)" % seed_value)
		elif charm:
			extra += 1
	assert_gt(extra, 0, "the second try saves some failed bonds")
	assert_has(BattleScene.bond_charms({"rg_bond_retry": 1}), "rg_bond_retry", "offered in the bond menu")

func test_unfurl_spark_skips_the_ring_but_not_items() -> void:
	var s := Spirling.new(Database.species("Mossling"), 3)
	GameState.inventory["rg_unfurl_spark"] = 1
	assert_string_contains(GameState.use_item_outside_battle("rg_unfurl_spark", s), "Thornback")
	assert_eq(s.data.species_name, "Thornback")
	assert_eq(s.level, 3, "Rings stay")
	assert_eq(GameState.item_count("rg_unfurl_spark"), 0, "used up")
	var k := Spirling.new(Database.species("Kelpup"), 3)
	GameState.inventory["rg_unfurl_spark"] = 1
	assert_eq(GameState.use_item_outside_battle("rg_unfurl_spark", k), "", "item forms need their item")
	assert_eq(GameState.item_count("rg_unfurl_spark"), 1, "kept when it does nothing")

func test_grand_tonic_heals_fully_without_a_battle_limit() -> void:
	var it: Dictionary = Database.item("rg_grand_tonic")
	assert_true(bool(it.battle))
	assert_eq(float(it.heal_frac), 1.0)
	assert_false(it.has("per_battle"), "no limit per battle")
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Zephlet", 5)] as Array[Spirling])
	m.items_used[0]["rg_grand_tonic"] = 50
	assert_true(m.item_left_this_battle(0, "rg_grand_tonic"))
