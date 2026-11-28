extends GutTest
## Area 3 items 1016 and 1027: a wrong bell only starts the row again; three failed tries in a
## room unlock the tip on the hint board at the dungeon entrance.

const DUNGEONS: Array[String] = ["bellstone_ruins", "lanternwell", "brackwater_sluice", "shatterfloor_mine"]

var _snapshot: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_snapshot = GameState.to_dict()
	GameState.records.erase("room_fails")
	for d: String in DUNGEONS:
		GameState.flags.erase(DungeonHints.hint_flag(d))

func after_each() -> void:
	GameState.from_dict(_snapshot)

func test_every_dungeon_has_a_hint_board_at_the_entrance() -> void:
	for d: String in DUNGEONS:
		var m: MapData = MapData.load_map(d)
		var board: Dictionary = {}
		for s: Dictionary in m.signs:
			if str(s.dialogue) == d + "/hint_board":
				board = s
		assert_false(board.is_empty(), d)
		var e: Dictionary = Dialogue.get_entry(d + "/hint_board")
		var before: Array[String] = Dialogue.lines_for(e, {})
		var after: Array[String] = Dialogue.lines_for(e, {DungeonHints.hint_flag(d): true})
		assert_ne(before, after, "%s: the tip shows after the flag" % d)
		assert_true(after[0].begins_with("Tip: "), after[0])

func test_three_failed_tries_in_one_room_unlock_the_tip() -> void:
	assert_false(DungeonHints.note_fail("bellstone_ruins@1"))
	assert_false(DungeonHints.note_fail("bellstone_ruins@2"), "fails count per room")
	assert_false(DungeonHints.note_fail("bellstone_ruins@1"))
	assert_true(DungeonHints.note_fail("bellstone_ruins@1"))
	assert_true(GameState.has_flag("hint_bellstone_ruins"))
	assert_false(DungeonHints.note_fail("bellstone_ruins@1"), "unlocks once")
	assert_false(GameState.has_flag("hint_lanternwell"))

func test_a_wrong_bell_only_resets_the_row() -> void:
	var flag: String = "bell_room_test"
	GameState.flags.erase(flag)
	assert_eq(GameState.press_switch(flag, 1, 3), GameState.SwitchResult.STEP)
	assert_eq(GameState.press_switch(flag, 3, 3), GameState.SwitchResult.WRONG)
	assert_eq(int(GameState.switch_progress.get(flag, 0)), 0, "the row starts again")
	assert_false(GameState.has_flag(flag))
	assert_eq(GameState.press_switch(flag, 1, 3), GameState.SwitchResult.STEP)
	assert_eq(GameState.press_switch(flag, 2, 3), GameState.SwitchResult.STEP)
	assert_eq(GameState.press_switch(flag, 3, 3), GameState.SwitchResult.SOLVED)
	GameState.flags.erase(flag)
