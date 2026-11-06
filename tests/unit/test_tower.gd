extends GutTest
## Plan area 8: lighthouse stair with 30 floors, rest points and Waymarks per floor.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_thirty_floors_in_three_sections() -> void:
	assert_eq(Gauntlet.FLOORS, 30)
	assert_eq(Gauntlet.FLOORS / Gauntlet.SECTION, 3)
	assert_true(Gauntlet.is_rest_point(10))
	assert_true(Gauntlet.is_rest_point(20))
	assert_false(Gauntlet.is_rest_point(30), "the top is the end, not a rest point")
	assert_false(Gauntlet.is_rest_point(9))
	assert_eq(Gauntlet.ai_for(0), 1)
	assert_eq(Gauntlet.ai_for(10), 2)
	assert_eq(Gauntlet.ai_for(29), 3)

func test_rings_follow_cap_not_strongest_spirling() -> void:
	GameState.party[0].level = 50
	var run := Gauntlet.new(3, GameState.progress_cap())
	assert_lte(run.level_for(29), GameState.progress_cap())
	for f: int in Gauntlet.FLOORS - 1:
		assert_lte(run.level_for(f), run.level_for(f + 1), "floors never get easier")
	assert_eq(run.team(5).size(), Gauntlet.TEAM_SIZE)

func test_floor_waymarks_paid_once() -> void:
	for f: int in range(1, 11):
		Gauntlet.pay_floor(f)
	assert_eq(GameState.waymarks, 9 * Gauntlet.FLOOR_WAYMARKS + Gauntlet.SECTION_WAYMARKS)
	assert_eq(Gauntlet.pay_floor(7), [] as Array[String], "a floor pays only the first time")
	assert_eq(GameState.waymarks, 95)

func test_checkpoint_saved_and_old_best_kept() -> void:
	assert_eq(Gauntlet.checkpoint(), 0)
	Gauntlet.save_checkpoint(20, 77)
	assert_eq(Gauntlet.checkpoint(), 20)
	assert_eq(Gauntlet.checkpoint_seed(), 77)
	var d: Dictionary = GameState.to_dict()
	GameState.from_dict(d)
	assert_eq(Gauntlet.checkpoint(), 20, "the climb survives a save")
	Gauntlet.clear_checkpoint()
	assert_eq(Gauntlet.checkpoint(), 0)
	GameState.records["gauntlet_best"] = 5
	assert_eq(Gauntlet.best(), 5, "an old best of 5 rounds reads as floor 5")
