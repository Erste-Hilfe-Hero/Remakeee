extends GutTest
## Plan area 8, P2 batch: no notification ever advertises the daily tasks (3500), the Echo Path
## map with visited rooms and their kinds (3470) and 52 weekly layouts that are all walkable and
## can all be finished (3473).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	EchoPath.force_week = "2031-01-06"
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_all() -> void:
	EchoPath.force_week = ""

func _scripts(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		_scripts(dir.path_join(sub), out)

func test_no_notification_for_daily_tasks() -> void:
	var files: Array[String] = []
	_scripts("res://scripts", files)
	assert_gt(files.size(), 50)
	var notify := RegEx.create_from_string("(?i)(local_?notification|schedule_?notification|push_?notification|OS\\.request_permission|Notifications?\\.)")
	for path: String in files:
		var src: String = FileAccess.get_file_as_string(path)
		var m: RegExMatch = notify.search(src)
		if m != null:
			assert_false(src.contains("DailyTasks") or src.contains("daily_task"), "%s schedules notifications near the daily tasks" % path)
	assert_string_contains(FileAccess.get_file_as_string("res://scripts/core/DailyTasks.gd"), "never advertised by a notification")

func test_path_map_marks_visited_rooms() -> void:
	var lines: Array[String] = EchoPath.map_lines()
	assert_eq(lines.size(), EchoPath.ROOMS + 2, "a title, one line per room and the chest")
	assert_false("\n".join(lines.slice(1)).contains(Loc.t(EchoPath.KIND_NAMES[EchoPath.kind_of(1)])), "unvisited rooms keep their kind hidden")
	EchoPath.note_visit(EchoPath.slot_id(1))
	EchoPath.note_visit("fernstair")
	assert_string_contains(EchoPath.map_lines()[1], Loc.t(EchoPath.KIND_NAMES[EchoPath.kind_of(1)]))
	assert_true(EchoPath.map_lines()[1].begins_with("[ ]"))
	EchoPath.clear(2)
	assert_true(EchoPath.map_lines()[2].begins_with("[x]"), "a cleared room counts as visited")
	assert_string_contains(EchoPath.map_lines()[2], Loc.t(EchoPath.KIND_NAMES[EchoPath.kind_of(2)]))
	EchoPath.force_week = "2031-01-13"
	assert_false(EchoPath.is_visited(1), "a new week, a new map")

func test_menu_row_only_once_open() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/PauseMenu.gd")
	var at: int = src.find("\"Echo Path map...\"")
	assert_gt(at, 0)
	assert_gt(src.rfind("EchoPath.OPEN_FLAG", at), src.rfind("func ", at), "the row waits for the path to open")
	assert_string_contains(FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd"), "EchoPath.note_visit(map_id)")

func test_52_weeks_are_walkable_and_solvable() -> void:
	var ids: PackedStringArray = [EchoPath.FILE]
	for s: int in range(1, EchoPath.ROOMS + 2):
		ids.append(MapData.floor_id(EchoPath.FILE, s))
	var start: int = 1798761600 # a Monday in 2027
	for w: int in 52:
		EchoPath.force_week = WeeklyChallenge.week_key(start + w * 7 * 86400)
		var errors: PackedStringArray = []
		WorldValidator.check_reachability(errors, ids, EchoPath.FILE, EchoPath.ARRIVE_UP)
		var real: PackedStringArray = []
		for e: String in errors:
			if not e.contains("cinder_rift"):
				real.append(e)
		assert_eq(real, PackedStringArray(), EchoPath.force_week)
		for slot: int in range(1, EchoPath.ROOMS + 1):
			var t: Dictionary = EchoPath.template_for(slot)
			match str(t.get("kind", "")):
				"wild":
					assert_not_null(EchoPath.wild_for(slot), "%s room %d" % [EchoPath.force_week, slot])
				"echo":
					assert_eq(EchoPath.echo_team(slot).size(), EchoPath.ECHO_TEAM)
				"treasure":
					assert_true(Database.items.has(str(t.get("item", "tonic"))), str(t.get("item", "")))
		GameState.records["echo_path"] = {}
		for slot: int in range(1, EchoPath.ROOMS + 1):
			assert_true(EchoPath.clear(slot))
		var before: int = GameState.waymarks
		EchoPath.open_chest()
		assert_eq(GameState.waymarks, before + EchoPath.CHEST_WAYMARKS, EchoPath.force_week)
