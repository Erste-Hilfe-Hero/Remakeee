extends GutTest
## Shop advantages in the game (plan area 10, PR 2): keepsakes, Element Prisms, bond charms,
## Spark Shards, the merchant discount and extra storage boxes.

var _state: Dictionary
var _bonus: int
var _boxes: Array

func before_each() -> void:
	_state = Billing.state.duplicate(true)
	_bonus = GameState.storage_box_bonus
	_boxes = GameState.storage_boxes.duplicate(true)

func after_each() -> void:
	Billing.state = _state
	GameState.storage_box_bonus = _bonus
	GameState.storage_boxes = _boxes

func _mon() -> Spirling:
	return Spirling.new(Database.species("Mossling"), 30)

func test_keepsakes_raise_stats() -> void:
	var s: Spirling = _mon()
	var atk: int = s.effective_atk()
	var def: int = s.effective_def()
	var spd: int = s.effective_spd()
	s.held = "rg_riftheart"
	assert_gt(s.effective_atk(), atk, "Riftheart: +15% Might")
	s.held = "rg_glass_shield"
	assert_gt(s.effective_def(), def, "Glass Shield: +15% Guard")
	s.held = "rg_whirl_glass"
	assert_gt(s.effective_spd(), spd, "Whirl Glass: +15% Speed")

func test_core_glass_raises_vigor_and_take_off_clamps() -> void:
	var s: Spirling = _mon()
	var hp: int = s.max_hp()
	GameState.add_item("rg_vigor_glass")
	assert_true(GameState.set_held(s, "rg_vigor_glass"))
	assert_gt(s.max_hp(), hp)
	s.hp = s.max_hp()
	GameState.set_held(s, "")
	assert_eq(s.hp, s.max_hp(), "no Vigor above the cap after taking it off")
	GameState.inventory.erase("rg_vigor_glass")

func test_element_prism_only_boosts_its_element() -> void:
	var user: Spirling = _mon()
	var target: Spirling = _mon()
	var ember: MoveData = Database.move("Cinder Breath")
	var volt: MoveData = Database.move("Arc Bolt")
	var base_e: float = BattleRules.damage_mult(user, target, ember, "")
	var base_v: float = BattleRules.damage_mult(user, target, volt, "")
	user.held = "rg_prism_ember"
	assert_almost_eq(BattleRules.damage_mult(user, target, ember, ""), base_e * 1.2, 0.0001)
	assert_almost_eq(BattleRules.damage_mult(user, target, volt, ""), base_v, 0.0001)

func test_bond_seal_is_certain_and_scent_helps() -> void:
	var foe: Spirling = _mon()
	assert_true(bool(Database.item("rg_bond_seal").get("bond_sure", false)))
	assert_gt(BondCalc.chance(foe, 0.5, float(Database.item("rg_echo_scent").bond_bonus)), BondCalc.chance(foe, 0.5))

func test_bond_seal_bonds_for_sure_in_battle() -> void:
	var theirs: Array[Spirling] = [BattleFixtures.make("Zephlet", 5)]
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], theirs, true, 5)
	m.inventory["rg_bond_seal"] = 1
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_bond(BattleModel.Side.PLAYER, 0.0, "rg_bond_seal"),
		BattleAction.make_rest(BattleModel.Side.FOE))
	assert_true(BattleFixtures.first_of(ev, BattleEvent.Type.BOND_RESULT).data.success, "even with the worst timing")
	assert_eq(int(m.inventory.rg_bond_seal), 0, "used up")

func test_bond_charms_list_kin_charm_first() -> void:
	var bag: Dictionary = {"rg_echo_scent": 2, "tonic": 3, "kin_charm": 1, "rg_bond_seal": 0}
	assert_eq(BattleScene.bond_charms(bag), ["kin_charm", "rg_echo_scent"] as Array[String])

func test_spark_shard_uses_spark_training() -> void:
	assert_eq(int(Database.item("rg_spark_shard").spark), 6)

func test_merchant_discount() -> void:
	Billing.state = {"unlocks": {}}
	assert_eq(ShopEffects.merchant_price(1000), 1000)
	Billing.state = {"unlocks": {"merchant_discount": 1}}
	assert_eq(ShopEffects.merchant_price(1000), 800)
	assert_eq(ShopEffects.merchant_price(1), 1, "never free")

func test_storage_boxes_only_grow() -> void:
	GameState.storage_box_bonus = 0
	Billing.state = {"unlocks": {"storage_box": 2}}
	ShopEffects.apply_unlocks()
	assert_eq(GameState.storage_box_bonus, 2)
	assert_eq(GameState.storage_boxes.size(), GameState.storage_box_count())
	Billing.state = {"unlocks": {}}
	ShopEffects.apply_unlocks()
	assert_eq(GameState.storage_box_bonus, 2, "a box with Spirlings in it is never taken away")

func test_ready_offers_have_working_items() -> void:
	for o: Dictionary in ShopCatalog.offers():
		if not bool(o.get("ready", false)):
			continue
		for g: Dictionary in o.grants:
			if str(g.t) == "item":
				var it: Dictionary = Database.item(str(g.id))
				assert_false(it.is_empty(), "%s grants a real item" % o.id)
				assert_false(it.has("price"), "%s: shop items have no merchant price" % g.id)

func test_receipt_check_goes_to_billing_service() -> void:
	assert_eq(SupabaseBackend.SERVICE_ROUTES.get("shop_verify"), "/billing/v1/verify")

func test_ring_tonics_stop_at_the_cap() -> void:
	var s: Spirling = Spirling.new(Database.species("Mossling"), 10)
	var diff: int = GameState.difficulty
	GameState.difficulty = GameState.Difficulty.TAMER
	GameState.add_item("rg_ring_tonic_5")
	assert_string_contains(GameState.use_item_outside_battle("rg_ring_tonic_5", s), "Ring 15")
	assert_eq(s.level, 15)
	assert_eq(s.xp, Spirling.xp_for_level(15))
	assert_eq(GameState.item_count("rg_ring_tonic_5"), 0, "used up")
	GameState.add_item("rg_ring_elixir")
	GameState.use_item_outside_battle("rg_ring_elixir", s)
	assert_eq(s.level, mini(GameState.level_cap(), Spirling.MAX_LEVEL))
	GameState.add_item("rg_ring_tonic")
	assert_eq(GameState.use_item_outside_battle("rg_ring_tonic", s), "", "nothing above the cap")
	assert_eq(GameState.item_count("rg_ring_tonic"), 1, "kept when it would do nothing")
	GameState.inventory.erase("rg_ring_tonic")
	GameState.difficulty = diff

func test_spark_forge_sets_every_spark_to_top() -> void:
	var s: Spirling = _mon()
	GameState.add_item("rg_spark_forge")
	assert_ne(GameState.use_item_outside_battle("rg_spark_forge", s), "")
	for k: String in Spirling.STAT_KEYS:
		assert_eq(int(s.spark[k]), Spirling.SPARK_MAX)

func test_growth_and_coin_boosts_count_battles() -> void:
	var boosts: Dictionary = GameState.shop_boosts.duplicate(true)
	GameState.shop_boosts = {}
	Billing.state = {}
	GameState.add_item("rg_growth_x2")
	GameState.add_item("rg_growth_x3")
	assert_eq(ShopEffects.start_boost("rg_growth_x3"), "Works for the next 20 battles.")
	assert_eq(ShopEffects.start_boost("rg_growth_x2"), "A stronger boost is still working.")
	assert_eq(GameState.item_count("rg_growth_x2"), 1, "kept")
	assert_almost_eq(ShopEffects.growth_mult(), 3.0, 0.001)
	Billing.state = {"pass_active": true}
	assert_almost_eq(ShopEffects.growth_mult(), 4.5, 0.001, "the pass multiplies")
	for i: int in 20:
		ShopEffects.battle_done()
	assert_almost_eq(ShopEffects.growth_mult(), 1.5, 0.001, "crystal ran out after 20 battles")
	GameState.add_item("rg_coin_boost")
	ShopEffects.start_boost("rg_coin_boost")
	assert_almost_eq(ShopEffects.coin_mult(), 2.0, 0.001)
	assert_eq(ShopEffects.boost_left("coins"), 20)
	GameState.inventory.erase("rg_growth_x2")
	GameState.shop_boosts = boosts

func test_boosts_survive_save_and_load() -> void:
	var boosts: Dictionary = GameState.shop_boosts.duplicate(true)
	GameState.shop_boosts = {"growth": {"mult": 2.0, "left": 7}}
	var d: Dictionary = GameState.to_dict()
	GameState.shop_boosts = {}
	GameState.from_dict(d)
	assert_eq(ShopEffects.boost_left("growth"), 7)
	GameState.shop_boosts = boosts

func test_xp_mult_scales_battle_growth() -> void:
	var a: Array[Spirling] = [BattleFixtures.make("Kindlop", 10)]
	var b: Array[Spirling] = [BattleFixtures.make("Kindlop", 10)]
	var foe1: Array[Spirling] = [BattleFixtures.make("Zephlet", 10)]
	var foe2: Array[Spirling] = [BattleFixtures.make("Zephlet", 10)]
	var m1: BattleModel = BattleFixtures.model(a, foe1, true, 3)
	var m2: BattleModel = BattleFixtures.model(b, foe2, true, 3)
	m2.xp_mult = 2.0
	m1.participants.append(a[0])
	m2.participants.append(b[0])
	m1._award_xp(foe1[0])
	m2._award_xp(foe2[0])
	assert_gt(b[0].xp, a[0].xp)

func test_rift_breath_brings_back_a_defeated_spirling_once() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 10), BattleFixtures.make("Mossling", 10)]
	var m: BattleModel = BattleFixtures.model(mine, [BattleFixtures.make("Zephlet", 5)] as Array[Spirling], true, 5)
	m.inventory["rg_rift_breath"] = 2
	mine[1].hp = 0
	mine[1].status = "burn"
	var on_standing := BattleAction.make_item(BattleModel.Side.PLAYER, "rg_rift_breath", 0)
	assert_false(m.is_legal(on_standing), "only for a defeated Spirling")
	var a := BattleAction.make_item(BattleModel.Side.PLAYER, "rg_rift_breath", 1)
	assert_true(m.is_legal(a))
	m.submit_turn(a, BattleAction.make_rest(BattleModel.Side.FOE))
	assert_eq(mine[1].hp, ceili(mine[1].max_hp() * 0.5))
	assert_eq(mine[1].status, "")
	assert_eq(int(m.inventory.rg_rift_breath), 1)
	mine[1].hp = 0
	assert_false(m.is_legal(a), "one per battle")

func test_great_rift_breath_and_glass_tonic() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 10), BattleFixtures.make("Mossling", 10)]
	var m: BattleModel = BattleFixtures.model(mine, [BattleFixtures.make("Zephlet", 5)] as Array[Spirling], true, 5)
	m.inventory["rg_rift_breath_full"] = 1
	m.inventory["rg_glass_tonic"] = 3
	mine[1].hp = 0
	mine[1].energy = 0
	m.submit_turn(BattleAction.make_item(BattleModel.Side.PLAYER, "rg_rift_breath_full", 1), BattleAction.make_rest(BattleModel.Side.FOE))
	assert_eq(mine[1].hp, mine[1].max_hp())
	assert_eq(mine[1].energy, m.max_energy())
	var tonic := BattleAction.make_item(BattleModel.Side.PLAYER, "rg_glass_tonic", 0)
	for i: int in 2:
		mine[0].hp = 1
		assert_true(m.is_legal(tonic))
		m.submit_turn(tonic, BattleAction.make_rest(BattleModel.Side.FOE))
		assert_eq(mine[0].hp, mine[0].max_hp(), "all Vigor")
	assert_false(m.is_legal(tonic), "two per battle")
	assert_false(BattleModel.is_revive_item("rg_glass_tonic"))
