extends GutTest
## Plan item 1872: start menu rows with something new carry a dot until opened.

func after_each() -> void:
	MenuDots.mail_unread = 0
	GameState.in_game = false

func _fresh() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	MenuDots.mail_unread = 0
	MenuDots.baseline()

func test_a_fresh_baseline_shows_no_dots() -> void:
	_fresh()
	assert_eq(MenuDots.dotted(MenuDots.LABELS), [] as Array[String])

func test_new_spirlog_entry_dots_until_opened() -> void:
	_fresh()
	var unseen: SpirlingData = null
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		if not SpirlogBook.is_seen(GameState.spirlog, sd.species_name):
			unseen = sd
			break
	assert_not_null(unseen)
	GameState.spirlog[unseen.species_name] = {"seen": true}
	assert_true(MenuDots.has_new("Spirlog"))
	MenuDots.mark_seen("Spirlog")
	assert_false(MenuDots.has_new("Spirlog"))

func test_new_mail_dots_friends() -> void:
	_fresh()
	MenuDots.mail_unread = 2
	assert_true(MenuDots.has_new("Friends"))
	MenuDots.mark_seen("Friends")
	MenuDots.mail_unread = 1
	assert_false(MenuDots.has_new("Friends"), "reading mail never adds a dot")

func test_new_badge_dots_records() -> void:
	_fresh()
	GameState.menu_seen["Records"] = Achievements.unlocked().size() - 1
	assert_true(MenuDots.has_new("Records"))

func test_a_changed_goal_dots_goals() -> void:
	_fresh()
	GameState.menu_seen["Goals"] = 12345
	assert_true(MenuDots.has_new("Goals"))

func test_rows_carry_the_dot_in_each_layout() -> void:
	var labels: Array[String] = ["Team", "Spirlog"]
	var plain: Array[Dictionary] = EraMenuKit.pause_entries(labels, false, EraMenus.layout(1, "pause"), ["Spirlog"] as Array[String])
	assert_string_ends_with(str(plain[1].text), "!")
	assert_eq(str(plain[1].say), "new")
	var icons: Array[Dictionary] = EraMenuKit.pause_entries(labels, false, EraMenus.layout(3, "pause"), ["Spirlog"] as Array[String])
	assert_eq(icons[1].icon, Goals.dot())
	assert_false(icons[0].has("say"))

func test_the_save_keeps_what_was_seen() -> void:
	_fresh()
	GameState.menu_seen["Spirlog"] = 7
	var d: Dictionary = GameState.to_dict()
	GameState.menu_seen.clear()
	GameState.from_dict(d)
	assert_eq(int(GameState.menu_seen.get("Spirlog", -1)), 7)
