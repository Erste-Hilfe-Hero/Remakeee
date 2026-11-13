extends GutTest
## Plan item 1992: the first time Team, Satchel and Spirlog open, a help line stands under the title.

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	GameState.in_game = false

func test_help_shows_once_per_screen() -> void:
	for screen: String in ["party", "bag", "dex"]:
		assert_false(MenuHost.first_help(screen).is_empty(), screen + " has help the first time")
		assert_eq(MenuHost.first_help(screen), "", screen + " is quiet the second time")
	assert_eq(MenuHost.first_help("pause"), "", "other screens have none")

func test_help_header_keeps_the_screen_header() -> void:
	var own := Label.new()
	own.name = "own"
	var box: Control = MenuHost.help_header("Tap a Spirling for details.", own)
	assert_not_null(box.find_child("help_line", true, false))
	assert_not_null(box.find_child("own", true, false))
	box.free()

func test_first_team_screen_shows_the_line() -> void:
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	add_child_autofree(menu)
	await wait_process_frames(1)
	var state: Dictionary = {"done": false, "line": "", "again": "x"}
	var runner := func() -> void:
		await menu.pick_screen("party", "Team", [{"text": "a"}] as Array[Dictionary])
		await menu.pick_screen("party", "Team", [{"text": "a"}] as Array[Dictionary])
		state.done = true
	runner.call()
	await wait_process_frames(2)
	var head: Control = menu.picker.header()
	var line: Label = head.find_child("help_line", true, false) as Label if head != null else null
	state.line = line.text if line != null else ""
	menu.picker.picked.emit(-1)
	await wait_process_frames(2)
	state.again = "" if menu.picker.header() == null else "header"
	menu.picker.picked.emit(-1)
	await wait_process_frames(2)
	assert_true(state.done)
	assert_eq(state.line, "Tap a Spirling for details.")
	assert_eq(state.again, "", "no help line the second time")
