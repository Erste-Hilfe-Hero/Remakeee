extends GutTest
## Plan items 1789 (hold a team or satchel row), 1966 (characters left) and 1972 (version).

const MAX_FRAMES: int = 200

func after_each() -> void:
	GameState.in_game = false

func _menu() -> PauseMenu:
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	add_child_autofree(menu)
	return menu

func test_counter_says_what_is_left() -> void:
	assert_eq(CharCounter.text_for("", 10), "10/10")
	assert_eq(CharCounter.text_for("Tessa1", 10), "4/10")
	assert_eq(CharCounter.text_for("ABCDEFGHIJKL", 10), "0/10")

func test_counter_follows_its_box() -> void:
	var edit := LineEdit.new()
	add_child_autofree(edit)
	var c: CharCounter = CharCounter.make(edit, 10)
	add_child_autofree(c)
	edit.text = "Pip"
	await wait_process_frames(2)
	assert_eq(c.text, "7/10")

func test_nickname_box_has_a_counter_but_email_does_not() -> void:
	var short := TextPrompt.new()
	add_child_autofree(short)
	short._build("Nickname", false, 10, "")
	assert_not_null(short.find_child("char_counter", true, false))
	var long := TextPrompt.new()
	add_child_autofree(long)
	long._build("Email", false, 64, "")
	assert_null(long.find_child("char_counter", true, false))

func test_version_label_is_small_and_names_the_version() -> void:
	var v: Label = TitleScreen.version_label()
	add_child_autofree(v)
	assert_eq(v.text, "v" + Online.CLIENT_VERSION_NAME)
	assert_eq(v.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)

func test_item_details_name_the_thing() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.add_item("tonic", 2)
	var d: String = PauseMenu.item_details("tonic")
	assert_string_contains(d, "x%d" % GameState.item_count("tonic"))
	assert_string_contains(d, str(Database.item("tonic").description))

func test_holding_a_team_row_opens_the_summary() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu.run_team()
		state.done = true
	runner.call()
	var frames: int = 0
	var seen: int = 0
	var titles: Array[String] = []
	var last_view: Object = null
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		var view: EraSummary = null
		for c: Node in menu.get_children():
			if c is EraSummary and not c.is_queued_for_deletion():
				view = c
		if view != null and view != last_view:
			last_view = view
			view.closed.emit()
		elif menu._info_wait:
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			seen = menu.picks
			titles.append(menu.last_title)
			if titles.size() == 1:
				menu.picker.last_long = true
				menu.picker.picked.emit(0)
			else:
				menu.picker.picked.emit(-1)
	assert_true(state.done)
	assert_has(menu.screens_shown, "summary")
	assert_eq(titles.size(), 2, "back in the team list, no options in between")

func test_holding_a_satchel_row_explains_instead_of_using() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.party[0].hp = 1
	GameState.add_item("tonic", 1)
	var before: int = GameState.item_count("tonic")
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu.run_bag()
		state.done = true
	runner.call()
	var frames: int = 0
	var seen: int = 0
	var lists: int = 0
	var infos: Array[String] = []
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		if menu._info_wait:
			infos.append(menu._info_source)
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			seen = menu.picks
			lists += 1
			if lists == 1 and menu.last_title == "Satchel":
				menu.picker.last_long = true
				menu.picker.picked.emit(menu.last_rows.find("Tonic x%d" % before))
			else:
				menu.picker.picked.emit(-1)
	assert_true(state.done)
	assert_eq(GameState.item_count("tonic"), before, "nothing was used")
	assert_true(infos.any(func(s: String) -> bool: return s.contains("x%d" % before)), "the details showed")
