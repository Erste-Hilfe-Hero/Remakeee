extends GutTest
## Bug sweep (2026-11-04): phone taps counted twice, info texts cut off, unfurling as a revive,
## a pearl lost by furling back, and two quick saves where the newer one never reached the server.

func _click(pressed: bool = true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e

func _touch(pressed: bool = true) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	return e

## What a phone delivers for one finger tap: the emulated click, then the touch itself.
func _finger(target: Callable, at: Vector2 = Vector2.ZERO) -> void:
	var c := _click()
	c.position = at
	var t := _touch()
	t.position = at
	target.call(c)
	target.call(t)

func test_touch_is_emulated_as_a_click() -> void:
	assert_true(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)),
		"TapInput relies on the default: every touch also arrives as a left click")
	assert_true(TapInput.is_press(_click()))
	assert_false(TapInput.is_press(_touch()), "the raw touch would count the same tap twice")
	assert_true(TapInput.is_release(_click(false)))
	assert_false(TapInput.is_release(_touch(false)))
	var right := _click()
	right.button_index = MOUSE_BUTTON_RIGHT
	assert_false(TapInput.is_press(right))

func test_one_finger_tap_is_one_echo_mark() -> void:
	var bm := BondMinigame.new()
	add_child_autofree(bm)
	bm.size = Vector2(144, 256)
	bm._sequence = [0, 1, 2, 1] as Array[int]
	bm._phase = BondMinigame.Phase.ECHO
	_finger(bm._gui_input, bm._mark_center(0))
	assert_eq(bm._taps, [0] as Array[int], "a single tap on the first mark")
	assert_eq(bm._phase, BondMinigame.Phase.ECHO, "still on track, the echo goes on")
	_finger(bm._gui_input, bm._mark_center(1))
	assert_eq(bm._taps, [0, 1] as Array[int])

func test_one_finger_tap_advances_text_once() -> void:
	var tb := TextBox.new()
	add_child_autofree(tb)
	var count: Array[int] = [0]
	tb.advanced.connect(func() -> void: count[0] += 1)
	tb._waiting = true
	_finger(tb._gui_input)
	assert_eq(count[0], 1)
	# While the next line types, one tap only finishes it.
	tb._typing = true
	tb._waiting = false
	_finger(tb._gui_input)
	assert_false(tb._typing)
	assert_false(tb._waiting, "the line is shown, the next tap moves on")

func test_long_info_text_scrolls_and_closes_on_a_tap() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	assert_true(host._info_label.get_parent() is ScrollContainer, "long texts scroll instead of running off screen")
	var done: Array[bool] = [false]
	var run := func() -> void:
		await host.info(AccountMenu.PRIVACY_NOTE)
		done[0] = true
	run.call()
	await wait_process_frames(1)
	assert_true(host._info_label.text.ends_with("(tap to continue)"))
	# A drag scrolls; it does not close.
	var down := _click()
	down.position = Vector2(50, 60)
	var up := _click(false)
	up.position = Vector2(50, 20)
	host._input(down)
	host._input(up)
	assert_false(done[0])
	up.position = Vector2(51, 61)
	# Long texts turn a page per tap (plan item 1838); the tap at the end closes it.
	for i: int in 30:
		if done[0]:
			break
		host._input(down)
		host._input(up)
		await wait_process_frames(1)
	assert_true(done[0], "a tap closes the text")

func test_info_text_is_translated() -> void:
	var before: String = Loc.language()
	Loc.set_language("de")
	var host := MenuHost.new()
	add_child_autofree(host)
	host.info(AccountMenu.PRIVACY_NOTE)
	await wait_process_frames(1)
	assert_true(host._info_label.text.begins_with("Chimora läuft nur online"), host._info_label.text.left(40))
	assert_true(host._info_label.text.ends_with(Loc.t("(tap to continue)")))
	host._close_info()
	Loc.set_language(before)

func test_unfurling_does_not_revive() -> void:
	var base: SpirlingData = Database.species("Kindlop")
	var s := Spirling.new(base, base.evolve_level)
	s.hp = 0
	s.evolve()
	assert_eq(s.data, base.evolves_to)
	assert_eq(s.hp, 0, "a resting Spirling stays at rest")

func test_furling_back_returns_the_unfurl_item() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 1, "Kindlop")
	var pup: SpirlingData = Database.species("Kelpup")
	assert_eq(pup.evolve_item, "tide_pearl")
	var s := Spirling.new(pup, 20)
	GameState.add_item("tide_pearl")
	assert_ne(GameState.use_item_outside_battle("tide_pearl", s), "")
	assert_eq(GameState.item_count("tide_pearl"), 0)
	GameState.furl_back(s)
	assert_eq(s.data, pup)
	assert_eq(GameState.item_count("tide_pearl"), 1, "the pearl comes back, so it can unfurl again")
	var kin := Spirling.new(Database.species("Kindlop").evolves_to, 20)
	GameState.furl_back(kin)
	assert_eq(GameState.item_count("tide_pearl"), 1, "ring unfurls give nothing back")

class SlowServer extends LocalBackend:
	func call_fn(name: String, args: Dictionary = {}) -> Dictionary:
		if name == "save_put":
			await (Engine.get_main_loop() as SceneTree).process_frame
			await (Engine.get_main_loop() as SceneTree).process_frame
		return super.call_fn(name, args)

func test_two_quick_saves_both_reach_the_server() -> void:
	var old_backend: OnlineBackend = Online.backend
	var old_state: Online.State = Online.state
	var old_revs: Dictionary = Online.revs.duplicate()
	var old_dirty: Dictionary = Online.dirty.duplicate()
	var kept: String = FileAccess.get_file_as_string(SaveManager.path_for_slot(3)) if FileAccess.file_exists(SaveManager.path_for_slot(3)) else ""
	var server := SlowServer.new()
	Online.backend = server
	Online.revs = {}
	Online.dirty = {}
	Online.conflicts.clear()
	assert_eq(await Online.connect_now(), Online.State.ONLINE)
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 1, "Kindlop")
	SaveManager.set_slot(3)
	GameState.money = 111
	SaveManager.save_game()
	GameState.money = 222
	SaveManager.save_game()
	await wait_process_frames(12)
	assert_true(Online.conflicts.is_empty(), "the second save is no conflict with the first")
	assert_false(Online.dirty.has(3), "nothing left to upload")
	var got: Dictionary = (await server.call_fn("save_get", {"p_slot": 3})).data
	assert_eq(int(got.data.money), 222, "the newer save is on the server")
	SaveManager.delete_save()
	if kept != "":
		SaveManager.write_atomic(SaveManager.path_for_slot(3), kept)
	SaveManager.set_slot(1)
	Online.backend = old_backend
	Online.state = old_state
	Online.revs = old_revs
	Online.dirty = old_dirty
	GameState.in_game = false
