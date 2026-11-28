extends GutTest
## Plan area 8, P2 batch: Echo melody, new Spirling and rare visitor tasks, and one progress
## test for every task in data/events.json (plan 3171).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	for m: String in ["lighthouse", "brindlewick", "fernstair", "crowcrest", "saltmarsh", "murk_hollow", "thornridge"]:
		DailyTasks.note_map(m)
	for m: String in ["brindlewick", "crowcrest", "fernstair"]:
		GameState.visit_rest(m, Vector2i(3, 3))

func after_each() -> void:
	Online.clock_offset = 0

func _force(id: String) -> void:
	GameState.daily_tasks = {"day": DailyTasks.day_key(), "tasks": [{"id": id, "n": 0}], "bonus": false}

func _maps() -> Array[String]:
	return DailyTasks.reached_maps()

## The game event that moves task [param t] one step, as the game sends it.
func _event_info(t: Dictionary, i: int) -> Dictionary:
	var info: Dictionary = {"map": str(t.get("map", "fernstair")), "wild": bool(t.get("wild", true)),
		"elements": [str(t.get("element", "EMBER"))], "night": bool(t.get("night", false))}
	if bool(t.get("distinct", false)):
		info["map"] = "place_%d" % i
		info["key"] = "place_%d" % i
	return info

func test_every_task_counts_its_event() -> void:
	GameState.set_flag(GameState.ACT1_END_FLAG)
	for t: Dictionary in DailyTasks.defs():
		_force(str(t.id))
		var need: int = int(t.get("n", 1))
		if bool(t.get("distinct", false)):
			for i: int in need:
				DailyTasks.record(str(t.event), _event_info(t, i))
		else:
			DailyTasks.record(str(t.event), _event_info(t, 0), need - 1)
			assert_false(DailyTasks.all_done(), "%s is not done one short" % t.id)
			DailyTasks.record(str(t.event), _event_info(t, 0))
		assert_true(DailyTasks.all_done(), "%s is done by its event" % t.id)

func test_melody_good_or_better() -> void:
	_force("melody_good")
	assert_true(DailyTasks.doable(DailyTasks.def("melody_good"), _maps(), DailyTasks.reachable_elements(_maps())))
	DailyTasks.record("melody", {"map": "fernstair"})
	assert_true(DailyTasks.all_done())
	assert_almost_eq(DailyTasks.MELODY_GOOD, Overworld.ECHO_SONG_PASS, 0.001, "same mark in and out of battle")

func test_new_spirling_only_while_unseen_kinds_are_reachable() -> void:
	var t: Dictionary = DailyTasks.def("see_new")
	var els: Array[String] = DailyTasks.reachable_elements(_maps())
	var unseen: Array[String] = DailyTasks.unseen_reachable(_maps())
	assert_false(unseen.is_empty())
	assert_true(DailyTasks.doable(t, _maps(), els))
	_force("see_new")
	DailyTasks.note_seen(unseen[0], "fernstair")
	GameState.mark_seen(unseen[0])
	assert_true(DailyTasks.all_done(), "seeing a new kind counts")
	for sp: String in DailyTasks.unseen_reachable(_maps()):
		GameState.mark_seen(sp)
	assert_true(DailyTasks.unseen_reachable(_maps()).is_empty())
	assert_false(DailyTasks.doable(t, _maps(), els), "nothing left to see here")

func test_seeing_a_known_kind_again_does_not_count() -> void:
	var sp: String = DailyTasks.unseen_reachable(_maps())[0]
	GameState.mark_seen(sp)
	_force("see_new")
	DailyTasks.note_seen(sp, "fernstair")
	assert_false(DailyTasks.all_done())

func test_rare_visitor_task_follows_the_day() -> void:
	var t: Dictionary = DailyTasks.def("meet_daily_find")
	var els: Array[String] = DailyTasks.reachable_elements(_maps())
	var day: String = DailyTasks.day_key()
	var p: Dictionary = DailyFind.pick(day)
	assert_eq(DailyTasks.doable(t, _maps(), els, day), str(p.table) in _maps())
	var few: Array[String] = ["lighthouse"]
	assert_false(DailyTasks.doable(t, few, els, day), "not before its place is reached")
	_force("meet_daily_find")
	var rng := RandomNumberGenerator.new()
	var met: Spirling = null
	for i: int in 200:
		rng.seed = i
		met = DailyFind.maybe_spawn(str(p.table), GameState.flags, rng, day)
		if met != null:
			break
	assert_not_null(met)
	assert_true(DailyTasks.all_done(), "meeting the visitor counts")
