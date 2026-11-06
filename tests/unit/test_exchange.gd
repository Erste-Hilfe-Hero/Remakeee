extends GutTest
## Plan area 8: Marla's exchange stand (Waymarks only, weekly stock).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_offers_reference_real_items() -> void:
	for o: Dictionary in Exchange.all_offers():
		assert_false(Database.item(str(o.item)).is_empty(), "item %s" % o.item)
		assert_gt(int(o.price), 0)
		assert_gt(int(o.stock), 0)
		assert_true(str(o.tier) in ["base", "full"])

func test_closed_until_first_rift_then_six_then_all() -> void:
	assert_false(Exchange.is_open())
	assert_eq(Exchange.offers().size(), 0)
	GameState.seal_rift("cinder")
	assert_eq(Exchange.offers().size(), 6, "six base offers after the first Rift")
	GameState.set_flag(Exchange.ACT1_FLAG)
	var by_item: Dictionary = {}
	for o: Dictionary in Exchange.offers():
		by_item[str(o.item)] = o
	for e: String in ["ember", "tide", "bloom", "volt", "stone", "gale", "lumen", "umbra"]:
		assert_eq(int(by_item["echo_" + e].price), 150)
		assert_eq(int(by_item["echo_" + e].stock), 1)
	assert_eq(int(by_item["spark_charm"].price), 120)
	assert_eq(int(by_item["spark_charm"].stock), 2)
	assert_eq(int(by_item["tide_pearl"].price), 200)
	assert_eq(int(by_item["tide_pearl"].stock), 2)

func test_buy_spends_waymarks_and_respects_weekly_stock() -> void:
	GameState.seal_rift("cinder")
	assert_eq(Exchange.buy("spark_charm"), "Not enough Waymarks.")
	Waymarks.earn(500, "weekly")
	var before: int = GameState.item_count("spark_charm")
	assert_eq(Exchange.buy("spark_charm"), "")
	assert_eq(Exchange.buy("spark_charm"), "")
	assert_eq(GameState.waymarks, 260)
	assert_eq(GameState.item_count("spark_charm"), before + 2)
	assert_string_contains(Exchange.buy("spark_charm"), "Sold out")
	assert_eq(GameState.waymarks, 260, "a refused trade costs nothing")
	assert_eq(Exchange.buy("echo_gale"), "Marla doesn't have that right now.", "full offers wait for Act I")
	# A new week refills the stock.
	GameState.records["exchange"]["week"] = "2000-W01"
	assert_eq(Exchange.left(Exchange.find("spark_charm")), 2)
	assert_eq(GameState.money, 500, "coins are never used")

func test_card_shows_effect_price_and_count() -> void:
	GameState.seal_rift("cinder")
	Waymarks.earn(30, "weekly")
	var card: String = Exchange.describe(Exchange.find("strong_tonic"))
	assert_string_contains(card, "Restores 70 Vigor.")
	assert_string_contains(card, "Price: 20 Waymarks (you have 30)")
	assert_string_contains(card, "In your satchel: 0")
	assert_string_contains(card, "Left this week: 5 of 5")

func test_marla_stands_in_the_lighthouse() -> void:
	var m: MapData = MapData.load_map("lighthouse")
	var found: bool = false
	for n: Dictionary in m.npcs:
		if str(n.id) == "marla":
			found = true
			assert_true(m.is_walkable(Vector2i(int(n.x), int(n.y))))
			assert_eq(str(Dialogue.get_entry(str(n.dialogue)).get("action", "")), "exchange")
	assert_true(found)
