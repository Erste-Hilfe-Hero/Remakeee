extends GutTest
## UI flow (update 1.3.2, docs/FLOW.md): lists, info boxes, notes and buttons arrive and leave
## with a short transition. Three promises are pinned here: reduced motion shows the end state
## at once, no transition makes the player wait or swallows a press, and Eras I and II move
## in hard steps while later eras ease.

var _motion: bool
var _retro: int
var _unlocked: int

func before_each() -> void:
	_motion = GameState.reduce_motion
	_retro = EraManager.retro_filter
	_unlocked = EraManager.unlocked_era
	GameState.reduce_motion = false
	EraManager.unlocked_era = 5
	EraManager.retro_filter = 4

func after_each() -> void:
	GameState.reduce_motion = _motion
	EraManager.retro_filter = _retro
	EraManager.unlocked_era = _unlocked

func _host() -> MenuHost:
	var host := MenuHost.new()
	add_child_autofree(host)
	return host

func _panel() -> Panel:
	var p := Panel.new()
	p.position = Vector2(10, 20)
	p.size = Vector2(40, 30)
	add_child_autofree(p)
	return p

func _rows(n: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in n:
		out.append("Row %d" % i)
	return out

# --- Juice.enter / leave / finish --------------------------------------------------------

func test_enter_slides_home_and_fades_in() -> void:
	var p: Panel = _panel()
	var tw: Tween = Juice.enter(p, Vector2(0, 4))
	assert_not_null(tw)
	assert_eq(p.modulate.a, 0.0, "starts clear")
	assert_eq(p.position, Vector2(10, 24), "starts 4 px off")
	assert_eq(p.size, Vector2(40, 30), "the slide never changes the size")
	assert_true(Juice.flowing(p))
	await wait_seconds(Juice.CURVES["open"].time + 0.1)
	assert_eq(p.position, Vector2(10, 20), "lands exactly")
	assert_eq(p.modulate.a, 1.0)
	assert_false(Juice.flowing(p))

func test_enter_under_reduced_motion_is_there_at_once() -> void:
	GameState.reduce_motion = true
	var p: Panel = _panel()
	p.modulate.a = 0.3
	assert_null(Juice.enter(p, Vector2(0, 4)), "no tween at all")
	assert_eq(p.position, Vector2(10, 20))
	assert_eq(p.modulate.a, 1.0)
	assert_false(Juice.flowing(p))

func test_leave_under_reduced_motion_hides_at_once() -> void:
	GameState.reduce_motion = true
	var p: Panel = _panel()
	assert_null(Juice.leave(p, Vector2(0, -6)))
	assert_false(p.visible)
	assert_eq(p.position, Vector2(10, 20))

func test_leave_fades_then_hides_and_restores() -> void:
	var p: Panel = _panel()
	Juice.leave(p, Vector2(0, -6))
	assert_true(p.visible, "still on screen while it fades")
	await wait_seconds(Juice.CURVES["close"].time + 0.1)
	assert_false(p.visible)
	assert_eq(p.position, Vector2(10, 20), "back in its place for the next time")
	assert_eq(p.modulate.a, 1.0)

func test_finish_ends_a_transition_in_its_end_state() -> void:
	var p: Panel = _panel()
	Juice.enter(p, Vector2(8, 0))
	Juice.finish(p)
	assert_eq(p.position, Vector2(10, 20))
	assert_eq(p.modulate.a, 1.0)
	Juice.leave(p)
	Juice.finish(p)
	assert_false(p.visible)
	Juice.finish(p)
	assert_false(p.visible, "finishing twice is harmless")

func test_enter_inside_a_container_only_fades() -> void:
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(20, 10)
	box.add_child(p)
	await wait_process_frames(2)
	var home: Vector2 = p.position
	Juice.enter(p, Vector2(8, 0))
	assert_eq(p.position, home, "the container keeps the place")
	assert_eq(p.modulate.a, 0.0)

func test_positions_stay_on_whole_pixels_all_the_way() -> void:
	var p: Panel = _panel()
	Juice.enter(p, Vector2(7, 0), "move")
	for i: int in 12:
		assert_eq(p.position, p.position.round(), "whole pixels")
		await wait_process_frames(1)

func test_stepped_eras_fade_in_four_levels_and_slide_in_2px() -> void:
	EraManager.retro_filter = 1
	assert_true(Juice.stepped())
	var p: Panel = _panel()
	Juice.enter(p, Vector2(4, 0), "move")
	var levels: Dictionary = {}
	for i: int in 16:
		levels[snappedf(p.modulate.a, 0.01)] = true
		assert_eq(int(p.position.x - 10) % Juice.STEP_PX, 0, "2 px steps")
		await wait_process_frames(1)
	for a: float in levels.keys():
		assert_true(a in [0.0, 0.33, 0.67, 1.0], "level %.2f is one of four" % a)
	assert_eq(p.modulate.a, 1.0)
	EraManager.retro_filter = 2
	assert_true(Juice.stepped(), "Era II too")
	EraManager.retro_filter = 3
	assert_false(Juice.stepped(), "Era III eases")

func test_stepped_tween_alpha_lands_on_the_exact_value() -> void:
	EraManager.retro_filter = 1
	var p: Panel = _panel()
	var tw: Tween = Juice.tween(p, "modulate:a", 0.5, "fade")
	await tw.finished
	assert_eq(p.modulate.a, 0.5)

func test_step_helpers() -> void:
	assert_eq(Juice.step_alpha(0.4), 1.0 / 3.0)
	assert_eq(Juice.step_alpha(0.9), 1.0)
	assert_eq(Juice.step_alpha(-1.0), 0.0)
	assert_eq(Juice.step_px(Vector2(3.2, -0.9)), Vector2(4, 0))

# --- Buttons -----------------------------------------------------------------------------

func test_held_button_squashes_and_springs_back() -> void:
	var b := Button.new()
	b.size = Vector2(60, 16)
	add_child_autofree(b)
	Juice.press_feedback(b)
	b.button_down.emit()
	await wait_seconds(Juice.SQUASH_TIME + 0.05)
	assert_eq(b.scale, Juice.SQUASH_SCALE)
	b.button_up.emit()
	await wait_seconds(Juice.POP_UP_TIME + Juice.CURVES["settle"].time + 0.1)
	assert_eq(b.scale, Vector2.ONE)

func test_button_stays_still_under_reduced_motion_and_in_stepped_eras() -> void:
	var b := Button.new()
	b.size = Vector2(60, 16)
	add_child_autofree(b)
	Juice.press_feedback(b)
	GameState.reduce_motion = true
	b.button_down.emit()
	await wait_process_frames(3)
	assert_eq(b.scale, Vector2.ONE, "reduced motion")
	GameState.reduce_motion = false
	EraManager.retro_filter = 1
	b.button_down.emit()
	await wait_process_frames(3)
	assert_eq(b.scale, Vector2.ONE, "Era I buttons only sink 1 px (theme)")

# --- Lists -------------------------------------------------------------------------------

func test_list_takes_a_pick_while_it_still_fades_in() -> void:
	var host: MenuHost = _host()
	var got: Array[int] = []
	var run := func() -> void: got.append(await host.pick_strings("Menu", _rows(3), true))
	run.call()
	await wait_process_frames(1)
	assert_true(Juice.flowing(host.picker), "still arriving")
	assert_true(host.picker.visible)
	host.picker.picked.emit(1)
	await wait_process_frames(1)
	assert_eq(got, [1] as Array[int], "the pick went through mid-fade")
	assert_false(host.picker.visible, "and the list is gone at once")
	assert_false(Juice.flowing(host.picker))
	assert_eq(host.picker.modulate.a, 1.0)

func test_pick_returns_in_the_same_frame_with_motion_on() -> void:
	var host: MenuHost = _host()
	var frames: Array[int] = []
	var run := func() -> void:
		await host.pick_strings("Menu", _rows(3), true)
		frames.append(Engine.get_process_frames())
	run.call()
	await wait_process_frames(3)
	var at: int = Engine.get_process_frames()
	host.picker.picked.emit(0)
	assert_eq(frames, [at] as Array[int], "no waiting for the close transition")

func test_press_finishes_the_list_arrival() -> void:
	var host: MenuHost = _host()
	var run := func() -> void: await host.pick_strings("Menu", _rows(3), true)
	run.call()
	await wait_process_frames(1)
	assert_true(Juice.flowing(host.picker))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(30, 30)
	host.picker._input(ev)
	assert_false(Juice.flowing(host.picker), "a press ends the transition")
	assert_eq(host.picker.modulate.a, 1.0)
	host.picker.picked.emit(-1)

func test_list_under_reduced_motion_has_no_transition_and_no_ghost() -> void:
	GameState.reduce_motion = true
	var host: MenuHost = _host()
	var run := func() -> void: await host.pick_strings("Menu", _rows(3), true)
	run.call()
	assert_false(Juice.flowing(host.picker))
	assert_eq(host.picker.modulate.a, 1.0)
	var home: Vector2 = host.picker.position
	await wait_process_frames(2)
	assert_eq(host.picker.position, home)
	host.picker.picked.emit(-1)
	assert_null(host.picker.ghost(), "nothing lingers")

func test_closed_list_leaves_a_fading_frame_that_takes_no_input() -> void:
	var host: MenuHost = _host()
	var run := func() -> void: await host.pick_strings("Menu", _rows(3), true)
	run.call()
	await wait_process_frames(3)
	host.picker.picked.emit(-1)
	var ghost: Panel = host.picker.ghost()
	assert_not_null(ghost)
	assert_eq(ghost.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(ghost.size, host.picker.size)
	assert_lt(ghost.get_index(), host.picker.get_index(), "behind the next list")
	await wait_seconds(Juice.CURVES["close"].time + 0.15)
	assert_null(host.picker.ghost(), "gone after 0.12 s")

func test_list_direction_deeper_back_and_same() -> void:
	var host: MenuHost = _host()
	var p: ListPicker = host.picker
	assert_eq(p.flow_dir("Menu"), 0, "a fresh menu has no direction")
	p._hidden_ms = Time.get_ticks_msec()
	assert_eq(p.flow_dir("Team"), 1, "deeper")
	p._hidden_ms = Time.get_ticks_msec()
	assert_eq(p.flow_dir("Kindlop"), 1)
	p._hidden_ms = Time.get_ticks_msec()
	assert_eq(p.flow_dir("Kindlop"), 0, "the same list again")
	p._hidden_ms = Time.get_ticks_msec()
	assert_eq(p.flow_dir("Menu"), -1, "back to an earlier list")
	p._hidden_ms = Time.get_ticks_msec() - ListPicker.FLOW_FOLLOW_MS - 50
	assert_eq(p.flow_dir("Team"), 0, "after a pause it is a new menu")

func test_following_list_slides_in_from_its_side() -> void:
	var host: MenuHost = _host()
	var first := func() -> void: await host.pick_strings("Menu", _rows(3), true)
	first.call()
	await wait_seconds(0.2)
	var home: float = host.picker.position.x
	host.picker.picked.emit(0)
	var second := func() -> void: await host.pick_strings("Team", _rows(2), true)
	second.call()
	assert_eq(host.picker.position.x, home + ListPicker.FLOW_PX, "deeper comes from the right")
	await wait_seconds(0.2)
	assert_eq(host.picker.position.x, home)
	host.picker.picked.emit(-1)
	first.call()
	assert_eq(host.picker.position.x, home - ListPicker.FLOW_PX, "back comes from the left")
	await wait_seconds(0.2)
	assert_eq(host.picker.position.x, home, "lands exactly")
	host.picker.picked.emit(-1)

func test_changed_value_does_not_flash_the_list() -> void:
	var host: MenuHost = _host()
	var run := func() -> void: await host.pick_strings("Sound", _rows(3), true)
	run.call()
	await wait_seconds(0.2)
	host.picker.picked.emit(0)
	run.call()
	assert_eq(host.picker.modulate.a, 1.0, "the same list again in the same frame stays solid")
	assert_false(Juice.flowing(host.picker))
	host.picker.picked.emit(-1)

func test_old_rows_do_not_count_in_the_new_list() -> void:
	var host: MenuHost = _host()
	var run := func() -> void: await host.pick_strings("Sound", _rows(12), true)
	run.call()
	await wait_process_frames(4)
	host.picker.picked.emit(0)
	run.call()
	var shown: int = 0
	for c: Node in host.picker._box.get_children():
		if c is Button and (c as Button).visible:
			shown += 1
	assert_eq(shown, 13, "12 rows and Back; the old rows are hidden before they are freed")
	host.picker.picked.emit(-1)

# --- Info box and menu toast -------------------------------------------------------------

func test_info_box_takes_the_close_while_it_rises() -> void:
	var host: MenuHost = _host()
	var done: Array[bool] = []
	var run := func() -> void:
		await host.info("A warm ember.")
		done.append(true)
	run.call()
	assert_true(host._info_panel.visible)
	assert_true(Juice.flowing(host._info_panel), "rising")
	host._close_info()
	assert_eq(done, [true] as Array[bool], "closed in the same frame, mid-rise")
	assert_eq(host._info_panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "takes no input while it fades out")
	await wait_seconds(Juice.CURVES["close"].time + 0.15)
	assert_false(host._info_panel.visible)

func test_info_box_blocks_again_when_reopened() -> void:
	var host: MenuHost = _host()
	var run := func() -> void: await host.info("One.")
	run.call()
	host._close_info()
	run.call()
	assert_true(host._info_panel.visible)
	assert_eq(host._info_panel.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_false(Juice.flowing(host._info_panel), "a following page keeps the box")
	assert_true(Juice.flowing(host._info_scroll), "only the text fades in")
	host._close_info()

func test_info_box_under_reduced_motion() -> void:
	GameState.reduce_motion = true
	var host: MenuHost = _host()
	var run := func() -> void: await host.info("One.")
	run.call()
	var home: Vector2 = host._info_panel.position
	assert_false(Juice.flowing(host._info_panel))
	assert_eq(host._info_panel.modulate.a, 1.0)
	host._close_info()
	assert_false(host._info_panel.visible, "hidden at once")
	assert_eq(host._info_panel.position, home)

func test_menu_toast_text_ends_when_its_time_is_up() -> void:
	var host: MenuHost = _host()
	host.toast("Saved.", 0.1)
	assert_eq(host.toast_text(), "Saved.")
	assert_true(Juice.flowing(host._toast), "drops in")
	await wait_seconds(0.15)
	assert_eq(host.toast_text(), "", "over, even while it fades out")
	await wait_seconds(Juice.CURVES["close"].time + 0.1)
	assert_false(host._toast.visible)

func test_menu_toast_under_reduced_motion() -> void:
	GameState.reduce_motion = true
	var host: MenuHost = _host()
	host.toast("Saved.", 0.1)
	assert_false(Juice.flowing(host._toast))
	await wait_seconds(0.15)
	assert_false(host._toast.visible, "gone at once")

# --- Notes at the top --------------------------------------------------------------------

func test_note_slides_in_and_never_takes_input() -> void:
	var t := Toast.new()
	add_child_autofree(t)
	t.show_note("Badge earned", null, "")
	assert_true(t._panel.visible)
	assert_true(Juice.flowing(t._panel))
	assert_eq(t._panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	await wait_seconds(Juice.CURVES["open"].time + 0.1)
	assert_eq(t._panel.offset_top, 4.0, "lands on its place")
	assert_eq(t._panel.modulate.a, 1.0)

func test_note_under_reduced_motion() -> void:
	GameState.reduce_motion = true
	var t := Toast.new()
	add_child_autofree(t)
	t.show_note("Badge earned", null, "")
	assert_false(Juice.flowing(t._panel))
	assert_eq(t._panel.offset_top, 4.0)
	assert_eq(t._panel.modulate.a, 1.0)

## The viewport changing (a rotation) while a note still slides in refits it; the note keeps
## the pixels it has left to go and lands on its place, top and bottom.
func test_note_refit_while_sliding_in_lands_on_its_place() -> void:
	var t := Toast.new()
	add_child_autofree(t)
	var top: float = t._panel.offset_top
	var bottom: float = t._panel.offset_bottom
	t.show_note("Badge earned", null, "")
	var left: float = Juice.shift_of(t._panel).y
	assert_ne(left, 0.0, "still on its way")
	t._fit_column()
	assert_eq(t._panel.offset_top, top + left, "keeps the pixels left to go")
	await wait_seconds(Juice.CURVES["open"].time + 0.1)
	assert_false(Juice.flowing(t._panel))
	assert_eq(t._panel.offset_top, top, "lands on its place")
	assert_eq(t._panel.offset_bottom, bottom)

# --- Place banner and battle orders ------------------------------------------------------

func test_plain_banner_fades_in_steps_and_is_instant_under_reduced_motion() -> void:
	EraManager.retro_filter = 1
	var banner := Label.new()
	banner.text = "Brindlewick"
	add_child_autofree(banner)
	var run := func() -> void: await TownPopup.slide(banner, "plain", true)
	run.call()
	assert_eq(banner.modulate.a, 0.0, "starts clear")
	await wait_seconds(Juice.CURVES["fade"].time + 0.1)
	assert_eq(banner.modulate.a, 1.0)
	GameState.reduce_motion = true
	banner.modulate.a = 0.4
	await TownPopup.slide(banner, "plain", true)
	assert_eq(banner.modulate.a, 1.0, "there at once")

func test_screen_fade_is_stepped_in_era_one_and_smooth_in_era_four() -> void:
	for era: int in [1, 4]:
		EraManager.retro_filter = era
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, 0)
		add_child_autofree(r)
		Juice.tween(r, "color:a", 1.0, "close", 0.11)
		var off_step: int = 0
		for i: int in 5:
			await wait_process_frames(1)
			if absf(Juice.step_alpha(r.color.a) - r.color.a) > 0.01:
				off_step += 1
		if era == 1:
			assert_eq(off_step, 0, "Era I: only the four levels")
		else:
			assert_gt(off_step, 0, "Era IV: smooth")

func test_battle_orders_fade_in_and_take_a_choice_at_once() -> void:
	var menu := CommandMenu.new()
	add_child_autofree(menu)
	await wait_process_frames(1)
	menu.set_enabled(false)
	menu.set_enabled(true)
	assert_true(menu._content.visible, "shown in the same call")
	assert_true(Juice.flowing(menu._content), "fading in")
	var got: Array = []
	menu.chosen.connect(func(kind: BattleAction.Kind, index: int) -> void: got.append([kind, index]))
	menu.chosen.emit(BattleAction.Kind.RUN, -1)
	assert_eq(got.size(), 1, "a choice goes through mid-fade")
	menu.set_enabled(false)
	GameState.reduce_motion = true
	menu.set_enabled(true)
	assert_false(Juice.flowing(menu._content), "reduced motion: no fade")
	assert_eq(menu._content.modulate.a, 1.0)
