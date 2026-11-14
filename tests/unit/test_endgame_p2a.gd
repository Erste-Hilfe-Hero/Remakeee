extends GutTest
## Plan area 8, P2 batch: Waymark history, sources, save card, season path bonus steps,
## festival goals and the one-festival-per-month rule.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Online.clock_offset = 0

func _unix(date: String) -> int:
	return Time.get_unix_time_from_datetime_string(date + "T12:00:00")

func test_history_shows_newest_first_with_source_names() -> void:
	Waymarks.earn(10, "daily_task")
	Waymarks.earn(40, "echo_path")
	var lines: Array[String] = Waymarks.history_lines()
	assert_eq(lines.size(), 2)
	assert_string_contains(lines[0], "Echo Path: 40")
	assert_string_contains(lines[1], "Daily task: 10")
	for i: int in 40:
		Waymarks.earn(1, "tower")
	assert_eq(Waymarks.history_lines().size(), Waymarks.HISTORY)
	for src: String in Waymarks.SOURCES:
		assert_true(Waymarks.SOURCE_NAMES.has(src), src)

## Plan 3124: every Waymarks.earn() call in the game names a source from Waymarks.SOURCES.
func test_every_reward_uses_a_valid_source() -> void:
	var re := RegEx.create_from_string(r'Waymarks\.earn\([^\n]*?"([a-z_]+)"\)')
	var found: int = 0
	for dir: String in ["res://scripts/core/", "res://scripts/overworld/", "res://scripts/ui/", "res://scripts/battle/"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var text: String = FileAccess.get_file_as_string(dir + f)
			for m: RegExMatch in re.search_all(text):
				found += 1
				assert_true(m.get_string(1) in Waymarks.SOURCES, "%s uses '%s'" % [f, m.get_string(1)])
	assert_gt(found, 5)

## Plan 3125: a lost battle never takes Waymarks; only the exchange stand spends them.
func test_only_spend_lowers_waymarks() -> void:
	for dir: String in ["res://scripts/core/", "res://scripts/overworld/", "res://scripts/ui/", "res://scripts/battle/"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and f != "Waymarks.gd":
				assert_false(FileAccess.get_file_as_string(dir + f).contains("waymarks -="), f)

func test_save_card_shows_waymarks() -> void:
	var d: Dictionary = GameState.to_dict()
	assert_false(SaveManager.summary_line(d).contains(Waymarks.GLYPH))
	d["waymarks"] = 345
	assert_string_contains(SaveManager.summary_line(d), Waymarks.GLYPH + "345")

func test_steps_past_the_last_pay_twenty() -> void:
	var st: Dictionary = SeasonPath.state()
	st.points = SeasonPath.tiers() * SeasonPath.per_tier() - 1
	st.claimed = SeasonPath.tiers()
	var before: int = GameState.waymarks
	var n: int = SeasonPath.per_tier() * 2 / maxi(1, SeasonPath.points_for("weekly")) + 1
	for i: int in n:
		SeasonPath.add("weekly")
	assert_eq(SeasonPath.extra_steps(), int(st.extra))
	assert_gte(SeasonPath.extra_steps(), 2)
	assert_eq(GameState.waymarks - before, SeasonPath.extra_steps() * SeasonPath.EXTRA_STEP_WAYMARKS)
	assert_string_contains("\n".join(SeasonPath.goal_lines()), "%d" % SeasonPath.EXTRA_STEP_WAYMARKS)

## Plan 3224: no month has two festivals.
func test_at_most_one_festival_per_month() -> void:
	for month: int in range(1, 13):
		var n: int = 0
		for f: Dictionary in Season.festivals():
			if month in (f.months as Array):
				n += 1
		assert_lte(n, 1, "month %d" % month)

func test_festival_goal_lines_every_month() -> void:
	for month: int in range(1, 13):
		Online.clock_offset = _unix("2027-%02d-10" % month) - int(Time.get_unix_time_from_system())
		var lines: Array[String] = Festival.goal_lines()
		assert_eq(lines.size(), 1, "month %d" % month)
		if not Festival.active().is_empty():
			assert_between(Festival.days_left(), 1, 62)
	Online.clock_offset = _unix("2027-05-31") - int(Time.get_unix_time_from_system())
	assert_eq(Festival.days_left(), 1, "the last day of the Bloom Fair")
	Online.clock_offset = _unix("2026-12-01") - int(Time.get_unix_time_from_system())
	assert_eq(Festival.days_left(), 62, "Hearth Weeks run through January")
	assert_string_contains(Goals.today(), "days left")
	assert_string_contains(Goals.tab_text("Season path"), "Season path")
