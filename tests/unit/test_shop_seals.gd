extends GutTest
## Pay-to-win step 1 (Ali, 10 Nov 2026): Power, Guard and Pace Seals in tiers, Stat Crystals,
## the Growth Seal and the account power number. Values come from data/shop.json.

var _state: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_state = Billing.state.duplicate(true)

func after_each() -> void:
	Billing.state = _state

func test_seal_values_come_from_data() -> void:
	var v: Dictionary = ShopCatalog.data().advantage_values
	assert_eq(v.power_seal, [5, 10, 15, 20, 25, 30, 35])
	assert_eq(v.guard_seal, [5, 10, 15, 20, 25, 30, 35])
	assert_eq(v.speed_seal, [5, 10, 15, 20, 25])
	assert_eq(ShopEffects.seal_max("power_seal"), 7)
	assert_eq(ShopEffects.seal_max("speed_seal"), 5)
	assert_eq(ShopEffects.crystal_cap(), Spirling.SPARK_MAX * 2, "twice the free Spark cap")

func test_seal_math() -> void:
	assert_almost_eq(ShopEffects.seal_damage_mult(0, 0), 1.0, 0.0001)
	assert_almost_eq(ShopEffects.seal_damage_mult(7, 0), 1.35, 0.0001)
	assert_almost_eq(ShopEffects.seal_damage_mult(0, 7), 0.65, 0.0001)
	assert_almost_eq(ShopEffects.seal_damage_mult(3, 2), 1.15 * 0.9, 0.0001)
	assert_almost_eq(ShopEffects.seal_speed_mult(5), 1.25, 0.0001)
	assert_almost_eq(ShopEffects.seal_speed_mult(9), 1.25, 0.0001, "never above the top tier")
	assert_eq(ShopEffects.clamp_tier("guard_seal", 12), 7)
	assert_eq(ShopEffects.clamp_tier("speed_seal", -1), 0)

func test_tiers_pay_only_the_difference() -> void:
	for kind: String in ShopEffects.SEAL_KINDS:
		var total: int = 0
		for t: int in range(1, ShopEffects.seal_max(kind) + 1):
			var o: Dictionary = ShopCatalog.offer("rg_%s_%d" % [kind, t])
			assert_false(o.is_empty(), "%s tier %d" % [kind, t])
			assert_eq(str(o.requires), "tier:%s:%d" % [kind, t - 1])
			assert_eq(int(o.limit.n), 1)
			assert_eq(str(o.league_scope), "open", "says it works in the Open League")
			assert_true(bool(o.get("rg_only", false)), "no new store product")
			assert_eq(int(o.rg_price) % 100, 0)
			total += int(o.rg_price)
		assert_gt(total, 0)
	assert_true(ShopEffects.tier_ok("tier:power_seal:2", 2))
	assert_false(ShopEffects.tier_ok("tier:power_seal:2", 1))
	assert_false(ShopEffects.tier_ok("tier:power_seal:2", 3))

func test_seals_never_in_fair_league() -> void:
	Billing.state = {"unlocks": {"power_seal": 7, "guard_seal": 3, "speed_seal": 5}}
	assert_eq(ShopEffects.seal_tiers(), [7, 3, 5] as Array[int])
	for ctx: String in ["story", "raid", "league_open"]:
		assert_eq(ShopEffects.seals_for(ctx), [7, 3, 5] as Array[int], ctx)
	for ctx: String in ["league_fair", "echo"]:
		assert_eq(ShopEffects.seals_for(ctx), [0, 0, 0] as Array[int], ctx)
	var be := LocalBackend.new()
	be.switch_user("ann")
	LocalShop.of(be)._shop(be.me()).unlocks["power_seal"] = 4
	assert_eq(be._league_expect({"seed": 1, "teams": [[], []], "league": LeagueRules.FAIR, "user": be.me()}).seals, [0, 0, 0])
	assert_eq(be._league_expect({"seed": 1, "teams": [[], []], "league": LeagueRules.OPEN, "user": be.me()}).seals, [4, 0, 0])
	assert_true((JSON.parse_string(FileAccess.get_file_as_string("res://store/products.json")).products as Array).all(
		func(p: Dictionary) -> bool: return not str(p.offer).contains("_seal_")), "seals are Riftglass only")

func _hit(seals: Array) -> int:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 20, ["Cinder Nip"] as Array[String])]
	var foes: Array[Spirling] = [BattleFixtures.make("Zephlet", 20)]
	var m := BattleModel.new(mine, foes, false, 9, 0)
	m.seals = seals
	m.start()
	var before: int = foes[0].hp
	m.submit_turn(BattleAction.make_move(BattleModel.Side.PLAYER, 0), BattleAction.make_rest(BattleModel.Side.FOE))
	return before - foes[0].hp

func test_power_and_guard_change_battle_damage() -> void:
	var plain: int = _hit([[0, 0, 0], [0, 0, 0]])
	assert_gt(plain, 0)
	assert_gt(_hit([[7, 0, 0], [0, 0, 0]]), plain, "Power Seal VII hits harder")
	assert_lt(_hit([[0, 0, 0], [0, 7, 0]]), plain, "a guarded foe takes less")

func test_replay_keeps_and_clamps_seals() -> void:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Zephlet", 5)] as Array[Spirling], true, 5)
	m.seals = [[3, 2, 1], [0, 0, 0]]
	var snap: Dictionary = BattleReplay.snapshot(m, "", "")
	assert_eq(BattleReplay.build_model(snap).seals[0], [3, 2, 1])
	snap["seals"] = [99, 99, 99]
	assert_eq(BattleReplay.build_model(snap).seals[0], [7, 7, 5], "a tampered replay is clamped")
	assert_eq(BattleReferee.from_expect({"seed": 1, "teams": [], "seals": [1, 0, 0]}).seals, [1, 0, 0])

func test_stat_crystals_cap_and_save() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 20)
	var atk: int = s.atk()
	assert_eq(ShopEffects.add_crystal(s, "atk", 10), 10)
	assert_gt(s.atk(), atk)
	assert_eq(ShopEffects.add_crystal(s, "atk", 10), 10)
	assert_eq(ShopEffects.add_crystal(s, "atk", 10), 4, "up to 24 per value")
	assert_eq(ShopEffects.add_crystal(s, "atk", 1), 0)
	var back: Spirling = Spirling.from_dict(s.to_dict())
	assert_eq(int(back.crystal.get("atk", 0)), 24)
	var d: Dictionary = s.to_dict()
	d["crystal"] = {"atk": 500}
	assert_eq(int(Spirling.from_dict(d).crystal.atk), 24, "saves are clamped")
	for n: int in [1, 5, 10]:
		assert_eq(int(Database.item("rg_stat_crystal_%d" % n).crystal), n)
		assert_eq(str(ShopCatalog.offer("rg_stat_crystal_%d" % n).league_scope), "none")

func test_boosters_and_growth_seal() -> void:
	assert_almost_eq(float(Database.item("rg_growth_x5").boost.mult), 5.0, 0.001)
	assert_almost_eq(float(Database.item("rg_coin_boost_x3").boost.mult), 3.0, 0.001)
	assert_eq(int(Database.item("rg_ring_tonic_10").rings), 10)
	var boosts: Dictionary = GameState.shop_boosts.duplicate(true)
	GameState.shop_boosts = {}
	Billing.state = {"unlocks": {}}
	assert_almost_eq(ShopEffects.growth_mult(), 1.0, 0.001)
	Billing.state = {"unlocks": {"growth_plus": 1}}
	assert_almost_eq(ShopEffects.growth_mult(), 1.5, 0.001)
	GameState.shop_boosts = {"growth": {"mult": 5.0, "left": 20}}
	assert_almost_eq(ShopEffects.growth_mult(), 7.5, 0.001, "stacks with a crystal")
	GameState.shop_boosts = boosts

func test_account_power() -> void:
	var party: Array[Spirling] = GameState.party.duplicate()
	GameState.party.clear()
	Billing.state = {"unlocks": {}}
	assert_eq(ShopEffects.account_power(), 0)
	var s: Spirling = BattleFixtures.make("Kindlop", 10)
	s.crystal["def"] = 6
	GameState.party.append(s)
	Billing.state = {"unlocks": {"power_seal": 2, "guard_seal": 1, "speed_seal": 1, "growth_plus": 1}}
	assert_eq(ShopEffects.account_power(), 10 + 5 + 5 + 50 + 6)
	GameState.party.assign(party)

func test_local_server_sells_tiers_in_order() -> void:
	var be := LocalBackend.new()
	var shop: LocalShop = LocalShop.of(be)
	be.switch_user("ann")
	be.call_fn("hello", {"p_version": 1})
	be.call_fn("shop_set_age", {"p_year": 1990, "p_month": 3})
	shop._ledger_add(be.me(), 5000, "store", "test")
	var buy := func(id: String) -> Dictionary:
		return be.call_fn("shop_buy", {"p_offer": id, "p_expected_price": int(ShopCatalog.offer(id).rg_price)}).data
	assert_eq(str(buy.call("rg_power_seal_2").error), "not_yet", "tier II needs tier I")
	assert_true(bool(buy.call("rg_power_seal_1").ok))
	assert_eq(str(buy.call("rg_power_seal_1").error), "offer_limit")
	assert_true(bool(buy.call("rg_power_seal_2").ok))
	assert_eq(int(shop._shop(be.me()).unlocks.power_seal), 2)
