extends GutTest
## Plan area 8: free season path and Spirlog goals with Waymarks.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_thirty_visible_rewards() -> void:
	assert_eq(SeasonPath.tiers(), 30)
	assert_eq(SeasonPath.rewards().size(), 30)
	assert_eq(SeasonPath.lines().size(), 30, "the whole path is visible from the start")
	for r: Variant in SeasonPath.rewards():
		assert_ne(SeasonPath.reward_text(r), "")
		if str((r as Dictionary).get("item", "")) != "":
			assert_false(Database.item(str(r.item)).is_empty(), str(r.item))
	assert_eq(SeasonPath.points_for("daily_task"), 15)
	assert_eq(SeasonPath.points_for("weekly"), 40)
	assert_eq(SeasonPath.points_for("festival_stage"), 20)
	assert_eq(SeasonPath.points_for("shop"), 0, "only playing moves the path")

func test_points_advance_and_pay_each_step_once() -> void:
	var coins: int = GameState.money
	for i: int in 10:
		SeasonPath.add("daily_task")
	assert_eq(SeasonPath.tier(), 1)
	assert_gt(GameState.money, coins, "step 1 pays coins")
	SeasonPath.add("weekly")
	SeasonPath.add("weekly")
	SeasonPath.add("festival_stage")
	assert_eq(SeasonPath.tier(), 2)
	assert_eq(int(SeasonPath.state().claimed), 2)

func test_new_season_starts_fresh() -> void:
	GameState.records["season_path"] = {"season": "2001-Q1", "points": 900, "claimed": 9}
	assert_eq(SeasonPath.tier(), 0)
	assert_eq(str(SeasonPath.state().season), SeasonPath.season_key())

func test_daily_task_feeds_the_path() -> void:
	GameState.daily_tasks = {"day": DailyTasks.day_key(), "tasks": [{"id": "photo", "n": 0}], "bonus": false}
	DailyTasks.record("photo", {})
	assert_eq(int(SeasonPath.state().points), SeasonPath.points_for("daily_task") + SeasonPath.points_for("daily_bonus"), "the only task of the day also brings the bonus points")

func test_seen_goals_pay_waymarks() -> void:
	var names: Array = Database.spirlings.keys()
	for i: int in 5:
		GameState.mark_seen(str(names[i]))
	Collection.claim()
	assert_true((GameState.records["collection"] as Dictionary).has("seen_5"))
	var w: int = GameState.waymarks
	Collection.claim()
	assert_eq(GameState.waymarks, w, "paid once")

func test_bonded_goal_pays_waymarks_too() -> void:
	var names: Array = Database.spirlings.keys()
	for i: int in 3:
		GameState.mark_seen(str(names[i]), true)
	var w: int = GameState.waymarks
	Collection.claim()
	assert_gte(GameState.waymarks - w, 20)

func test_star_needs_bond_and_ring_30() -> void:
	assert_false(Collection.starred("Kindlop"))
	GameState.party[0].level = 30
	assert_true(Collection.starred("Kindlop"))
