extends GutTest
## Plan area 8, P2 batch: Marla's weekly crates (open list, seeded picks), restock countdown
## and the savings goal.

const DAY: int = 86400

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.rifts_sealed.append("cinder")

func after_each() -> void:
	Online.clock_offset = 0

func test_weekly_list_is_open_and_valid() -> void:
	var main: Array[String] = []
	for o: Dictionary in Exchange.all_offers():
		main.append(str(o.item))
	assert_gte(Exchange.weekly_list().size(), Exchange.WEEKLY_PICKS + 3)
	for o: Dictionary in Exchange.weekly_list():
		assert_false(Database.item(str(o.item)).is_empty(), str(o.item))
		assert_false(str(o.item) in main, "weekly crates do not repeat the main list: %s" % o.item)
		assert_gt(int(o.price), 0)
	var text: String = Exchange.weekly_list_text()
	for o: Dictionary in Exchange.weekly_list():
		assert_string_contains(text, str(Database.item(str(o.item)).name))

func test_weekly_picks_are_seeded_by_week() -> void:
	var a: Array[Dictionary] = Exchange.weekly_for("2026-W45")
	assert_eq(a.size(), Exchange.WEEKLY_PICKS)
	assert_eq(a, Exchange.weekly_for("2026-W45"), "same week, same crates for everyone")
	var ids: Array[String] = []
	for o: Dictionary in a:
		assert_false(str(o.item) in ids, "three different goods")
		ids.append(str(o.item))
	var differs: bool = false
	for w: int in range(1, 20):
		if Exchange.weekly_for("2026-W%02d" % w) != a:
			differs = true
	assert_true(differs, "the picks change over the weeks")

func test_weekly_crates_only_after_act1_and_buyable() -> void:
	for o: Dictionary in Exchange.offers():
		assert_false(bool(o.get("weekly", false)))
	GameState.set_flag(Exchange.ACT1_FLAG)
	var weekly: Array[Dictionary] = Exchange.offers().filter(func(o: Dictionary) -> bool: return bool(o.get("weekly", false)))
	assert_eq(weekly.size(), Exchange.WEEKLY_PICKS)
	var o: Dictionary = weekly[0]
	Waymarks.earn(500, "weekly")
	assert_eq(Exchange.buy(str(o.item)), "")
	assert_eq(GameState.item_count(str(o.item)), 1)
	assert_eq(Exchange.left(o), int(o.stock) - 1)

func test_restock_countdown() -> void:
	for d: int in 7:
		Online.clock_offset = d * DAY
		var n: int = Exchange.days_to_restock()
		assert_between(n, 1, 7)
		var wd: int = int(Time.get_datetime_dict_from_unix_time(Online.unix_now()).weekday)
		if wd == 0:
			assert_eq(n, 1, "Sunday: restock tomorrow")
	assert_string_contains(Exchange.describe(Exchange.offers()[0]), "Monday")

func test_savings_goal_bar() -> void:
	assert_eq(Exchange.goal_line(), "")
	var o: Dictionary = Exchange.offers()[0]
	Exchange.set_goal(str(o.item))
	assert_string_contains(Exchange.goal_line(), "%d more Waymarks" % int(o.price))
	Waymarks.earn(int(o.price), "weekly")
	assert_string_contains(Exchange.goal_line(), "ready")
	assert_string_contains(Goals.week(), Exchange.goal_line())
	var d: Dictionary = GameState.to_dict()
	GameState.from_dict(d)
	assert_eq(str(Exchange.goal().item), str(o.item), "the goal is part of the save")
