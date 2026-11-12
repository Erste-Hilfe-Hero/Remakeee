extends GutTest
## Plan items 1878 (travel asks first), 1898 (free team slots) and 1903 (leader mark).

const MAX_FRAMES: int = 120

func after_each() -> void:
	GameState.in_game = false

func _menu() -> PauseMenu:
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	add_child_autofree(menu)
	return menu

## Answers the next [param answers].size() lists with these rows, then waits for the end.
func _answer(menu: PauseMenu, state: Dictionary, answers: Array) -> Array[String]:
	var titles: Array[String] = []
	var seen: int = 0
	var frames: int = 0
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		if menu.picks > seen and menu.picker.visible:
			seen = menu.picks
			titles.append(menu.last_title)
			menu.picker.picked.emit(int(answers.pop_front()) if not answers.is_empty() else -1)
	return titles

func _travel(answers: Array) -> Dictionary:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.visited_rests = {"fernstair": true, "mossgate": true}
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false, "result": false}
	var runner := func() -> void:
		state.result = await menu.run_travel()
		state.done = true
	runner.call()
	var titles: Array[String] = await _answer(menu, state, answers)
	return {"done": state.done, "result": state.result, "to": menu.travel_to, "titles": titles}

func test_travel_asks_with_the_place_name() -> void:
	var r: Dictionary = await _travel([0, 1])
	assert_true(r.done)
	assert_false(r.result, "Stay keeps the player here")
	assert_eq(r.to, "")
	assert_eq(r.titles.size(), 2, "a second list asks first")
	var place: String = MapData.load_map("mossgate").display_name if MapData.exists("mossgate") else "mossgate"
	assert_string_contains(r.titles[1], place)

func test_travel_goes_after_yes() -> void:
	var r: Dictionary = await _travel([0, 0])
	assert_true(r.result)
	assert_eq(r.to, "mossgate")

func test_team_list_shows_free_slots_up_to_five() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu.run_team()
		state.done = true
	runner.call()
	await _answer(menu, state, [-1])
	assert_true(state.done)
	assert_eq(menu.last_rows.size(), GameState.MAX_PARTY)
	assert_eq(menu.last_rows.count("free"), GameState.MAX_PARTY - GameState.party.size())

func test_free_row_is_grey_with_a_reason() -> void:
	var row: Dictionary = PauseMenu.free_slot_row()
	assert_true(row.disabled)
	assert_false(str(row.why).is_empty())

func test_leader_row_carries_its_mark() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	assert_true(MenuHost.party_entry(s, true).leader)
	assert_false(MenuHost.party_entry(s).leader)
	assert_string_contains(str(MenuHost.party_entry(s, true).hint), "Leads the team")
	assert_eq(str(MenuHost.party_entry(s, true).say), "leads the team")

func test_german_lead_option_is_clear() -> void:
	Loc.set_language("de")
	assert_eq(Loc.t("Lead the team"), "An die Spitze")
	Loc.set_language("en")

## Items 1873, 1875, 1879: the pause menu remembers its last entry, names the place and
## can save and end the session.
func _run_pause(answers: Array) -> Dictionary:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu.run()
		state.done = true
	runner.call()
	var titles: Array[String] = await _answer(menu, state, answers)
	return {"done": state.done, "menu": menu, "titles": titles}

func test_pause_title_names_the_place() -> void:
	var place: String = MapData.load_map("fernstair").display_name
	assert_string_contains(PauseMenu.menu_title("fernstair"), place)
	assert_false(PauseMenu.menu_title().contains("\n"))

func test_pause_menu_starts_on_the_last_entry() -> void:
	PauseMenu.last_label = ""
	var r: Dictionary = await _run_pause([1, -1, -1])
	assert_true(r.done)
	var labels: Array[String] = r.menu.last_rows
	assert_eq(PauseMenu.last_label, labels[1])
	PauseMenu.last_label = ""

func test_save_and_to_title_closes_the_menu() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false, "result": false}
	var runner := func() -> void:
		state.result = await menu.save_and_quit()
		state.done = true
	runner.call()
	# Without a server the game asks first; "To title" is the first answer.
	await _answer(menu, state, [0])
	assert_true(state.done)
	assert_true(state.result)
	assert_true(menu.to_title)

func test_staying_keeps_the_session() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false, "result": false}
	var runner := func() -> void:
		state.result = await menu.save_and_quit()
		state.done = true
	runner.call()
	var titles: Array[String] = await _answer(menu, state, [1])
	assert_true(state.done)
	if titles.is_empty():
		pass_test("saved on the server, nothing to ask")
		return
	assert_false(state.result)
	assert_false(menu.to_title)

## Items 1901, 1904: item rows show Vigor before and after, and the list stays open.
func test_vigor_preview_names_before_and_after() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	s.hp = 1
	var it: Dictionary = Database.item("tonic")
	var to: int = mini(s.max_hp(), 1 + int(it.heal))
	assert_eq(PauseMenu.vigor_preview(it, s), "Vigor 1/%d to %d/%d" % [s.max_hp(), to, s.max_hp()])
	s.hp = s.max_hp()
	assert_eq(PauseMenu.vigor_preview(it, s), "", "nothing to heal, no preview")
	assert_eq(PauseMenu.vigor_preview({"name": "Rope"}, s), "")

func test_item_list_stays_open_after_a_use() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	s.hp = 1
	GameState.add_item("tonic", 2)
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu._use_item_on(s)
		state.done = true
	runner.call()
	var frames: int = 0
	var lists: int = 0
	var seen: int = 0
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		if menu._info_wait:
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			seen = menu.picks
			lists += 1
			menu.picker.picked.emit(menu.last_rows.find("Tonic x%d" % GameState.item_count("tonic")) if lists == 1 else -1)
	assert_true(state.done)
	assert_eq(lists, 2, "the list opens again after the tonic")
	assert_gt(s.hp, 1)

## Item 1874: "=" or Start closes the pause menu from any level.
func test_menu_button_closes_from_a_deep_level() -> void:
	PauseMenu.last_label = ""
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu.run()
		state.done = true
	runner.call()
	var frames: int = 0
	var seen: int = 0
	var lists: int = 0
	var pressed: bool = false
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		if menu._info_wait and not pressed:
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible and not pressed:
			seen = menu.picks
			lists += 1
			if lists == 1:
				menu.picker.picked.emit(menu.last_rows.find("Team"))
			elif lists == 2:
				menu.picker.picked.emit(0)
			else:
				# Two levels deep (Team -> a Spirling): press the menu button once.
				var ev := InputEventAction.new()
				ev.action = GameState.MENU_ACTION
				ev.pressed = true
				menu._unhandled_input(ev)
				pressed = true
	assert_true(pressed, "reached a deep level")
	assert_true(state.done, "one press closed every level")
	assert_eq(menu.picks, seen, "no list opened again after the press")
	PauseMenu.last_label = ""
