extends GutTest
## Area 3 item 964: fish traps on the Reedhaven jetty, emptied once a day for a remedy or coins.

const TRAPS: Dictionary = {"reed_trap_a": Vector2i(9, 5), "reed_trap_b": Vector2i(8, 6)}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_traps_hang_from_the_jetty() -> void:
	var m: MapData = MapData.load_map("reedhaven")
	for id: String in TRAPS:
		var s: Dictionary = m.sign_at(TRAPS[id])
		assert_eq(str(s.get("dialogue", "")), "reedhaven/" + id)
		assert_eq(str(Dialogue.get_entry("reedhaven/" + id).get("action", "")), "fish_trap " + id)

func test_once_a_day() -> void:
	var got: Dictionary = FishTrap.catch("reed_trap_a", "2026-11-07")
	assert_true(got.has("item") or got.has("money"))
	FishTrap.empty("reed_trap_a", "2026-11-07")
	assert_true(FishTrap.catch("reed_trap_a", "2026-11-07").is_empty(), "empty for the rest of the day")
	assert_false(FishTrap.catch("reed_trap_b", "2026-11-07").is_empty(), "the other trap is still full")
	assert_false(FishTrap.catch("reed_trap_a", "2026-11-08").is_empty(), "full again the next day")

func test_catch_is_a_remedy_or_coins() -> void:
	var kinds: Dictionary = {}
	for d: int in range(1, 29):
		var got: Dictionary = FishTrap.catch("reed_trap_a", "2026-11-%02d" % d)
		if got.has("item"):
			assert_eq(str(got.item), FishTrap.ITEM)
			kinds["item"] = true
		else:
			assert_eq(int(got.money), FishTrap.COINS)
			kinds["money"] = true
	assert_eq(kinds.size(), 2, "both kinds of catch turn up over a month")
