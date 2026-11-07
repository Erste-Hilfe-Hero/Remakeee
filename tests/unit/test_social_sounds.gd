extends GutTest
## Plan area 6: sounds for greyed-out rows (item 2511), toasts (2512), gifts (2514), new friends
## (2515), finished daily tasks (2516) and the day's rare visitor (2517); locked rows shake (2423).

const NEW_SOUNDS: Array[String] = ["locked", "toast", "gift", "friend", "task_done", "sparkle"]

func test_new_sounds_exist_and_are_logged() -> void:
	var log_text: String = FileAccess.get_file_as_string("res://docs/ASSET_LOG.md")
	for n: String in NEW_SOUNDS:
		assert_true(ResourceLoader.exists(Sound.SFX_DIR % n), n)
		assert_string_contains(log_text, "audio/sfx/%s.wav" % n)

func test_menu_notes_go_to_the_ui_bus() -> void:
	assert_eq(Sound.bus_for("locked"), GameState.BUS_UI)
	assert_eq(Sound.bus_for("toast"), GameState.BUS_UI)
	assert_almost_eq(Sound.gap_for("locked"), 0.4, 0.001, "tapping a locked row fast stays calm")

func test_toast_rings_its_sound() -> void:
	var t := Toast.new()
	add_child_autofree(t)
	Sound.last_sfx = ""
	t.show_note("Hello")
	assert_eq(Sound.last_sfx, "toast")
	Sound.last_sfx = ""
	t._queue.clear()
	var quiet := Toast.new()
	add_child_autofree(quiet)
	quiet.show_note("Badge", null, "")
	assert_eq(Sound.last_sfx, "", "a badge note rings its own fanfare instead")

func test_daily_task_note_gets_the_bell() -> void:
	var line: String = Loc.t("Daily task done: %s") % "Win 3 battles"
	assert_eq(Overworld.notice_sound(line), "task_done")
	assert_eq(Overworld.notice_sound("+20 Waymarks"), "toast")

func test_locked_row_without_reason_still_taps() -> void:
	var lp := ListPicker.new()
	add_child_autofree(lp)
	var run := func() -> void: await lp.pick("T", [{"text": "A"}, {"text": "B", "disabled": true}] as Array[Dictionary])
	run.call()
	await get_tree().process_frame
	await get_tree().process_frame
	Sound.last_sfx = ""
	lp.tap_locked(1)
	assert_eq(Sound.last_sfx, "locked")
	lp.picked.emit(-1)

func test_locked_row_shakes_both_ways() -> void:
	var saved: bool = GameState.reduce_motion
	GameState.reduce_motion = false
	var row := Control.new()
	row.position = Vector2(10, 20)
	add_child_autofree(row)
	var seen: Dictionary = {"right": false, "left": false, "done": false}
	var run := func() -> void:
		await ListPicker.shake_row(row)
		seen.done = true
	run.call()
	var frames: int = 0
	while not seen.done and frames < 120:
		await get_tree().process_frame
		frames += 1
		if row.position.x > 10.0:
			seen.right = true
		if row.position.x < 10.0:
			seen.left = true
	GameState.reduce_motion = saved
	assert_true(seen.done)
	assert_true(seen.right, "out to the right")
	assert_true(seen.left, "and to the left")
	assert_eq(row.position, Vector2(10, 20), "back home")
