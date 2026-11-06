extends GutTest
## Plan area 8: Waymarks (earned-only endgame currency) and daily tasks.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_earn_logs_and_caps() -> void:
	var r: Dictionary = Waymarks.earn(10, "daily_task")
	assert_eq(int(r.gained), 10)
	assert_eq(GameState.waymarks, 10)
	var entries: Array = GameState.records["waymark_log"]
	assert_eq(entries.size(), 1)
	assert_eq(str(entries[0].src), "daily_task")
	GameState.waymarks = Waymarks.CAP - 5
	r = Waymarks.earn(20, "weekly")
	assert_eq(int(r.gained), 5)
	assert_eq(int(r.lost), 15)
	assert_eq(GameState.waymarks, Waymarks.CAP)
	assert_eq(Waymarks.reward_lines(r).size(), 2, "an overflow is announced")

func test_log_keeps_last_200() -> void:
	for i: int in 250:
		Waymarks.earn(1, "tower")
	assert_eq((GameState.records["waymark_log"] as Array).size(), Waymarks.LOG_MAX)
	assert_eq(int(GameState.records["waymarks_total"]), 250)

func test_unknown_source_and_negative_amounts_do_nothing() -> void:
	Waymarks.earn(50, "shop")
	Waymarks.earn(-5, "daily_task")
	assert_eq(GameState.waymarks, 0)
	assert_push_warning("unknown source")

func test_spend() -> void:
	Waymarks.earn(100, "weekly")
	assert_false(Waymarks.spend(101))
	assert_true(Waymarks.spend(60))
	assert_eq(GameState.waymarks, 40)

func test_never_buyable_or_tradeable() -> void:
	assert_false(Waymarks.TRANSFERABLE)
	assert_false("shop" in Waymarks.SOURCES)
	assert_false("gift" in Waymarks.SOURCES)
	assert_false("trade" in Waymarks.SOURCES)
	for id: Variant in Database.items:
		assert_false(str(id).contains("waymark"), "Waymarks are no bag item, so they cannot be gifted")

func test_gain_text() -> void:
	assert_eq(Waymarks.gain_text(10), "+10 Waymarks")
	assert_true(Waymarks.label().ends_with("0"))

func test_save_round_trip_and_old_saves() -> void:
	Waymarks.earn(42, "daily_task")
	DailyTasks.today()
	var d: Dictionary = GameState.to_dict()
	GameState.reset()
	GameState.from_dict(d)
	assert_eq(GameState.waymarks, 42)
	assert_eq(str(GameState.daily_tasks.get("day", "")), DailyTasks.day_key())
	d.erase("waymarks")
	d.erase("daily_tasks")
	GameState.from_dict(d)
	assert_eq(GameState.waymarks, 0, "old saves start with no Waymarks")
	assert_eq(GameState.daily_tasks, {})

# --- Daily tasks -------------------------------------------------------------------------

func _late_game() -> void:
	for m: String in ["lighthouse", "brindlewick", "fernstair", "crowcrest", "saltmarsh", "murk_hollow", "thornridge"]:
		DailyTasks.note_map(m)
	GameState.visit_rest("brindlewick", Vector2i(3, 3))
	GameState.visit_rest("crowcrest", Vector2i(3, 3))

func test_enough_task_kinds_with_text() -> void:
	assert_gte(DailyTasks.defs().size(), 30)
	var ids: Dictionary = {}
	for t: Dictionary in DailyTasks.defs():
		assert_false(ids.has(t.id), "duplicate task id %s" % t.id)
		ids[t.id] = true
		assert_true(str(t.get("text", "")) != "")
		assert_true(str(t.event) in ["win", "bond", "rest", "visit", "step", "photo", "talk"], str(t.id))
		assert_lte(int(t.n), 600, "each task fits in about 15 minutes")
		if t.has("map"):
			assert_true(MapData.exists(str(t.map)), "map %s" % t.map)
		if t.has("element"):
			assert_true(Elements.E.has(str(t.element)), "element %s" % t.element)

func test_draw_is_stable_three_tasks_one_battle_at_most() -> void:
	_late_game()
	for day: int in range(1, 29):
		var key: String = "2026-11-%02d" % day
		var ids: Array[String] = DailyTasks.draw(key)
		assert_eq(ids, DailyTasks.draw(key), "same day, same tasks")
		assert_eq(ids.size(), DailyTasks.PER_DAY)
		var battles: int = 0
		for id: String in ids:
			if str(DailyTasks.def(id).kind) == "battle":
				battles += 1
		assert_lte(battles, DailyTasks.MAX_BATTLE_TASKS)

func test_fresh_save_only_gets_doable_tasks() -> void:
	# A brand-new save stands in the lighthouse: no wild areas reached yet.
	var maps: Array[String] = DailyTasks.reached_maps()
	var els: Array[String] = DailyTasks.reachable_elements(maps)
	for day: int in range(1, 15):
		var ids: Array[String] = DailyTasks.draw("2026-12-%02d" % day)
		assert_eq(ids.size(), DailyTasks.PER_DAY)
		for id: String in ids:
			var t: Dictionary = DailyTasks.def(id)
			assert_false(str(t.event) in ["win", "bond"], "no battle tasks before wild areas: %s" % id)
			assert_true(DailyTasks.doable(t, maps, els))

func test_tasks_never_need_unreached_places_or_elements() -> void:
	DailyTasks.note_map("murk_hollow")
	var maps: Array[String] = DailyTasks.reached_maps()
	var els: Array[String] = DailyTasks.reachable_elements(maps)
	assert_false("TIDE" in els, "no Tide Spirlings live in Murk Hollow")
	assert_false(DailyTasks.doable(DailyTasks.def("bond_tide"), maps, els))
	assert_true(DailyTasks.doable(DailyTasks.def("bond_umbra"), maps, els))
	assert_false(DailyTasks.doable(DailyTasks.def("win_saltmarsh"), maps, els))

func _force(ids: Array) -> void:
	var tasks: Array = []
	for id: Variant in ids:
		tasks.append({"id": str(id), "n": 0})
	GameState.daily_tasks = {"day": DailyTasks.day_key(), "tasks": tasks, "bonus": false}

func test_progress_pays_waymarks_and_bonus() -> void:
	_force(["win_fernstair", "bond_gale", "rest_2"])
	DailyTasks.record("win", {"map": "crowcrest", "wild": true, "elements": ["GALE"]})
	assert_eq(int(GameState.daily_tasks.tasks[0].n), 0, "wrong place does not count")
	for i: int in 3:
		DailyTasks.record("win", {"map": "fernstair", "wild": true, "elements": ["VOLT"]})
	assert_eq(GameState.waymarks, DailyTasks.REWARD)
	DailyTasks.record("bond", {"map": "fernstair", "elements": ["VOLT"]})
	assert_eq(GameState.waymarks, DailyTasks.REWARD)
	DailyTasks.record("bond", {"map": "fernstair", "elements": ["GALE"]})
	assert_eq(GameState.waymarks, 2 * DailyTasks.REWARD)
	DailyTasks.record("rest", {"map": "fernstair"})
	DailyTasks.record("rest", {"map": "fernstair"})
	assert_false(DailyTasks.all_done(), "two rests at the same spring are one place")
	var lines: Array[String] = DailyTasks.record("rest", {"map": "brindlewick"})
	assert_true(DailyTasks.all_done())
	assert_eq(GameState.waymarks, 3 * DailyTasks.REWARD + DailyTasks.BONUS)
	assert_true(lines.has("+10 Waymarks"), "reward lines name the amount")
	DailyTasks.record("rest", {"map": "crowcrest"})
	assert_eq(GameState.waymarks, 3 * DailyTasks.REWARD + DailyTasks.BONUS, "nothing pays twice")
	assert_eq(int(GameState.records["daily_tasks_done"]), 3)
	assert_false(GameState.notices.is_empty(), "rewards are queued for the overworld")

func test_new_day_draws_fresh_without_penalty() -> void:
	GameState.daily_tasks = {"day": "2000-01-01", "tasks": [{"id": "photo", "n": 0}], "bonus": false}
	Waymarks.earn(30, "daily_task")
	var st: Dictionary = DailyTasks.today()
	assert_eq(str(st.day), DailyTasks.day_key())
	assert_eq(GameState.waymarks, 30, "a missed day takes nothing away")

func test_goals_lines_show_progress() -> void:
	_force(["steps_300", "photo", "talk_3"])
	DailyTasks.record("step", {}, 12)
	var lines: Array[String] = DailyTasks.lines()
	assert_eq(lines.size(), 5)
	assert_string_contains(lines[1], "12/300")
	assert_string_contains(PauseMenu.goals_text(), "Walk 300 steps")
