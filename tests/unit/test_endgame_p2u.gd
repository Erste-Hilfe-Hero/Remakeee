extends GutTest
## Plan area 8, P2 batch: return help (3499), no countdown under an hour (3501) and daily task
## rewards that are never lost at midnight (3504).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Online.clock_offset = 0

func test_return_help_after_two_weeks() -> void:
	assert_true(SeasonPath.note_play().is_empty(), "the first day is no return")
	var base: int = SeasonPath.points_for("daily_task")
	assert_gt(base, 0)
	Online.clock_offset = 5 * 86400
	assert_true(SeasonPath.note_play().is_empty(), "five days away is no long break")
	assert_false(SeasonPath.boost_active())
	Online.clock_offset = (5 + SeasonPath.RETURN_GAP_DAYS) * 86400
	assert_eq(SeasonPath.note_play().size(), 1)
	assert_true(SeasonPath.boost_active())
	var before: int = GameState.as_int(SeasonPath.state().get("points", 0))
	SeasonPath.add("daily_task")
	assert_eq(GameState.as_int(SeasonPath.state().points), before + 2 * base, "double points")
	assert_true(SeasonPath.note_play().is_empty(), "once per return")
	Online.clock_offset += SeasonPath.RETURN_DAYS * 86400
	SeasonPath.note_play()
	assert_false(SeasonPath.boost_active(), "three days only")

func test_clock_set_back_starts_nothing() -> void:
	Online.clock_offset = 30 * 86400
	SeasonPath.note_play()
	Online.clock_offset = 0
	assert_true(SeasonPath.note_play().is_empty())
	assert_false(SeasonPath.boost_active())

func test_trip_under_an_hour_reads_back_today() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 10)
	s.uid = "late"
	GameState.storage.append(s)
	Expeditions.send(s, 4)
	(GameState.records["expeditions"] as Array)[0]["start"] = Online.unix_now() - 4 * 3600 + 1200
	var line: String = Expeditions.status_lines()[0]
	assert_string_contains(line, Loc.t("%s: back today") % s.display_name())
	assert_false(line.contains("min"), "no minutes countdown")

func test_festival_last_day_reads_ends_today() -> void:
	# Step the clock to the last day of an active festival.
	var found: bool = false
	for i: int in 400:
		Online.clock_offset = i * 86400
		if not Festival.active().is_empty() and Festival.days_left() <= 1:
			found = true
			break
	assert_true(found, "some festival has a last day within a year")
	var text: String = "\n".join(Festival.goal_lines())
	assert_string_contains(text, "ends today")
	assert_false(text.contains("days left"))

func test_task_done_before_midnight_is_paid_at_once() -> void:
	var t: Dictionary = {}
	for d: Dictionary in DailyTasks.defs():
		if not d.has("distinct") and not d.has("map") and not d.has("element") and not d.has("night") and not d.has("wild"):
			t = d
			break
	assert_false(t.is_empty(), "a task without conditions")
	GameState.daily_tasks = {"day": DailyTasks.day_key(), "tasks": [{"id": str(t.id), "n": int(t.get("n", 1)) - 1}], "bonus": false}
	var before: int = GameState.waymarks
	DailyTasks.record(str(t.event), {"map": "fernstair"})
	assert_true(DailyTasks.is_done((GameState.daily_tasks.tasks as Array)[0]))
	var paid: int = GameState.waymarks
	assert_gt(paid, before, "paid the moment it is done, nothing waits for a claim")
	Online.clock_offset = 86400
	DailyTasks.today()
	assert_eq(GameState.waymarks, paid, "nothing taken back on the next day")
