extends GutTest
## Plan item 1918: things just gained carry a dot until their satchel row had the focus.

const MAX_FRAMES: int = 160

func after_each() -> void:
	GameState.in_game = false

func test_gaining_marks_new_and_save_keeps_it() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.new_items.clear()
	GameState.add_item("tonic", 1)
	assert_true(GameState.new_items.has("tonic"))
	var d: Dictionary = GameState.to_dict()
	GameState.new_items.clear()
	GameState.from_dict(d)
	assert_true(GameState.new_items.has("tonic"), "the mark survives a save")

func test_old_saves_have_nothing_new() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var d: Dictionary = GameState.to_dict()
	d.erase("new_items")
	GameState.from_dict(d)
	assert_true(GameState.new_items.is_empty())

func test_used_up_things_lose_the_mark_in_the_save() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.add_item("tonic", 1)
	GameState.take_item("tonic")
	var d: Dictionary = GameState.to_dict()
	assert_false("tonic" in (d.new_items as Array))

func test_focus_clears_the_mark() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.bag_sort = 0
	GameState.new_items.clear()
	GameState.add_item("tonic", 1)
	GameState.add_item("strong_tonic", 1)
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	add_child_autofree(menu)
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu.run_bag()
		state.done = true
	runner.call()
	var frames: int = 0
	var seen: int = 0
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		if menu._info_wait:
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			seen = menu.picks
			assert_true(GameState.new_items.has("tonic") or GameState.new_items.has("strong_tonic"), "marks show while unseen")
			# Move the focus over every row once.
			for i: int in menu.last_rows.size():
				menu.picker.row_focused.emit(i)
			menu.picker.picked.emit(-1)
	assert_true(state.done)
	assert_false(GameState.new_items.has("tonic"))
	assert_false(GameState.new_items.has("strong_tonic"))
