extends GutTest
## Plan area 8, P2 batch: festival ribbons turn into Waymarks even weeks after the festival
## (3546), the season path across a season change and its 14-day catch-up (3548) and loading a
## save full of endgame data in under a second (3550).

const TEST_SLOT: String = "user://test_endgame_p2y.json"

var _old_slot: String

func before_all() -> void:
	Database.load_all()
	_old_slot = SaveManager.slot_path
	SaveManager.slot_path = TEST_SLOT

func after_all() -> void:
	SaveManager.delete_save()
	SaveManager.slot_path = _old_slot
	Online.clock_offset = 0

func before_each() -> void:
	Online.clock_offset = 0
	SaveManager.delete_save()
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Online.clock_offset = 0

## Days from now until [param want] holds (or -1 within two years).
func _days_until(want: Callable) -> int:
	for i: int in 730:
		Online.clock_offset = i * 86400
		if want.call():
			return i
	return -1

func test_festival_ribbons_become_waymarks_weeks_later() -> void:
	var start: int = _days_until(func() -> bool: return not Festival.active().is_empty())
	assert_gte(start, 0, "a festival runs within two years")
	var key: String = str(Festival.active().key)
	Festival.add(7)
	Festival.spend(2)
	assert_eq(Festival.ribbons(), 5)
	assert_true(SaveManager.save_game())
	# The player closes the game and only opens it six weeks after the festival is over.
	var end: int = _days_until(func() -> bool: return str(Festival.active().get("key", "")) != key)
	Online.clock_offset += 42 * 86400
	assert_gt(end, start)
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	assert_true(SaveManager.load_game())
	assert_true(GameState.festival_ribbons.has(key), "the ribbons came back with the save")
	var before: int = GameState.waymarks
	var text: String = "\n".join(Festival.settle())
	assert_string_contains(text, "5")
	assert_eq(GameState.waymarks, before + 5, "1:1, nothing lost to the long break")
	assert_false(GameState.festival_ribbons.has(key))
	assert_eq(Festival.settle().size(), 0, "paid once")

func test_open_settles_ended_festivals() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	var at: int = src.find("func announce_achievements")
	assert_gt(at, 0)
	assert_gt(src.find("Festival.settle()", at), at, "the first screen after opening settles ribbons")

func test_season_change_keeps_paid_steps_and_starts_fresh() -> void:
	var first: String = SeasonPath.season_key()
	for i: int in 30:
		SeasonPath.add("weekly")
	var steps: int = SeasonPath.tier()
	assert_gt(steps, 0)
	assert_eq(int(SeasonPath.state().claimed), steps, "every reached step is paid at once")
	var paid: int = GameState.waymarks
	var money: int = GameState.money
	# Two weeks into the next season: nothing waits to be caught up, nothing is taken back.
	var change: int = _days_until(func() -> bool: return SeasonPath.season_key() != first)
	assert_gt(change, 0)
	Online.clock_offset += 14 * 86400
	assert_eq(int(SeasonPath.state().points), 0, "the new season starts at 0")
	assert_eq(int(SeasonPath.state().claimed), 0)
	assert_eq(GameState.waymarks, paid)
	assert_eq(GameState.money, money)
	# The new season pays its own steps again.
	for i: int in 30:
		SeasonPath.add("weekly")
	assert_eq(SeasonPath.tier(), steps)
	assert_gt(GameState.waymarks, paid)

func test_clock_set_back_keeps_the_new_season() -> void:
	var first: String = SeasonPath.season_key()
	var change: int = _days_until(func() -> bool: return SeasonPath.season_key() != first)
	SeasonPath.add("weekly")
	var pts: int = int(SeasonPath.state().points)
	assert_gt(pts, 0)
	Online.clock_offset = (change - 1) * 86400
	assert_eq(int(SeasonPath.state().points), pts, "a clock set back does not wipe the season")

func _fill_endgame() -> void:
	for i: int in Waymarks.LOG_MAX + 20:
		Waymarks.earn(5, "daily_task")
	for i: int in 40:
		GameState.festival_ribbons["fest_%d" % i] = {"ribbons": 0, "earned": 200, "stages": 5, "task": {}}
	var arts: Array[String] = Collection.learnable_arts()
	for a: String in arts:
		Collection.note_art(a)
	var rec: Dictionary = GameState.records
	var log: Array = []
	for i: int in 10:
		log.append({"uid": "u%d" % i, "map": "fernstair", "coins": 50, "item": "", "xp": 30})
	rec["expedition_log"] = log
	var album: Dictionary = {}
	for m: int in range(1, 13):
		album["2026-%02d" % m] = {"fields": {}, "done": true}
	rec["album"] = album
	var memorial: Array = []
	for i: int in 50:
		memorial.append({"name": "Spirling %d" % i, "species": "Kindlop", "level": 40, "day": "2026-01-01"})
	rec["memorial"] = memorial
	for i: int in 150:
		var s := Spirling.new(Database.species("Kindlop"), 30)
		s.uid = "box%d" % i
		GameState.storage.append(s)

func test_full_endgame_save_loads_in_under_a_second() -> void:
	_fill_endgame()
	assert_true(SaveManager.save_game())
	var size: int = FileAccess.get_file_as_string(TEST_SLOT).length()
	assert_gt(size, 50000, "the save really is full")
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var t0: int = Time.get_ticks_usec()
	assert_true(SaveManager.load_game())
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	gut.p("full endgame save: %d bytes, loaded in %.1f ms" % [size, ms])
	assert_lt(ms, 1000.0)
	assert_eq(GameState.storage.size(), 150)
	assert_eq((GameState.records.waymark_log as Array).size(), Waymarks.LOG_MAX)
