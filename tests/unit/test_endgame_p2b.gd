extends GutTest
## Plan area 8, P2 batch: daily task swap, the fourth (hard) task after Act I, roaming trip
## and night photo tasks.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	for m: String in ["lighthouse", "brindlewick", "fernstair", "crowcrest", "saltmarsh", "murk_hollow", "thornridge"]:
		DailyTasks.note_map(m)
	GameState.visit_rest("brindlewick", Vector2i(3, 3))
	GameState.visit_rest("crowcrest", Vector2i(3, 3))
	GameState.visit_rest("fernstair", Vector2i(3, 3))

func after_each() -> void:
	Online.clock_offset = 0

func _after_act1() -> void:
	GameState.set_flag(GameState.ACT1_END_FLAG)
	GameState.storage.append(GameState.party[0])

func _force(ids: Array) -> void:
	var tasks: Array = []
	for id: Variant in ids:
		tasks.append({"id": str(id), "n": 0})
	GameState.daily_tasks = {"day": DailyTasks.day_key(), "tasks": tasks, "bonus": false}

func test_hard_task_joins_only_after_act1() -> void:
	for day: int in range(1, 15):
		for id: String in DailyTasks.draw("2026-12-%02d" % day):
			assert_false(bool(DailyTasks.def(id).get("hard", false)), "no hard task before Act I: %s" % id)
	_after_act1()
	for day: int in range(1, 15):
		var ids: Array[String] = DailyTasks.draw("2026-12-%02d" % day)
		assert_eq(ids.size(), DailyTasks.PER_DAY + 1)
		assert_true(bool(DailyTasks.def(ids[-1]).get("hard", false)), "the fourth task is the hard one")
		var battles: int = 0
		for id: String in ids:
			if str(DailyTasks.def(id).kind) == "battle":
				battles += 1
		assert_lte(battles, DailyTasks.MAX_BATTLE_TASKS)

func test_hard_task_pays_more() -> void:
	_after_act1()
	_force(["hard_steps_2500"])
	DailyTasks.record("step", {"map": "fernstair"}, 2499)
	assert_eq(GameState.waymarks, 0)
	DailyTasks.record("step", {"map": "fernstair"}, 1)
	assert_eq(GameState.waymarks, DailyTasks.HARD_REWARD + DailyTasks.BONUS)
	assert_string_contains("\n".join(DailyTasks.lines()), "%s%d" % [Waymarks.GLYPH, DailyTasks.HARD_REWARD])

func test_trip_task_needs_act1_and_counts_a_sent_trip() -> void:
	var maps: Array[String] = DailyTasks.reached_maps()
	var els: Array[String] = DailyTasks.reachable_elements(maps)
	assert_false(DailyTasks.doable(DailyTasks.def("send_trip"), maps, els))
	_after_act1()
	assert_true(DailyTasks.doable(DailyTasks.def("send_trip"), maps, els))
	_force(["send_trip"])
	DailyTasks.record("trip", {"map": "fernstair"})
	assert_true(DailyTasks.all_done())

func test_night_photo_counts_only_at_night() -> void:
	_force(["photo_night"])
	DailyTasks.record("photo", {"map": "fernstair", "night": false})
	assert_false(DailyTasks.all_done())
	DailyTasks.record("photo", {"map": "fernstair", "night": true})
	assert_true(DailyTasks.all_done())

func test_swap_once_a_day_for_an_open_task() -> void:
	_force(["photo", "rest_2", "win_fernstair"])
	assert_true(DailyTasks.can_swap())
	var got: String = DailyTasks.swap(0)
	assert_ne(got, "")
	assert_false(got in ["photo", "rest_2", "win_fernstair"], "a task not on today's list")
	assert_false(bool(DailyTasks.def(got).get("hard", false)))
	assert_ne(str(DailyTasks.def(got).get("kind", "")), "battle", "still one battle task at most")
	assert_eq(str(GameState.daily_tasks.tasks[0].id), got)
	assert_false(DailyTasks.can_swap(), "once a day")
	assert_eq(DailyTasks.swap(1), "")

func test_started_task_cannot_be_swapped() -> void:
	_force(["rest_2"])
	DailyTasks.record("rest", {"map": "fernstair"})
	assert_false(DailyTasks.can_swap())
	assert_eq(DailyTasks.swap(0), "")

func test_swap_survives_the_save() -> void:
	_force(["photo", "rest_2"])
	var got: String = DailyTasks.swap(1)
	var d: Dictionary = GameState.to_dict()
	GameState.from_dict(d)
	assert_eq(str(GameState.daily_tasks.tasks[1].id), got)
	assert_false(DailyTasks.can_swap())
