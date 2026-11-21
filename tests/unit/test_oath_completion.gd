extends GutTest
## Plan area 8: Iron Oath extras (chain mark, memorial book, Waymark bonus) and the
## "Journey complete" percentage.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_oath_pays_a_quarter_more_waymarks() -> void:
	Waymarks.earn(20, "daily_task")
	assert_eq(GameState.waymarks, 20)
	GameState.iron_oath = true
	var r: Dictionary = Waymarks.earn(20, "daily_task")
	assert_eq(int(r.bonus), 5)
	assert_eq(GameState.waymarks, 45)
	Masters.win(str(Masters.list()[0].id))
	assert_eq(GameState.waymarks, 45 + Masters.FIRST_WAYMARKS * 5 / 4)

func test_memorial_book_lists_retired_spirlings() -> void:
	GameState.iron_oath = true
	GameState.current_map = "fernstair"
	var s: Spirling = GameState.party[0]
	s.hp = 0
	var names: Array[String] = GameState.retire_fainted()
	assert_eq(names.size(), 1)
	var book: Array = GameState.records["memorial"]
	assert_eq(book.size(), 1)
	assert_eq(int(book[0].level), s.level)
	assert_eq(str(book[0].map), "fernstair")
	var lines: Array[String] = PauseMenu.memorial_lines()
	assert_eq(lines.size(), 1)
	assert_string_contains(lines[0], s.display_name())
	GameState.records["memorial"] = "broken"
	assert_eq(PauseMenu.memorial_lines().size(), 0, "a damaged book shows nothing")

func test_save_slot_line_shows_chain_under_oath() -> void:
	var d: Dictionary = GameState.to_dict()
	assert_false(SaveManager.summary_line(d).begins_with(SaveManager.OATH_GLYPH))
	GameState.iron_oath = true
	d = GameState.to_dict()
	assert_true(SaveManager.summary_line(d).begins_with(SaveManager.OATH_GLYPH))
	assert_true(PixelFont.GLYPHS.has(SaveManager.OATH_GLYPH), "the chain is drawn in the pixel font")

func test_oathkeeper_has_three_steps() -> void:
	var tiers: Array = []
	for a: Dictionary in Achievements.list():
		if str(a.get("group", "")) == "oath":
			tiers.append(str(a.tier))
	assert_eq(tiers.size(), 3)

func test_completion_weights_and_range() -> void:
	var sum: int = 0
	for k: String in Completion.WEIGHTS:
		sum += int(Completion.WEIGHTS[k])
	assert_eq(sum, 100)
	var start: int = Completion.percent()
	assert_between(start, 0, 10, "a new journey is barely started")
	# The story counts as done once the last main goal is reached (its flags set).
	var goals: Array = QuestLog.main_goals()
	for f: Variant in (goals[goals.size() - 1] as Dictionary).get("done", []):
		GameState.set_flag(str(f))
	assert_gte(Completion.percent(), start + 19, "the story is worth 20 percent")
	for sd: SpirlingData in Database.spirlings.values():
		GameState.spirlog[sd.species_name] = {"seen": true, "bonded": true}
	GameState.set_flag("gauntlet_clear")
	# Towers count the stair and both Rift towers alike.
	for t: Dictionary in RiftTower.list():
		GameState.records["rift_" + str(t.id)] = RiftTower.floors(t)
	assert_gte(Completion.percent(), start + 59)
	assert_lte(Completion.percent(), 100)
	assert_string_contains(PauseMenu.records_text(), "Journey complete")
