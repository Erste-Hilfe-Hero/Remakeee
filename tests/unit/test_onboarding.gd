extends GutTest
## Onboarding pass (first 15 minutes): no text walls in tips, the bonding tutorial paced and in
## the words of the bonding style, the goals tip even with tips off, "First steps" in Goals
## (item 1995), tips reset (item 1998), partner hints and the first-start settings hint (2000).

const ROW_TEXT_WIDTH: int = 115

var _flags: Dictionary
var _tips_on: bool
var _style: String

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_flags = GameState.flags.duplicate()
	_tips_on = GameState.tips_enabled
	_style = GameState.bond_style
	GameState.flags.clear()
	GameState.notices.clear()
	GameState.tips_enabled = true

func after_each() -> void:
	GameState.flags = _flags
	GameState.tips_enabled = _tips_on
	GameState.bond_style = _style
	GameState.notices.clear()
	Loc.set_language("en")

func _width(text: String) -> float:
	return PixelFont.get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x

# --- Tips: short, paced, right words --------------------------------------------------

func test_no_tip_is_a_wall_of_text() -> void:
	for id: String in Tips.LINES:
		for touch: bool in [true, false]:
			assert_between(Tips.lines_of(id, touch).size(), 1, Tips.MAX_LINES, id)
		assert_true(Tips.TOPICS.has(id), id + " is in the Guide")

func test_first_wild_battle_starts_with_few_lines() -> void:
	# Before the first order: the Energy tip and bonding steps 1 and 2 only.
	var n: int = Tips.take("battle").size() + Tips.take("bond").size()
	assert_lte(n, 5)
	var start: String = "\n".join(Tips.lines_of("bond"))
	assert_false(start.contains("step 3"), "steps 3 and 4 wait until Bond is picked")

func test_bond_how_follows_the_bonding_style() -> void:
	assert_eq(Tips.bond_how_id("mine"), "bond_mine")
	assert_eq(Tips.bond_how_id("echo"), "bond_echo")
	GameState.bond_style = "echo"
	assert_eq(Tips.bond_how_id(), "bond_echo")
	var echo: String = "\n".join(Tips.lines_of("bond_echo", true))
	assert_false(echo.contains("Mine!"), "echo players are not told to tap Mine!")
	assert_string_contains(echo, "repeat")
	for id: String in ["bond_mine", "bond_echo"]:
		var all: String = "\n".join(Tips.lines_of(id, true))
		assert_string_contains(all, "step 3")
		assert_string_contains(all, "step 4")
		assert_string_contains(all, "Kin Charm")

func test_goals_tip_shows_even_with_tips_off() -> void:
	GameState.tips_enabled = false
	assert_true(Tips.take("menu").is_empty())
	assert_false(Tips.take("goals").is_empty(), "nobody is left without a goal (item 2009)")
	assert_true(Tips.take("goals").is_empty(), "still only once")

func test_goals_tip_follows_the_input() -> void:
	assert_string_contains(Tips.lines_of("goals", true)[0], "Tap =")
	assert_string_contains(Tips.lines_of("goals", false)[0], "Press Start")

func test_tips_reset_brings_tips_back_and_keeps_other_flags() -> void:
	GameState.set_flag("got_starter")
	Tips.take("save")
	Tips.take("menu")
	assert_eq(Tips.seen().size(), 2)
	assert_eq(Tips.reset(), 2)
	assert_eq(Tips.seen(), [] as Array[String])
	assert_true(GameState.has_flag("got_starter"), "story flags stay")
	assert_false(Tips.take("save").is_empty(), "the tip shows again")

# --- First steps (item 1995) ----------------------------------------------------------

func test_first_steps_tick_themselves_off() -> void:
	assert_eq(FirstSteps.done_count(GameState.flags), 0)
	assert_eq(FirstSteps.next_step(GameState.flags), "Open the menu")
	var finished: int = 0
	for s: Array in FirstSteps.STEPS:
		if FirstSteps.tick(str(s[0])):
			finished += 1
	assert_eq(finished, 1, "only the last tick finishes the list")
	assert_true(FirstSteps.all_done(GameState.flags))
	assert_has(GameState.notices, FirstSteps.DONE_LINE)
	assert_false(FirstSteps.tick(FirstSteps.SAVED), "a done list stays done")
	assert_eq(GameState.notices.count(FirstSteps.DONE_LINE), 1)

func test_first_steps_menu_step_is_the_menu_hint_flag() -> void:
	assert_eq(str(FirstSteps.STEPS[0][0]), VirtualPad.MENU_SEEN_FLAG)

func test_first_steps_row_in_goals_for_newcomers_only() -> void:
	var flags: Dictionary = {"aldo_gift": true, FirstSteps.SAVED: true}
	var rows: Array[Dictionary] = PauseMenu.goal_rows(flags, "", true)
	assert_eq(str(rows[1].text), "First steps 1/5", "right under the main goal")
	assert_string_contains(str(rows[1].detail), "[x] Save your journey")
	assert_string_contains(str(rows[1].detail), "[ ] Open the menu")
	assert_eq(str(rows[1].hint), "Open the menu")
	for r: Dictionary in PauseMenu.goal_rows(flags, "", false):
		assert_false(str(r.text).begins_with("First steps"), "seasoned players do not see it")
	for s: Array in FirstSteps.STEPS:
		flags[s[0]] = true
	for r: Dictionary in PauseMenu.goal_rows(flags, "", true):
		assert_false(str(r.text).begins_with("First steps"), "gone once all are done")

# --- Partner pick and first start -----------------------------------------------------

func test_partner_rows_have_a_hint_each() -> void:
	var rows: Array[Dictionary] = Overworld.starter_rows()
	assert_eq(rows.size(), Database.STARTERS.size())
	for i: int in rows.size():
		assert_string_contains(str(rows[i].text), Database.STARTERS[i])
		assert_false(str(rows[i].hint).is_empty(), Database.STARTERS[i])

func test_new_texts_have_german_and_fit_the_rows() -> void:
	var texts: Array[String] = [Overworld.STARTER_TITLE, FirstSteps.DONE_LINE, "First steps",
		PauseMenu.RESET_TIPS_ROW, PauseMenu.RESET_TIPS_DONE, TitleScreen.FIRST_START_HINT]
	texts.append_array(Overworld.STARTER_HINTS.values())
	for s: Array in FirstSteps.STEPS:
		texts.append(str(s[1]))
	for id: String in ["bond", "bond_mine", "bond_echo", "goals"]:
		for touch: bool in [true, false]:
			texts.append_array(Tips.lines_of(id, touch))
	Loc.set_language("de")
	for t: String in texts:
		assert_ne(Loc.t(t), t, "German for: " + t)
	assert_eq(Loc.t("First steps %d/%d" % [2, 5]), "Erste Schritte 2/5")
	var rows: Array[String] = ["First steps 5/5", PauseMenu.RESET_TIPS_ROW]
	for r: Dictionary in Overworld.starter_rows():
		rows.append(str(r.text))
	for lang: String in ["en", "de"]:
		Loc.set_language(lang)
		for t: String in rows:
			assert_lte(_width(Loc.t(t)), float(ROW_TEXT_WIDTH), "%s row too wide: %s" % [lang, Loc.t(t)])
