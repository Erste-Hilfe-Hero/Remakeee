extends GutTest
## Plan item 1947: in storage a long press on a Spirling opens its summary.

const MAX_FRAMES: int = 200

var _pointer: bool

func before_each() -> void:
	_pointer = ListPicker.pointer_used

func after_each() -> void:
	ListPicker.pointer_used = _pointer
	GameState.in_game = false

func _menu() -> PauseMenu:
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	add_child_autofree(menu)
	return menu

## Opens a one-row list, holds the row for [param held_ms] and reports last_long.
func _hold(held_ms: int) -> bool:
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu.pick_strings("Test", ["One"] as Array[String])
		state.done = true
	runner.call()
	await wait_process_frames(2)
	ListPicker.pointer_used = true
	var now: int = Time.get_ticks_msec()
	menu.picker._opened_ms = now - 5000
	menu.picker._press_ms = now - held_ms
	menu.picker._on_row(0)
	await wait_process_frames(1)
	assert_true(state.done)
	return menu.picker.last_long

func test_a_long_hold_counts_as_long() -> void:
	assert_true(await _hold(ListPicker.LONG_PRESS_MS + 100))

func test_a_tap_is_not_long() -> void:
	assert_false(await _hold(80))

func test_long_press_in_a_box_opens_the_summary() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.ensure_boxes()
	GameState.storage.clear()
	GameState._store(Spirling.new(Database.species("Zippit"), 9), true)
	var menu := _menu()
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu._run_box(GameState.storage[0].box)
		state.done = true
	runner.call()
	var frames: int = 0
	var seen: int = 0
	var titles: Array[String] = []
	var summaries: int = 0
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
			summaries += 1
			view.closed.emit()
		elif menu._info_wait:
			if menu.screens_shown.has("summary"):
				summaries += 1
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			seen = menu.picks
			titles.append(menu.last_title)
			if titles.size() == 1:
				menu.picker.last_long = true
				menu.picker.picked.emit(PauseMenu.STORAGE_ROWS)
			else:
				menu.picker.picked.emit(-1)
	assert_true(state.done)
	assert_has(menu.screens_shown, "summary", "the hold opened the summary")
	assert_eq(titles.size(), 2, "back in the box after it, no options list in between")
