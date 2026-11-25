extends GutTest
## Chimora 200 list items 31 (world map "last here"), 32 (way to the nearest rest point) and
## 41 (on-screen "Reset room" in boulder rooms).

func _room() -> MapData:
	return MapData.from_dict("t_room", {"name": "Test Room", "rows": [
		"WWWWfWWWW",
		"WfffffffW",
		"WfBfffPfW",
		"WfffBfffW",
		"WfffffPfW",
		"WffffkffW",
		"WWWWDWWWW"],
		"blocks": [{"x": 4, "y": 0, "open_flag": "t_room_open"}],
		"puzzles": [{"id": "plates", "flag": "t_room_open"}],
		"warps": [{"x": 4, "y": 6, "to": "brindlewick", "tx": 2, "ty": 5}]})

func test_reset_button_shows_after_a_push_until_solved() -> void:
	var m: MapData = _room()
	assert_false(PuzzleRoom.reset_offered(m), "nothing moved yet")
	PuzzleRoom.step(m, Vector2i(1, 2), Vector2i.RIGHT)
	assert_true(PuzzleRoom.reset_offered(m), "a boulder moved and the door is shut")
	PuzzleRoom.set_boulders(m, [Vector2i(6, 2), Vector2i(6, 4)])
	assert_false(PuzzleRoom.reset_offered(m), "solved: no reset to undo it by mistake")
	PuzzleRoom.reset(m, {})
	assert_false(PuzzleRoom.reset_offered(m), "back at the start")

func test_reset_button_in_a_room_without_plates() -> void:
	var m := MapData.from_dict("t_push", {"rows": ["WWWWW", "WfBfW", "WfffW", "WWWWW"]})
	PuzzleRoom.step(m, Vector2i(1, 1), Vector2i.RIGHT)
	assert_true(PuzzleRoom.reset_offered(m))
