extends GutTest
## Plan items 1919 (heal the same Spirling again), 1924 (battle-only mark) and 1927
## (focus stays on the used item).

const MAX_FRAMES: int = 160

func after_each() -> void:
	GameState.in_game = false

func _menu() -> PauseMenu:
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	add_child_autofree(menu)
	return menu

func test_battle_only_items_are_marked() -> void:
	assert_true(PauseMenu.battle_only(Database.item("remedy")))
	assert_true(PauseMenu.battle_only(Database.item("power_brew")))
	assert_false(PauseMenu.battle_only(Database.item("tonic")), "tonics also heal outside")
	assert_false(PauseMenu.battle_only({"name": "Rope"}))

func test_tonic_can_be_used_twice_in_a_row() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	s.hp = 1
	GameState.add_item("tonic", 3)
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu._use_on_party("tonic")
		state.done = true
	runner.call()
	var frames: int = 0
	var lists: int = 0
	var seen: int = 0
	var focus_second: int = -2
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		if menu._info_wait:
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			seen = menu.picks
			lists += 1
			if lists == 2:
				focus_second = menu.picker.focused_index()
			menu.picker.picked.emit(0 if lists <= 2 else -1)
	assert_true(state.done)
	assert_eq(lists, 3, "the list came back after each use until Back")
	assert_eq(GameState.item_count("tonic"), 1, "two tonics used")
	assert_eq(focus_second, 0, "the same Spirling keeps the focus")

func test_satchel_keeps_focus_on_the_used_item() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.party[0].hp = 1
	GameState.add_item("tonic", 2)
	GameState.add_item("strong_tonic", 1)
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu.run_bag()
		state.done = true
	runner.call()
	var frames: int = 0
	var seen: int = 0
	var step: int = 0
	var target: int = -1
	var focus_after: int = -2
	while not state.done and frames < MAX_FRAMES * 2:
		await wait_process_frames(1)
		frames += 1
		if menu._info_wait:
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			seen = menu.picks
			step += 1
			if menu.last_title == "Satchel" and target < 0:
				target = 0
				for i: int in menu.last_rows.size():
					if menu.last_rows[i].begins_with("Strong"):
						target = i
				menu.picker.picked.emit(target)
			elif menu.last_title == "Satchel":
				focus_after = menu.picker.focused_index()
				menu.picker.picked.emit(-1)
			elif step < 6:
				menu.picker.picked.emit(0 if step == 2 else -1)
			else:
				menu.picker.picked.emit(-1)
	assert_true(state.done)
	assert_gt(target, -1)
	assert_eq(focus_after, mini(target, menu.last_rows.size() - 1), "focus stays on the used item")

## Items 1921, 1923: Echo Crystal rows say why someone can't learn, forget rows show
## element, power and energy.
func test_echo_reason_names_the_cause() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	var reasons: Array[String] = []
	for id: String in ["echo_ember", "echo_tide", "echo_bloom"]:
		var why: String = PauseMenu.echo_reason(s, id)
		assert_eq(why.is_empty(), GameState.can_learn_echo(s, id), id)
		reasons.append(why)
	assert_true("Wrong element." in reasons, "a starter can't learn all three elements")

func test_echo_reason_for_a_known_art() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	var mv: MoveData = Database.move(str(Database.item("echo_ember").teaches))
	s.moves.append(mv)
	assert_eq(PauseMenu.echo_reason(s, "echo_ember"), "Already knows this art.")

func test_art_rows_show_element_power_energy() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var s: Spirling = GameState.party[0]
	var rows: Array[Dictionary] = PauseMenu.art_rows(s.moves)
	assert_eq(rows.size(), s.moves.size())
	assert_eq(rows[0].text, s.moves[0].move_name)
	assert_string_contains(str(rows[0].hint), "Energy %d" % s.moves[0].energy_cost)
	assert_string_contains(str(rows[0].hint), Elements.element_name(s.moves[0].element))

## Items 1900, 1925: keepsakes show their effect while focused, gear says where it works.
func test_gear_hint_names_the_places() -> void:
	var hint: String = PauseMenu.gear_hint("wading_boots")
	assert_string_contains(hint, "Works on its own at:")
	assert_string_contains(hint, "shallow water")

func test_keepsake_rows_show_the_effect() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var held: String = "bark_wrap"
	assert_true(BattleRules.is_holdable(held))
	GameState.add_item(held, 1)
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu._held_item(GameState.party[0])
		state.done = true
	runner.call()
	var frames: int = 0
	var hint: String = ""
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		if menu.picker.visible and menu.picks > 0 and hint.is_empty():
			hint = menu.picker.hint_text()
			menu.picker.picked.emit(-1)
	assert_true(state.done)
	assert_false(hint.is_empty(), "the focused keepsake shows its effect")
