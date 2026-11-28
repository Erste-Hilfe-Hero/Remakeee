extends GutTest
## The bond charm family (1.3.2, owner 28 Nov 2026): ten charms held out before the Mine! bar.
## Bonus and situations (BondCalc.charm_bonus), fewer Mine! taps, the 0.95 cap, the picker rows,
## and where each charm is sold (merchants for coins, the shop for Riftglass and real money).

const FAMILY: Array[String] = ["kin_charm", "charm_inkquill", "charm_kindred", "charm_moonwick", "charm_stormbell",
	"charm_mender", "rg_charm_hush", "rg_charm_swiftleaf", "rg_charm_lantern", "rg_charm_firstlight"]
const COIN: Array[String] = ["kin_charm", "charm_inkquill", "charm_kindred", "charm_moonwick", "charm_stormbell", "charm_mender"]
const PACKS: Array[String] = ["rg_charm_swiftleaf_x3", "rg_charm_lantern_x3", "rg_charm_satchel"]

func before_all() -> void:
	Database.load_all()

func _species(rarity: String) -> SpirlingData:
	for k: String in Database.spirlings:
		var sd: SpirlingData = Database.spirlings[k]
		if sd.rarity == rarity and sd.bond_rate > 0.0:
			return sd
	return null

## A species that shares no element with [param sd].
func _stranger(sd: SpirlingData) -> SpirlingData:
	for k: String in Database.spirlings:
		var o: SpirlingData = Database.spirlings[k]
		var shared: bool = false
		for e: int in o.elements:
			if e in sd.elements:
				shared = true
		if not shared:
			return o
	return null

func test_family_is_ten_charms_in_rank_order_with_own_icons() -> void:
	assert_eq(ShopScreen.charm_family(), FAMILY)
	var icons: Dictionary = {}
	for i: int in FAMILY.size():
		var it: Dictionary = Database.item(FAMILY[i])
		assert_eq(int(it.charm.rank), i + 1, FAMILY[i])
		var key: String = ShopArt.charm_icon_key(FAMILY[i])
		assert_true(ShopArt.GRIDS.has(key), key)
		assert_ne(key, "charm_tag", "own look: " + FAMILY[i])
		icons[key] = true
		assert_false(str(it.charm.effect).is_empty(), "one-line effect: " + FAMILY[i])
	assert_eq(icons.size(), 10, "ten different looks")
	assert_eq(ShopArt.problems(), [] as Array[String])

func test_no_charm_is_sure_or_thrown_and_the_seal_stays_the_only_sure_bond() -> void:
	for id: String in Database.items:
		if bool(Database.items[id].get("bond_sure", false)):
			assert_eq(id, "rg_bond_seal")
	for id: String in FAMILY:
		var it: Dictionary = Database.item(id)
		assert_false(bool(it.get("battle", true)), "not a battle item: " + id)
		assert_false(str(it.name).to_lower().contains("ball"), id)
		assert_true(str(it.description).begins_with("Hold it out") or str(it.description).contains("Hold it out"), "held out: " + id)

func test_without_a_charm_bonding_is_unchanged() -> void:
	var foe := Spirling.new(_species("common"), 10)
	foe.hp = foe.max_hp() / 2
	var base: float = foe.data.bond_rate * 0.5 * 0.8
	assert_almost_eq(BondCalc.chance(foe, 0.8), base, 0.02)
	assert_almost_eq(BondCalc.charm_bonus({}, foe), 0.0, 0.0001)

func test_situations() -> void:
	var sd: SpirlingData = _species("common")
	var foe := Spirling.new(sd, 10)
	var kin := Spirling.new(sd, 10)
	var other := Spirling.new(_stranger(sd), 10)
	var thread: Dictionary = Database.item("charm_kindred")
	assert_almost_eq(BondCalc.charm_bonus(thread, foe, other), 0.06, 0.0001)
	assert_almost_eq(BondCalc.charm_bonus(thread, foe, kin), 0.36, 0.0001, "shares an element")
	var wick: Dictionary = Database.item("charm_moonwick")
	assert_almost_eq(BondCalc.charm_bonus(wick, foe, null, {"night": false}), 0.06, 0.0001)
	assert_almost_eq(BondCalc.charm_bonus(wick, foe, null, {"night": true}), 0.36, 0.0001)
	var bell: Dictionary = Database.item("charm_stormbell")
	assert_almost_eq(BondCalc.charm_bonus(bell, foe, null, {"weather": ""}), 0.06, 0.0001)
	for w: String in ["rain", "fog", "wind", "storm"]:
		assert_almost_eq(BondCalc.charm_bonus(bell, foe, null, {"weather": w}), 0.36, 0.0001, w)
	var ribbon: Dictionary = Database.item("charm_mender")
	foe.hp = foe.max_hp()
	assert_almost_eq(BondCalc.charm_bonus(ribbon, foe), 0.06, 0.0001)
	foe.hp = foe.max_hp() / 2
	assert_almost_eq(BondCalc.charm_bonus(ribbon, foe), 0.36, 0.0001, "half Vigor")
	foe.hp = foe.max_hp()
	foe.status = "scorch"
	assert_almost_eq(BondCalc.charm_bonus(ribbon, foe), 0.36, 0.0001, "a status")
	var hush: Dictionary = Database.item("rg_charm_hush")
	assert_almost_eq(BondCalc.charm_bonus(hush, Spirling.new(sd, 10)), 0.08, 0.0001)
	assert_almost_eq(BondCalc.charm_bonus(hush, Spirling.new(_species("shy"), 10)), 0.43, 0.0001, "shy")

func test_chance_keeps_the_cap_with_the_top_charm() -> void:
	var foe := Spirling.new(_species("common"), 10)
	foe.hp = 1
	foe.status = "scorch"
	var top: float = BondCalc.charm_bonus(Database.item("rg_charm_firstlight"), foe)
	assert_almost_eq(BondCalc.chance(foe, 1.0, top), BondCalc.MAX_CHANCE, 0.0001)
	assert_lt(BondCalc.MAX_CHANCE, 1.0)

func test_fewer_mine_taps_with_a_floor() -> void:
	var common: Dictionary = {"phases": [[0, 1, 2, 0]]}
	assert_eq(BondMinigame.mine_taps(common), 18)
	assert_eq(BondMinigame.mine_taps(common, BondCalc.taps_off(Database.item("charm_inkquill"))), 16)
	assert_eq(BondMinigame.mine_taps(common, BondCalc.taps_off(Database.item("rg_charm_swiftleaf"))), 12)
	assert_eq(BondMinigame.mine_taps({"phases": [[0, 1, 2, 0]], "state": "mended"}, 20), BondCalc.MIN_MINE_TAPS)
	assert_eq(BondCalc.taps_off(Database.item("kin_charm")), 0)
	assert_almost_eq(BondCalc.echo_head_start(Database.item("rg_charm_swiftleaf")), 0.18, 0.0001, "echo call styles")

func test_charm_is_used_up_and_counts_in_battle() -> void:
	var theirs: Array[Spirling] = [BattleFixtures.make("Zephlet", 5)]
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], theirs, true, 5)
	m.inventory["rg_charm_firstlight"] = 2
	m.submit_turn(BattleAction.make_bond(BattleModel.Side.PLAYER, 1.0, "rg_charm_firstlight"), BattleAction.make_rest(BattleModel.Side.FOE))
	assert_eq(int(m.inventory.rg_charm_firstlight), 1, "one used up")

func test_picker_lists_family_by_rank_with_icon_count_and_effect() -> void:
	var bag: Dictionary = {"rg_echo_scent": 1, "charm_moonwick": 2, "kin_charm": 3, "rg_charm_firstlight": 1, "tonic": 4}
	var ids: Array[String] = BattleScene.bond_charms(bag)
	assert_eq(ids, ["kin_charm", "charm_moonwick", "rg_charm_firstlight", "rg_echo_scent"] as Array[String])
	var rows: Array[Dictionary] = BattleScene.charm_rows(ids, bag)
	assert_eq(rows.size(), ids.size() + 1, "plus No charm")
	assert_true(str(rows[1].text).contains("x2"))
	assert_true(str(rows[1].text).contains("+6%, dusk and night +36%"))
	assert_true(rows[1].icon is Texture2D)
	assert_eq(str(rows[3].text).get_slice("\n", 1), "+25% bond", "older charms get a line too")
	assert_eq(str(rows[-1].text), "No charm")

func test_sold_at_merchants_for_coins_and_in_the_shop() -> void:
	var shops: String = ""
	var dir := DirAccess.open("res://data/dialogue")
	for f: String in dir.get_files():
		if f.ends_with(".json"):
			shops += FileAccess.get_file_as_string("res://data/dialogue/" + f)
	for id: String in COIN:
		assert_gt(int(Database.item(id).get("price", 0)), 0, id)
		assert_true(shops.contains(" " + id), "a merchant sells " + id)
		assert_true(ShopCatalog.offer(id).is_empty(), "coin charms are no shop offers")
	for id: String in ["rg_charm_hush", "rg_charm_swiftleaf", "rg_charm_lantern", "rg_charm_firstlight"]:
		var o: Dictionary = ShopCatalog.offer(id)
		assert_true(bool(o.get("rg_only", false)), "single charms for Riftglass: " + id)
		assert_false(shops.contains(" " + id), "shop goods never at merchants")
	for id: String in PACKS:
		var o: Dictionary = ShopCatalog.offer(id)
		assert_false(bool(o.get("rg_only", false)), "real-money pack: " + id)
		assert_eq(str(o.store_type), "consumable")
		assert_true(str(o.product_id).begins_with("de.chimora.game.consumable.charm_"))
		assert_between(int(o.eur_cents), 99, 999)
		assert_eq(int(o.min_band), 13)
		assert_false(o.has("rotation") or o.has("ends_at"), "no countdown")
		assert_false(o.has("limit"), "a consumable pack can be bought again: " + id)
		assert_false(str(o.get("explain", "")).is_empty())
	var products: Array = JSON.parse_string(FileAccess.get_file_as_string("res://store/products.json")).products
	for p: Dictionary in products:
		if str(p.offer) in PACKS:
			assert_eq(str(p.apple_type), "CONSUMABLE", str(p.offer))
			assert_false(str(p.desc_en).to_lower().contains("once"), "no once-only text on a consumable: " + str(p.offer))
	assert_eq(ShopScreen.charm_offers(0).size(), 7)
	assert_eq(ShopScreen.charm_where("charm_moonwick"), "Merchants: 1000 coins")
	assert_eq(ShopScreen.charm_where("rg_charm_lantern"), "Here: 200 Riftglass")

func test_balance_sims_hold_no_charms() -> void:
	for path: String in ["res://scripts/battle/ActSim.gd", "res://tools/balance_sim.gd"]:
		if not FileAccess.file_exists(path):
			continue
		var src: String = FileAccess.get_file_as_string(path)
		for id: String in FAMILY:
			assert_false(src.contains(id), "%s uses %s" % [path, id])
