extends GutTest
## Pay-to-win step 4 (plan points 16 to 19): Crit Seal I-III, Status Ward, Opening Shield and the
## line that names the bought advantages at the start of a battle. Values come from data/shop.json.

const IDS: Array[String] = ["rg_crit_seal_1", "rg_crit_seal_2", "rg_crit_seal_3", "rg_status_ward", "rg_start_shield"]

var _state: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_state = Billing.state.duplicate(true)

func after_each() -> void:
	Billing.state = _state

func test_offers_are_fixed_riftglass_only_and_for_13_plus() -> void:
	for id: String in IDS:
		var o: Dictionary = ShopCatalog.offer(id)
		assert_false(o.is_empty(), id)
		assert_eq(str(o.kind), "advantage", id)
		assert_true(bool(o.rg_only), id)
		assert_eq(int(o.min_band), 13, id)
		assert_eq(int(o.eur_cents), int(o.rg_price) - 1, "euro equivalent shown for " + id)
		assert_eq(str(o.league_scope), "open", id)
		assert_eq(int(o.limit.n), 1, "once per account: " + id)
	for t: int in 3:
		assert_eq(str(ShopCatalog.offer(IDS[t]).requires), "tier:crit_seal:%d" % t, "tiers in order")
	var products: Array = JSON.parse_string(FileAccess.get_file_as_string("res://store/products.json")).products
	for p: Dictionary in products:
		assert_false(str(p.offer) in IDS, "no store product for " + str(p.offer))
	var mine: Array[Dictionary] = []
	for id: String in IDS:
		mine.append(ShopCatalog.offer(id))
	assert_eq(ShopValidator.check(mine), [] as Array[String])

func test_values_come_from_data_and_never_reach_the_fair_league() -> void:
	assert_eq(ShopEffects.seal_max("crit_seal"), 3)
	assert_eq(ShopEffects.seal_max("status_ward"), 1)
	assert_eq(ShopEffects.seal_max("start_shield"), 1)
	Billing.state = {"unlocks": {"crit_seal": 9, "status_ward": 1, "start_shield": 1}}
	assert_eq(ShopEffects.amulet_tiers(), [3, 1, 1] as Array[int], "clamped to the top tier")
	for ctx: String in ["story", "raid", "league_open"]:
		assert_eq(ShopEffects.amulets_for(ctx), [3, 1, 1] as Array[int], ctx)
	for ctx: String in ["league_fair", "echo"]:
		assert_eq(ShopEffects.amulets_for(ctx), [0, 0, 0] as Array[int], ctx)
	var be := LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	be.rng.seed = 1
	be.switch_user("ann")
	LocalShop.of(be)._shop(be.me()).unlocks["crit_seal"] = 2
	assert_eq(be._league_expect({"seed": 1, "teams": [[], []], "league": LeagueRules.FAIR, "user": be.me()}).amulets, [0, 0, 0])
	assert_eq(be._league_expect({"seed": 1, "teams": [[], []], "league": LeagueRules.OPEN, "user": be.me()}).amulets, [2, 0, 0])

func test_crit_seal_adds_percentage_points() -> void:
	assert_almost_eq(ShopEffects.crit_mult(1.0, 0), 1.0, 0.0001)
	assert_almost_eq(ShopEffects.crit_mult(1.0, 3) * DamageCalc.CRIT_CHANCE, DamageCalc.CRIT_CHANCE + 0.15, 0.0001)
	var user: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Nip"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Zephlet", 20)
	var mv: MoveData = user.moves[0]
	var plain: int = 0
	var sealed: int = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i: int in 600:
		plain += int(DamageCalc.compute(user, foe, mv, rng, 1.0, 1.0).crit)
	rng.seed = 4
	for i: int in 600:
		sealed += int(DamageCalc.compute(user, foe, mv, rng, 1.0, ShopEffects.crit_mult(1.0, 3)).crit)
	assert_gt(sealed, plain, "Crit Seal III lands more critical hits")

func _ward_blocks(ward: int, from_side: int, seed: int) -> bool:
	var m := BattleModel.new([BattleFixtures.make("Zephlet", 20)] as Array[Spirling], [BattleFixtures.make("Zephlet", 20)] as Array[Spirling], false, seed, 0)
	m.amulets = [[0, ward, 0], [0, 0, 0]]
	m.start()
	return not m.apply_status(BattleModel.Side.PLAYER, "scorch", 0, from_side)

func test_status_ward_stops_some_foe_statuses_only() -> void:
	var blocked: int = 0
	for seed: int in range(1, 41):
		assert_false(_ward_blocks(0, BattleModel.Side.FOE, seed), "without the ward the status lands")
		assert_false(_ward_blocks(1, BattleModel.Side.PLAYER, seed), "the ward never stops the own side")
		assert_false(_ward_blocks(1, -1, seed), "no cause, no ward")
		blocked += int(_ward_blocks(1, BattleModel.Side.FOE, seed))
	assert_gt(blocked, 0, "the ward stops some")
	assert_lt(blocked, 40, "the ward does not stop all")

func _two_hits(foe_shield: int) -> Array[int]:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 20, ["Cinder Nip"] as Array[String])]
	var foes: Array[Spirling] = [BattleFixtures.make("Zephlet", 30)]
	var m := BattleModel.new(mine, foes, false, 9, 0)
	m.amulets = [[0, 0, 0], [0, 0, foe_shield]]
	m.start()
	var out: Array[int] = []
	for i: int in 2:
		var before: int = foes[0].hp
		m.submit_turn(BattleAction.make_move(BattleModel.Side.PLAYER, 0), BattleAction.make_rest(BattleModel.Side.FOE))
		out.append(before - foes[0].hp)
	return out

func test_opening_shield_softens_only_the_first_hit() -> void:
	var plain: Array[int] = _two_hits(0)
	var shielded: Array[int] = _two_hits(1)
	assert_gt(plain[0], 1)
	assert_lt(shielded[0], plain[0], "the first hit is softened")
	assert_eq(shielded[1], plain[1], "the second hit is not")

func test_replay_keeps_and_clamps_amulets() -> void:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Zephlet", 5)] as Array[Spirling], true, 5)
	m.amulets = [[2, 1, 0], [0, 0, 0]]
	var snap: Dictionary = BattleReplay.snapshot(m, "", "")
	assert_eq(BattleReplay.build_model(snap).amulets[0], [2, 1, 0])
	snap["amulets"] = [99, 99, 99]
	assert_eq(BattleReplay.build_model(snap).amulets[0], [3, 1, 1], "a tampered replay is clamped")
	snap.erase("amulets")
	assert_eq(BattleReplay.build_model(snap).amulets[0], [0, 0, 0], "old replays run without amulets")
	assert_eq(BattleReferee.from_expect({"seed": 1, "teams": [], "amulets": [1, 0, 1]}).amulets, [1, 0, 1])

func _start_texts(seals: Array, amulets: Array) -> Array[String]:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Zephlet", 5)] as Array[Spirling], false, 3, 0)
	m.seals = [seals, [0, 0, 0]]
	m.amulets = [amulets, [0, 0, 0]]
	var out: Array[String] = []
	for e: BattleEvent in m.start():
		if e.type == BattleEvent.Type.SHOP_EDGE:
			out.append(e.describe())
	return out

func test_battle_names_the_bought_advantages_at_work() -> void:
	assert_eq(ShopEffects.edge_line([0, 0, 0], [0, 0, 0]), "")
	assert_eq(_start_texts([0, 0, 0], [0, 0, 0]), [] as Array[String], "no line without advantages")
	var lines: Array[String] = _start_texts([7, 0, 5], [3, 1, 0])
	assert_eq(lines.size(), 1)
	for part: String in ["Power +35%", "Pace +25%", "Crits +15", "Status Ward 50%"]:
		assert_string_contains(lines[0], part)
	assert_false(lines[0].contains("Guard"), "only what works")

func test_account_power_counts_the_amulets() -> void:
	Billing.state = {"unlocks": {}}
	var before: int = ShopEffects.account_power()
	Billing.state = {"unlocks": {"crit_seal": 3, "status_ward": 1, "start_shield": 1}}
	assert_eq(ShopEffects.account_power(), before + 15 + 50 + 50)
