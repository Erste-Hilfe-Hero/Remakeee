extends GutTest
## Plan area 6: the list pointer bobs 1 px sideways every 0.6 s while focus rests (item 2417).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false

func after_each() -> void:
	GameState.settings_from_dict(_saved)

func test_bob_rhythm() -> void:
	assert_eq(ListPicker.pointer_bob_at(0.1, false), 0)
	assert_eq(ListPicker.pointer_bob_at(0.5, false), 0, "rests for the first round")
	assert_eq(ListPicker.pointer_bob_at(0.65, false), 0)
	assert_eq(ListPicker.pointer_bob_at(0.95, false), 1, "out for the second half")
	assert_eq(ListPicker.pointer_bob_at(1.25, false), 0)
	assert_eq(ListPicker.pointer_bob_at(0.95, true), 0, "still under reduced motion")

func test_new_focus_restarts_the_bob() -> void:
	var lp := ListPicker.new()
	add_child_autofree(lp)
	var run := func() -> void: await lp.pick("T", [{"text": "A"}, {"text": "B"}] as Array[Dictionary])
	run.call()
	await get_tree().process_frame
	await get_tree().process_frame
	var rows: Array = lp.buttons()
	rows[0].grab_focus()
	await get_tree().process_frame
	lp._bob_pointer(0.95)
	assert_eq(lp._pointer_bob, 1)
	rows[1].grab_focus()
	await get_tree().process_frame
	assert_eq(lp._pointer_bob, 0, "moving the focus stops the bob")
	assert_lt(lp._pointer_idle, 0.3)
	lp.picked.emit(-1)
