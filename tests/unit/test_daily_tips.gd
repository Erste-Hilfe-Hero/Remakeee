extends GutTest
## Find of the day and first-time tips.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.tips_enabled = true

func test_pick_is_stable_and_a_visitor() -> void:
	var a: Dictionary = DailyFind.pick("2026-11-01")
	assert_eq(a, DailyFind.pick("2026-11-01"))
	assert_true(str(a.table) in EncounterTable.table_ids())
	assert_false(str(a.species) in EncounterTable.species_on(str(a.table)), "the visitor shouldn't normally live there")
	var days: Dictionary = {}
	for d: int in range(1, 29):
		days[str(DailyFind.pick("2026-02-%02d" % d))] = true
	assert_gt(days.size(), 4, "picks should vary across a month")

func test_spawns_once_per_day_only_in_its_area() -> void:
	var day: String = "2026-11-01"
	var p: Dictionary = DailyFind.pick(day)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var flags: Dictionary = {}
	var other: String = ""
	for t: String in EncounterTable.table_ids():
		if t != str(p.table):
			other = t
	for i: int in 50:
		assert_null(DailyFind.maybe_spawn(other, flags, rng, day))
	var s: Spirling = null
	for i: int in 100:
		s = DailyFind.maybe_spawn(str(p.table), flags, rng, day)
		if s != null:
			break
	assert_not_null(s)
	assert_eq(s.data.species_name, str(p.species))
	assert_eq(s.level, int(p.level))
	for key: String in s.spark:
		assert_gte(s.spark[key], DailyFind.SPARK_FLOOR)
	for i: int in 100:
		assert_null(DailyFind.maybe_spawn(str(p.table), flags, rng, day), "only once a day")
	assert_string_contains(DailyFind.hint(flags, day), "met")

func test_tips_show_once_and_can_be_switched_off() -> void:
	assert_false(Tips.take("battle").is_empty())
	assert_true(Tips.take("battle").is_empty())
	GameState.tips_enabled = false
	assert_true(Tips.take("bond").is_empty())
	GameState.tips_enabled = true
	assert_false(Tips.take("bond").is_empty())
	assert_true(Tips.take("no_such_tip").is_empty())

func test_tips_setting_round_trip() -> void:
	GameState.settings_from_dict({"tips": false})
	assert_false(GameState.tips_enabled)
	assert_false(bool(GameState.settings_to_dict().tips))
	GameState.settings_from_dict({})
	assert_true(GameState.tips_enabled)
