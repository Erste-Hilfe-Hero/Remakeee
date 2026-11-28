extends GutTest
## Plan area 8: monthly album, the four goals tabs and the fair rhythm rules (no streaks,
## server time, nothing paid twice when the clock moves back).

const DAY: int = 86400

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Online.clock_offset = 0

func test_album_has_twelve_fixed_fields() -> void:
	for month: String in ["2026-11", "2026-12", "2027-01"]:
		var ids: Array[String] = Album.draw(month)
		assert_eq(ids.size(), Album.FIELDS)
		assert_eq(ids, Album.draw(month), "the same for everyone")
		var places: int = 0
		for id: String in ids:
			var t: Dictionary = Album.def(id)
			assert_ne(str(t.get("text", "")), "")
			if t.has("map"):
				places += 1
				assert_true(MapData.exists(str(t.map)))
		assert_lte(places, Album.MAX_PLACE_FIELDS)

func _fill_album() -> void:
	var st: Dictionary = Album.state()
	for e: Dictionary in st.tasks:
		e["n"] = int(Album.def(str(e.id)).n)
	# The last field is finished by a real event.
	var last: Dictionary = st.tasks[st.tasks.size() - 1]
	last["n"] = 0
	var t: Dictionary = Album.def(str(last.id))
	last["n"] = int(t.n) - 1
	var info: Dictionary = {"map": str(t.get("map", "fernstair")), "key": "new-place", "wild": bool(t.get("wild", false))}
	if bool(t.get("distinct", false)):
		last["seen"] = []
		last["n"] = 0
		for i: int in int(t.n):
			Album.record(str(t.event), {"map": "m%d" % i, "key": "m%d" % i})
	else:
		Album.record(str(t.event), info)

func test_full_album_pays_once_and_adds_a_sticker() -> void:
	_fill_album()
	assert_eq(Album.filled(), Album.FIELDS)
	assert_eq(GameState.waymarks, Album.FULL_WAYMARKS)
	assert_eq(Album.stickers(), [Album.month_key()])
	Album.record("step", {}, 9999)
	assert_eq(GameState.waymarks, Album.FULL_WAYMARKS, "paid once")
	# Even a damaged album state that is drawn again does not pay the month twice.
	GameState.records["album"] = "broken"
	_fill_album()
	assert_eq(GameState.waymarks, Album.FULL_WAYMARKS)
	assert_eq(Album.wall_lines().size(), 1)

func test_daily_events_fill_the_album() -> void:
	GameState.records["album"] = {"month": Album.month_key(), "tasks": [{"id": "alb_steps_3000", "n": 0}, {"id": "alb_daily_5", "n": 0}], "full": false}
	DailyTasks.record("step", {}, 3000)
	assert_true(Album.is_done(Album.state().tasks[0]))
	assert_string_contains("\n".join(Album.lines()), "1/2")

func test_goals_have_four_tabs() -> void:
	assert_eq(Goals.TABS, ["Story", "Today", "Week", "Collection", "Season path"] as Array[String])
	assert_string_contains(Goals.today(), "Daily tasks")
	assert_string_contains(Goals.today(), "Wandering merchant today")
	assert_string_contains(Goals.week(), "Weekly echo")
	assert_string_contains(Goals.week(), "Lighthouse stair")
	assert_string_contains(Goals.collection(), "Album")
	GameState.set_flag(Masters.SHOW_FLAG)
	assert_string_contains(Goals.week(), "Master Wayfarers")
	GameState.set_flag("aldo_dock_told")
	assert_string_contains(Goals.story(), "After the story")
	for t: String in Goals.TABS:
		assert_ne(Goals.tab_text(t), "", t)

func test_no_streaks_anywhere() -> void:
	for path: String in ["res://data/events.json", "res://data/endgame.json", "res://data/achievements.json"]:
		var text: String = FileAccess.get_file_as_string(path).to_lower()
		assert_false(text.contains("streak"), "no streak in %s" % path)
		assert_false(text.contains("in a row"), "no 'in a row' goal in %s" % path)

func test_missed_days_cost_nothing() -> void:
	Waymarks.earn(50, "daily_task")
	Album.state()
	Online.clock_offset = 40 * DAY
	DailyTasks.today()
	Album.state()
	SeasonPath.state()
	assert_eq(GameState.waymarks, 50, "a gap of weeks takes nothing away")

func test_timed_content_runs_on_server_time() -> void:
	for path: String in ["res://scripts/core/Waymarks.gd", "res://scripts/core/DailyTasks.gd", "res://scripts/core/WorldEvents.gd",
			"res://scripts/core/Expeditions.gd", "res://scripts/core/Album.gd", "res://scripts/core/Masters.gd",
			"res://scripts/core/Festival.gd", "res://scripts/core/SeasonPath.gd", "res://scripts/core/Exchange.gd",
			"res://scripts/core/WeeklyChallenge.gd", "res://scripts/overworld/Gauntlet.gd", "res://scripts/overworld/DailyFind.gd"]:
		var code: String = FileAccess.get_file_as_string(path)
		assert_false(code.contains("_from_system()"), "%s reads the phone clock" % path)

func _finish_today() -> void:
	for e: Dictionary in DailyTasks.today().tasks:
		e["n"] = int(DailyTasks.def(str(e.id)).n) - 1
		var t: Dictionary = DailyTasks.def(str(e.id))
		if bool(t.get("distinct", false)):
			e["seen"] = []
			e["n"] = 0
	for e: Dictionary in DailyTasks.today().tasks.duplicate():
		var t: Dictionary = DailyTasks.def(str(e.id))
		var info: Dictionary = {"map": str(t.get("map", "fernstair")), "wild": bool(t.get("wild", true)),
			"elements": [str(t.get("element", "EMBER"))], "night": bool(t.get("night", false))}
		if bool(t.get("distinct", false)):
			for i: int in int(t.n):
				DailyTasks.record(str(t.event), {"map": "p%d" % i, "key": "p%d" % i})
		else:
			DailyTasks.record(str(t.event), info)

func test_clock_back_pays_nothing_twice() -> void:
	_finish_today()
	assert_true(DailyTasks.all_done())
	var paid: int = GameState.waymarks
	assert_gt(paid, 0)
	# The clock jumps back a day: today's finished tasks stay, nothing is drawn or paid again.
	Online.clock_offset = -DAY
	DailyTasks.today()
	assert_true(DailyTasks.all_done())
	DailyTasks.record("step", {}, 999)
	assert_eq(GameState.waymarks, paid)
	# Masters: going back a week does not pay the weekly reward again.
	Online.clock_offset = 0
	var id: String = str(Masters.list()[0].id)
	Masters.win(id)
	var after: int = GameState.waymarks
	Online.clock_offset = -8 * DAY
	assert_false(Masters.pays_now(id))
	Masters.win(id)
	assert_eq(GameState.waymarks, after)
	# Season path keeps its season.
	Online.clock_offset = 0
	var season: String = str(SeasonPath.state().season)
	Online.clock_offset = -120 * DAY
	assert_eq(str(SeasonPath.state().season), season)
