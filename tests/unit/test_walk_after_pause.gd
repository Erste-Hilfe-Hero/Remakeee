extends GutTest
## Owner report 13 Nov (iPhone, 1.1.0): after a battle the Wayfarer walks on by itself.
## A won battle sends its online steps (world goal, bonds, rift board); on a weak connection
## that call fails and Online goes OFFLINE. The old reconnect screen then paused the tree, so the
## finger lifted from the D-pad meanwhile was never seen. Since docs/OFFLINE.md a drop pauses
## nothing: the pad sees every touch and walking simply goes on.

var _mark: OfflineMark

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	VirtualPad.force_visible = true
	VirtualPad.apply_settings()
	VirtualPad.set_wanted(true)
	_mark = OfflineMark.new()
	add_child_autofree(_mark)

func after_each() -> void:
	get_tree().paused = false
	VirtualPad.release_all()
	VirtualPad.set_wanted(false)
	VirtualPad.force_visible = false

func _touch(pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = pressed
	t.position = pos
	Input.parse_input_event(t)
	Input.flush_buffered_events()

func _down_cell() -> Vector2:
	return VirtualPad.dpad_rect().get_center() + Vector2(0, VirtualPad._dpad)

## The connection is gone for a while (the offline mark shows) and comes back.
func _connection_drop_while(lift: Callable) -> void:
	Online.in_battle = false
	_mark.update_view(OfflineMark.SHOW_AFTER + 1.0)
	assert_false(get_tree().paused, "offline pauses nothing")
	await wait_process_frames(2)
	lift.call()
	await wait_process_frames(2)
	_mark.hide_mark()
	assert_false(get_tree().paused)

func test_finger_lifted_while_offline_lets_go_of_the_direction() -> void:
	_touch(_down_cell(), true)
	assert_eq(VirtualPad.held_dir(), "ui_down")
	assert_true(Input.is_action_pressed("ui_down"))
	await _connection_drop_while(func() -> void: _touch(_down_cell(), false))
	assert_eq(VirtualPad.held_dir(), "", "the pad holds no direction after the drop")
	assert_false(Input.is_action_pressed("ui_down"), "nothing presses down any more")

func _overworld() -> Overworld:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	ow.load_map("brindlewick", Vector2i(5, 1), "down")
	ow.player.place(Vector2i(5, 1), "down")
	VirtualPad.set_wanted(true)
	return ow

func test_wayfarer_stands_still_after_the_reconnect() -> void:
	var ow: Overworld = await _overworld()
	_touch(_down_cell(), true)
	await wait_process_frames(3)
	assert_true(ow.player.moving, "walking down with the D-pad")
	await _connection_drop_while(func() -> void: _touch(_down_cell(), false))
	# GridWalker moves cell at the start of a step: this is where the step under way ends.
	var at: Vector2i = ow.player.cell
	await wait_seconds(1.0)
	assert_eq(ow.player.cell, at, "the Wayfarer does not walk on by itself")

func test_tap_walk_goes_on_through_a_drop() -> void:
	var ow: Overworld = await _overworld()
	ow.player.follow([Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)] as Array[Vector2i])
	await _connection_drop_while(func() -> void: pass)
	for i: int in 180:
		if ow.player.path.is_empty() and not ow.player.moving:
			break
		await wait_process_frames(1)
	assert_eq(ow.player.cell, Vector2i(5, 4), "the tap walk reached its end, nothing stopped it")
