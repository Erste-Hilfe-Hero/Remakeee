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
