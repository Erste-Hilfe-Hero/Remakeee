extends GutTest
## Plan area 8, P2 batch: festival task stages (plan 3220), yearly gifts (3221), the crier's
## next-festival line (3223) and the first-day hint (3226).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Online.clock_offset = 0

func test_gifts_change_each_year() -> void:
	for f: Dictionary in Season.festivals():
		var gifts: Array = f.get("gifts", [])
		assert_eq(gifts.size(), 4, str(f.id))
		for g: Variant in gifts:
			assert_false(Database.item(str(g)).is_empty(), str(g))
			assert_false(bool(Database.item(str(g)).get("shop", false)), "no shop goods as gifts")
		assert_ne(Season.gift_for(f, 2026), Season.gift_for(f, 2027))
		assert_eq(Season.gift_for(f, 2026), Season.gift_for(f, 2030), "the list comes round again")

func test_task_grows_with_years_celebrated() -> void:
	var f: Dictionary = Season.festivals()[0]
	assert_eq(Festival.task_stage(f, 2026), 0)
	GameState.set_flag(Season.gift_flag(f, 2024))
	GameState.set_flag(Season.gift_flag(f, 2026))
	assert_eq(Festival.task_stage(f, 2026), 1, "only earlier years count")
	GameState.set_flag(Season.gift_flag(f, 2025))
	GameState.set_flag(Season.gift_flag(f, 2023))
	assert_eq(Festival.task_stage(f, 2027), Festival.MAX_TASK_STAGE)

func test_next_line_names_month_and_elements() -> void:
	var line: String = Season.next_line(3)
	var nxt: Dictionary = Season.next_after(3)
	assert_string_contains(line, Loc.t(str(nxt.name)))
	assert_string_contains(line, Loc.t(Season.MONTH_NAMES[int(nxt.months[0]) - 1]))
	for e: String in Festival.element_names(nxt):
		assert_string_contains(line, e)

func test_start_hint_once_per_festival() -> void:
	var d: int = 0
	while Festival.active().is_empty() and d < 400:
		d += 10
		Online.clock_offset = d * 86400
	assert_false(Festival.active().is_empty(), "a festival within a year")
	var hint: String = Festival.start_hint()
	assert_string_contains(hint, Loc.t(str(Festival.active().fest.name)))
	assert_eq(Festival.start_hint(), "", "only once per festival")
