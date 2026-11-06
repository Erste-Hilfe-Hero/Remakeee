extends GutTest
## Plan area 8: festival data from file, ribbons, goal stages, crier task and the 1:1 settle.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _key() -> String:
	return str(Festival.active().get("key", ""))

func test_festivals_come_from_data() -> void:
	assert_eq(Season.festivals().size(), 4)
	for f: Dictionary in Season.festivals():
		assert_eq((f.elements as Array).size(), 2)
		assert_false((f.get("shop", []) as Array).is_empty(), str(f.id))
		for o: Variant in f.shop:
			assert_false(Database.item(str(o.item)).is_empty(), str(o.item))

func test_ribbons_for_wins_against_festival_elements() -> void:
	if Festival.active().is_empty():
		pass_test("no festival this month")
		return
	var els: Array = Festival.active().fest.elements
	var on: String = Elements.E.keys()[int(els[0])]
	var off: String = ""
	for e: String in Elements.E.keys():
		if not Elements.E[e] in els:
			off = e
			break
	DailyTasks.record("win", {"map": "fernstair", "wild": true, "elements": [off]})
	assert_eq(Festival.ribbons(), 0)
	DailyTasks.record("win", {"map": "fernstair", "wild": true, "elements": [on]})
	assert_eq(Festival.ribbons(), Festival.RIBBONS_PER_WIN)

func test_goal_stages_pay_waymarks() -> void:
	if Festival.active().is_empty():
		pass_test("no festival this month")
		return
	Festival.add(30)
	assert_eq(int(GameState.festival_ribbons[_key()].stages), 2, "10 and 25 reached")
	assert_eq(GameState.waymarks, 2 * Festival.STAGE_WAYMARKS)
	Festival.add(200)
	assert_eq(int(GameState.festival_ribbons[_key()].stages), 5)
	assert_eq(GameState.waymarks, 5 * Festival.STAGE_WAYMARKS)

func test_old_festival_ribbons_become_waymarks() -> void:
	GameState.festival_ribbons["bloom_fair_2001"] = {"ribbons": 42, "earned": 60, "stages": 3, "task": {}}
	var lines: Array[String] = Festival.settle()
	assert_eq(GameState.waymarks, 42)
	assert_false(GameState.festival_ribbons.has("bloom_fair_2001"))
	assert_eq(lines.size(), 2)
	assert_eq(Festival.settle(), [] as Array[String], "only once")

func test_crier_task_once_a_day() -> void:
	if Festival.active().is_empty():
		pass_test("no festival this month")
		return
	var task: Dictionary = Festival.take_task()
	var t: Dictionary = Festival.task_def(str(task.id))
	assert_false(t.is_empty())
	var els: Array = Festival.active().fest.elements
	assert_true(Elements.E[str(t.element)] in els, "the task fits the festival")
	assert_eq(Festival.take_task(), task, "same task all day")
	for i: int in int(t.n):
		DailyTasks.record(str(t.event), {"map": "fernstair", "wild": true, "elements": [str(t.element)]})
	assert_true(bool(Festival.take_task().done))
	assert_gte(Festival.ribbons(), Festival.TASK_RIBBONS)

func test_draw_task_for_each_festival() -> void:
	for f: Dictionary in Season.festivals():
		var id: String = Festival.draw_task(f, "2026-11-06")
		assert_ne(id, "", str(f.id))
		assert_eq(id, Festival.draw_task(f, "2026-11-06"))

func test_shop_spends_ribbons() -> void:
	if Festival.active().is_empty():
		pass_test("no festival this month")
		return
	var o: Dictionary = Festival.shop()[0]
	assert_eq(Festival.buy(str(o.item)), "Not enough ribbons.")
	Festival.add(int(o.price))
	var left: int = Festival.ribbons() - int(o.price)
	assert_eq(Festival.buy(str(o.item)), "")
	assert_eq(Festival.ribbons(), left)

func test_ribbons_saved() -> void:
	GameState.festival_ribbons["tide_days_2026"] = {"ribbons": 7, "earned": 7, "stages": 0, "task": {}}
	var d: Dictionary = GameState.to_dict()
	GameState.from_dict(d)
	assert_eq(int(GameState.festival_ribbons["tide_days_2026"].ribbons), 7)

func test_tilda_in_brindlewick() -> void:
	var m: MapData = MapData.load_map("brindlewick")
	var found: bool = false
	for n: Dictionary in m.npcs:
		if str(n.id) == "festival_trader":
			found = true
			assert_true(m.is_walkable(Vector2i(int(n.x), int(n.y))))
	assert_true(found)
