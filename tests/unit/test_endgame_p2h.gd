extends GutTest
## Plan area 8, P2 batch: season path pacing (plan 3242), capped bonus steps and steps that
## pay at once (3243).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_step_30_in_11_weeks_with_4_play_days() -> void:
	var week: int = 4 * (DailyTasks.PER_DAY * SeasonPath.points_for("daily_task") + SeasonPath.points_for("daily_bonus")) + SeasonPath.points_for("weekly")
	assert_gte(11 * week, SeasonPath.tiers() * SeasonPath.per_tier(), "11 weeks are enough")
	assert_lt(8 * week, SeasonPath.tiers() * SeasonPath.per_tier(), "but it is not over in two months")
	for w: int in 11:
		for d: int in 4:
			for t: int in DailyTasks.PER_DAY:
				SeasonPath.add("daily_task")
			SeasonPath.add("daily_bonus")
		SeasonPath.add("weekly")
	assert_eq(SeasonPath.tier(), SeasonPath.tiers())
	assert_eq(int(SeasonPath.state().claimed), SeasonPath.tiers(), "every reached step is paid at once")

func test_bonus_steps_are_capped() -> void:
	for i: int in 400:
		SeasonPath.add("weekly")
	assert_eq(SeasonPath.extra_steps(), SeasonPath.MAX_EXTRA_STEPS)
	assert_eq(int(SeasonPath.state().get("extra", 0)), SeasonPath.MAX_EXTRA_STEPS)
