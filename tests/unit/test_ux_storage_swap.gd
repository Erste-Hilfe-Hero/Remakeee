extends GutTest
## Plan items 1945 (sort and filter switches in the title row) and 1946 (swap in one step).

const MAX_FRAMES: int = 160

func after_each() -> void:
	GameState.in_game = false

func _fill() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.ensure_boxes()
	GameState.storage.clear()
	GameState._store(Spirling.new(Database.species("Zippit"), 9), true)

func test_swap_puts_the_stored_one_in_the_team_slot() -> void:
	_fill()
	GameState._store(Spirling.new(Database.species("Zippit"), 4), true)
	var leader: Spirling = GameState.party[0]
	var incoming: Spirling = GameState.storage[1]
	incoming.box = 1
	var team_size: int = GameState.party.size()
	assert_eq(PauseMenu.swap_with_team(1, 0), "")
	assert_eq(GameState.party[0], incoming, "same slot, the leader's")
	assert_eq(GameState.party.size(), team_size)
	assert_true(GameState.storage.has(leader))
	assert_eq(leader.box, 1, "the team one goes into the stored one's box")
	assert_eq(GameState.storage.size(), 2)

func test_swap_works_with_a_single_team_member_and_full_storage() -> void:
	_fill()
	assert_eq(GameState.party.size(), 1)
	assert_eq(PauseMenu.swap_with_team(0, 0), "", "no room is needed, one goes and one comes")

func test_swap_refuses_bad_slots() -> void:
	_fill()
	assert_false(PauseMenu.swap_with_team(5, 0).is_empty())
	assert_false(PauseMenu.swap_with_team(0, 9).is_empty())

func test_box_has_sort_and_filter_switches_in_the_title_row() -> void:
	_fill()
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	add_child_autofree(menu)
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu._run_box(GameState.storage[0].box)
		state.done = true
	runner.call()
	var frames: int = 0
	var seen: int = 0
	var lists: Array = []
	var switches: int = 0
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		if menu._info_wait:
			menu._page_turn = -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			seen = menu.picks
			lists.append(menu.last_rows.duplicate())
			if lists.size() == 1:
				var head: Control = menu.picker.header()
				for id: String in ["sort_toggle", "filter_toggle"]:
					if head != null and head.find_child(id, true, false) != null:
						switches += 1
				menu.picker.picked.emit(PauseMenu.SORT_PICKED)
			elif lists.size() == 2:
				menu.picker.picked.emit(PauseMenu.FILTER_PICKED)
			else:
				menu.picker.picked.emit(-1)
	assert_true(state.done)
	assert_eq(switches, 2)
	assert_false(str(lists[0][0]).begins_with("Sort"), "no sort row in the list")
	assert_eq(lists[0].size(), PauseMenu.STORAGE_ROWS + 1, "three rows, then the Spirling")
	assert_eq(menu._storage_sort, 1, "the sort switch moved on")
	assert_eq(menu._storage_element, 0, "the filter switch moved on")
	assert_null(menu.picker.header(), "the switches leave with the list")
