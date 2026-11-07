extends GutTest
## Plan area 8, P2 batch: endless stretch above the lighthouse stair (plan 3264-3265) and the
## echo Wayfarer names (3273).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Online.clock_offset = 0

func test_forty_unique_names_and_stable_echo_names() -> void:
	var all: Array[String] = Gauntlet.names()
	assert_eq(all.size(), 40)
	var seen: Dictionary = {}
	for n: String in all:
		assert_false(seen.has(n), n)
		seen[n] = true
	var a := Gauntlet.new(77, 40)
	assert_eq(a.echo_name(3), Gauntlet.new(77, 40).echo_name(3), "same seed, same name")
	assert_true(a.echo_name(3).trim_prefix("Echo ") in all)

func test_endless_opens_after_the_top_and_grows_a_ring_per_floor() -> void:
	assert_false(Gauntlet.endless_open())
	GameState.set_flag("gauntlet_clear")
	assert_true(Gauntlet.endless_open())
	var run := Gauntlet.new(5, 40)
	var top: int = run.level_for(Gauntlet.FLOORS - 1)
	assert_eq(run.endless_level(0), top + 1)
	assert_eq(run.endless_level(4), top + 5)
	assert_eq(run.endless_level(200), Gauntlet.ENDLESS_MAX_RING)
	for s: Spirling in run.endless_team(2):
		assert_eq(s.level, top + 3)

func test_endless_waymarks_per_new_floor_capped_weekly() -> void:
	Gauntlet.pay_endless(5)
	assert_eq(GameState.waymarks, 5 * Gauntlet.ENDLESS_WAYMARKS)
	Gauntlet.pay_endless(3)
	assert_eq(GameState.waymarks, 5 * Gauntlet.ENDLESS_WAYMARKS, "no new floor, no pay")
	Gauntlet.pay_endless(200)
	assert_eq(GameState.waymarks, Gauntlet.ENDLESS_WEEK_CAP, "at most 100 a week")
	assert_eq(Gauntlet.endless_best(), 200)
	Online.clock_offset = 7 * 86400
	Gauntlet.pay_endless(4)
	assert_eq(GameState.waymarks, Gauntlet.ENDLESS_WEEK_CAP + 4 * Gauntlet.ENDLESS_WAYMARKS, "a new week counts again")
