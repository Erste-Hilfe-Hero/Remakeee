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
