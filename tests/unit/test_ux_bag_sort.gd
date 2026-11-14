extends GutTest
## Plan items 1917 (satchel order), 1938 (turning Spirlog pages) and 1939 (seen filter).

const MAX_FRAMES: int = 160

var _sort_before: int = 0

func before_each() -> void:
	_sort_before = GameState.bag_sort

func after_each() -> void:
	GameState.bag_sort = _sort_before
	GameState.in_game = false

func test_newest_first_reverses_the_order_things_came_in() -> void:
	assert_eq(PauseMenu.sort_bag(["tonic", "rope", "remedy"], 0), ["remedy", "rope", "tonic"])

func test_by_name_is_alphabetical() -> void:
	var ids: Array = ["tonic", "remedy", "strong_tonic"]
	var sorted: Array = PauseMenu.sort_bag(ids, 1)
	var names: Array[String] = []
	for id: Variant in sorted:
		names.append(str(Database.item(str(id)).name))
	var expect: Array[String] = names.duplicate()
	expect.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	assert_eq(names, expect)

func test_by_kind_follows_the_item_list() -> void:
	var order: Array = Database.items.keys()
	var ids: Array = [order[5], order[1], order[3]]
	assert_eq(PauseMenu.sort_bag(ids, 2), [order[1], order[3], order[5]])

func test_sort_does_not_change_its_input() -> void:
	var ids: Array = ["tonic", "remedy"]
	PauseMenu.sort_bag(ids, 0)
	assert_eq(ids, ["tonic", "remedy"])

func test_sort_switch_in_the_title_row_changes_and_keeps_the_order() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.bag_sort = 0
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
	var lists: Array = []
	var had_toggle: bool = false
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
				had_toggle = head != null and head.find_child("sort_toggle", true, false) != null
				menu.picker.picked.emit(PauseMenu.SORT_PICKED)
			else:
				menu.picker.picked.emit(-1)
	assert_true(state.done)
	assert_eq(lists.size(), 2, "the satchel opens again in the new order")
	assert_eq(GameState.bag_sort, 1, "New -> Name")
	assert_true(had_toggle, "the switch stands in the title row")
	assert_true(GameState.settings_to_dict().has("bag_sort"), "the choice is kept with the settings")

func test_settings_keep_the_bag_order() -> void:
	GameState.bag_sort = 2
	var d: Dictionary = GameState.settings_to_dict()
	GameState.bag_sort = 0
	GameState.settings_from_dict(d)
	assert_eq(GameState.bag_sort, 2)

func test_seen_filter_keeps_every_met_kind() -> void:
	var kinds: Array[SpirlingData] = SpirlogBook.visible_kinds({})
	var log: Dictionary = {}
	log[kinds[0].species_name] = {"seen": true}
	log[kinds[1].species_name] = {"seen": true, "bonded": true}
	var seen: Array[SpirlingData] = SpirlogBook.filtered(log, {}, "", -1, "", SpirlogBook.STATUS_SEEN)
	assert_eq(seen.size(), 2, "seen and bonded both count as seen")
	assert_eq(SpirlogBook.STATUS_NAMES[SpirlogBook.STATUS_SEEN], "seen")

func test_entry_page_turns_left_and_right_past_unseen_kinds() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var kinds: Array[SpirlingData] = SpirlogBook.visible_kinds(GameState.flags)
	GameState.spirlog = {}
	GameState.spirlog[kinds[0].species_name] = {"seen": true}
	GameState.spirlog[kinds[2].species_name] = {"seen": true}
	var page := SpirlogPage.new()
	page.kinds = kinds
	page.index = 0
	add_child_autofree(page)
	page._build()
	page._show()
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	page._unhandled_input(right)
	assert_eq(page.index, 2, "right skips the unseen kind")
	var left := InputEventAction.new()
	left.action = "ui_left"
	left.pressed = true
	page._unhandled_input(left)
	assert_eq(page.index, 0, "left goes back")
