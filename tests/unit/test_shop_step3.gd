extends GutTest
## Pay-to-win step 3 (Ali, 11 Nov 2026, "Fortschritt beschleunigen"): Ring Crown, Ring Cap Seal,
## Vault of Coins. Values come from data/shop.json and data/items.json. Since 2026-11-27 there is
## no Ring cap (owner decision): the Ring Cap Seal is off sale, owners keep its unlock.

var _state: Dictionary
var _difficulty: int
var _rifts: Array[String]
var _flags: Variant
var _money: int

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_state = Billing.state.duplicate(true)
	_difficulty = GameState.difficulty
	_rifts = GameState.rifts_sealed.duplicate()
	_flags = GameState.flags.duplicate(true)
	_money = GameState.money

func after_each() -> void:
	Billing.state = _state
	GameState.difficulty = _difficulty as GameState.Difficulty
	GameState.rifts_sealed = _rifts
	GameState.flags = _flags
	GameState.money = _money
	GameState.inventory.erase("rg_ring_crown")

func _veteran_first_cap() -> int:
	GameState.difficulty = GameState.Difficulty.VETERAN
	GameState.rifts_sealed.clear()
	GameState.flags.erase(GameState.ACT1_END_FLAG)
	return GameState.progress_cap()

func test_offers_are_fixed_riftglass_only_and_for_13_plus() -> void:
	for id: String in ["rg_ring_crown", "rg_coins_100000"]:
		var o: Dictionary = ShopCatalog.offer(id)
		assert_false(o.is_empty(), id)
		assert_eq(str(o.kind), "advantage", id)
		assert_true(bool(o.rg_only), id)
		assert_eq(int(o.min_band), 13, id)
		assert_eq(int(o.eur_cents), int(o.rg_price) - 1, "euro equivalent shown for " + id)
		assert_eq(str(o.league_scope), "none", id)
	assert_eq(ShopCatalog.offer("rg_coins_100000").grants, [{"t": "coins", "n": 100000.0}])

## The Ring Cap Seal stays in the catalog (purchase records and the server copy read it) but is
## not for sale: not ready, never listed, Billing refuses it. Its unlock stays readable.
func test_ring_cap_seal_is_off_sale_and_harmless() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_ring_cap_plus")
	assert_false(o.is_empty(), "the offer row stays for owners")
	assert_false(bool(o.ready), "off sale")
	assert_true(bool(o.rg_only), "never a store product")
	assert_eq(int(o.limit.n), 1, "once per account")
	for tab: Variant in ["advantages", "featured", str(o.tab)]:
		for shown: Dictionary in ShopCatalog.in_tab(str(tab)):
			assert_ne(str(shown.id), "rg_ring_cap_plus", "never listed in " + str(tab))
	Billing.state = {"open": true, "band": 18, "unlocks": {}}
	assert_eq(Billing.block_reason(o, true), "not_available")
	assert_eq(ShopEffects.ring_cap_bonus(), 0)
	Billing.state = {"unlocks": {"ring_cap_plus": 1}}
	assert_eq(ShopEffects.ring_cap_bonus(), 5, "an owner's unlock stays readable")
	assert_false(GameState.has_method("level_cap"), "there is no ring cap left to raise")
	assert_false(GameState.has_method("has_ring_limit"))

func test_ring_crown_jumps_to_fifty_with_no_cap() -> void:
	GameState.difficulty = GameState.Difficulty.TAMER
	Billing.state = {"unlocks": {}}
	var s := Spirling.new(Database.species("Mossling"), 10)
	GameState.add_item("rg_ring_crown")
	assert_string_contains(GameState.use_item_outside_battle("rg_ring_crown", s), "Ring 50")
	assert_eq(s.level, 50)
	var cap: int = _veteran_first_cap()
	var t := Spirling.new(Database.species("Mossling"), 5)
	GameState.add_item("rg_ring_crown")
	GameState.use_item_outside_battle("rg_ring_crown", t)
	assert_eq(t.level, 50, "no Ring cap stops it (story ring %d at this point)" % cap)

func test_vault_of_coins_grants_exactly_its_coins() -> void:
	GameState.money = 1000
	Billing.apply_grant({"t": "coins", "n": 100000})
	assert_eq(GameState.money, 101000)

func test_account_power_counts_the_ring_cap_seal() -> void:
	Billing.state = {"unlocks": {}}
	var before: int = ShopEffects.account_power()
	Billing.state = {"unlocks": {"ring_cap_plus": 1}}
	assert_eq(ShopEffects.account_power(), before + 50)
