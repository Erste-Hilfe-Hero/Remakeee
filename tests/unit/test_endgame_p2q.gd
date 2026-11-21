extends GutTest
## Plan area 8, P2 batch: the run chronicle over all slots (plan 3401-3403, 3411).

const TEST_PATH: String = "user://test_chronicle.json"

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	RunChronicle.path = TEST_PATH
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_all() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	RunChronicle.path = RunChronicle.DEFAULT_PATH

func _finish(starter: String, oath: bool = false) -> void:
	GameState.new_game(GameState.Difficulty.VETERAN, "Tess", 0, starter)
	GameState.iron_oath = oath
	GameState.play_time = 3725.0
	GameState.set_flag(GameState.ACT1_END_FLAG)

func test_a_run_is_booked_once_at_the_end_of_act_one() -> void:
	assert_true(RunChronicle.note().is_empty(), "not before the end of Act I")
	_finish("Kindlop")
	assert_eq(RunChronicle.note().size(), 1)
	assert_true(RunChronicle.note().is_empty(), "the same run is booked once")
	var runs: Array[Dictionary] = RunChronicle.runs()
	assert_eq(runs.size(), 1)
	assert_eq(str(runs[0].starter), "Kindlop")
	assert_eq(int(runs[0].difficulty), int(GameState.Difficulty.VETERAN))
	assert_eq(int(runs[0].play_time), 3725)
	assert_string_contains(RunChronicle.line(runs[0]), "1:02")

func test_chronicle_outlives_a_deleted_slot() -> void:
	_finish("Zippit")
	RunChronicle.note()
	assert_ne(RunChronicle.path, SaveManager.slot_path)
	assert_false(RunChronicle.path in SaveManager.save_paths(SaveManager.slot_path))
	GameState.new_game(GameState.Difficulty.TAMER, "Ada", 0, "Kindlop")
	assert_eq(RunChronicle.runs().size(), 1, "a new game keeps old runs")

func test_three_ways_badge() -> void:
	for sp: String in ["Kindlop", "Zippit", "Kindlop"]:
		_finish(sp)
		RunChronicle.note()
	assert_eq(RunChronicle.starters_done(), 2)
	assert_false(Achievements.earned("three_ways"))
	_finish("Wickit")
	RunChronicle.note()
	assert_eq(RunChronicle.starters_done(), 3)
	assert_true(Achievements.earned("three_ways"))

func test_oath_and_vows_have_glyphs() -> void:
	_finish("Kindlop", true)
	GameState.records["vows"] = {"no_shop": "kept"}
	RunChronicle.note()
	var line: String = RunChronicle.line(RunChronicle.runs()[0])
	assert_true(line.begins_with(SaveManager.OATH_GLYPH + RunChronicle.VOW_GLYPH), line)
	assert_true(PixelFont.GLYPHS.has(RunChronicle.VOW_GLYPH), "the knot glyph exists")
	var all: String = "\n".join(RunChronicle.lines())
	assert_string_contains(all, Loc.t("Vows kept: %d") % 1)

func test_empty_chronicle_text() -> void:
	assert_string_contains("\n".join(RunChronicle.lines()), Loc.t("No journey has reached the end of Act I yet."))
