extends GutTest
## Owner report 13 Nov (iPhone, 1.1.0): after a battle the Wayfarer walks on by itself.
## A won battle sends its online steps (world goal, bonds, rift board); on a weak connection
## that call fails, Online goes OFFLINE and three seconds later the reconnect screen pauses the
## tree. A paused VirtualPad gets no _input, so the finger lifted from the D-pad meanwhile was
## never seen: the direction stayed pressed and the Wayfarer walked off when the game went on.

var _overlay: ReconnectOverlay

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	VirtualPad.force_visible = true
	VirtualPad.apply_settings()
	VirtualPad.set_wanted(true)
	_overlay = ReconnectOverlay.new()
	add_child_autofree(_overlay)

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

## The reconnect screen comes up (pausing the tree) and goes again once the connection is back.
func _connection_drop_while(lift: Callable) -> void:
	Online.in_battle = false
	_overlay.show_overlay()
	_overlay.update_view(1, 0.0, ReconnectOverlay.SHORT_DROP + 1.0)
	assert_true(get_tree().paused, "the big reconnect screen pauses the game")
	await wait_process_frames(2)
	lift.call()
	await wait_process_frames(2)
	_overlay.hide_overlay()
	assert_false(get_tree().paused)

func test_finger_lifted_under_the_reconnect_screen_lets_go_of_the_direction() -> void:
	_touch(_down_cell(), true)
	assert_eq(VirtualPad.held_dir(), "ui_down")
	assert_true(Input.is_action_pressed("ui_down"))
	await _connection_drop_while(func() -> void: _touch(_down_cell(), false))
	assert_eq(VirtualPad.held_dir(), "", "the pad holds no direction after the reconnect")
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

func test_tap_walk_does_not_go_on_after_the_reconnect() -> void:
	var ow: Overworld = await _overworld()
	ow.player.follow([Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)] as Array[Vector2i])
	await _connection_drop_while(func() -> void: pass)
	await wait_process_frames(2)
	assert_true(ow.player.path.is_empty(), "the tap walk is dropped like on leaving the app")
