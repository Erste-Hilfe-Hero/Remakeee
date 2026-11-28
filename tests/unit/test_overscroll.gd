extends GutTest
## Plan area 6, item 2425: pushing a list past its end springs it 4 px over and back with
## "settle" instead of stopping hard.

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false

func after_each() -> void:
	GameState.settings_from_dict(_saved)

func test_only_at_the_ends() -> void:
	assert_eq(ListPicker.overscroll_dir(150.0, 50.0, 200.0, 1), 1, "past the bottom")
	assert_eq(ListPicker.overscroll_dir(0.0, 50.0, 200.0, -1), -1, "past the top")
	assert_eq(ListPicker.overscroll_dir(60.0, 50.0, 200.0, 1), 0, "still room below")
	assert_eq(ListPicker.overscroll_dir(60.0, 50.0, 200.0, -1), 0, "still room above")
	assert_eq(ListPicker.overscroll_dir(0.0, 50.0, 200.0, 1), 0)

func test_bounce_goes_over_and_back() -> void:
	var lp := ListPicker.new()
	add_child_autofree(lp)
	var run := func() -> void: await lp.pick("T", [{"text": "A"}, {"text": "B"}] as Array[Dictionary])
	run.call()
	await get_tree().process_frame
	await get_tree().process_frame
	var home: Vector2 = lp._scroll.position
	var seen: Dictionary = {"peak": 0.0, "done": false}
	var go := func() -> void:
		await lp.bounce(1)
		seen.done = true
	go.call()
	var frames: int = 0
	while not seen.done and frames < 120:
		await get_tree().process_frame
		frames += 1
		seen.peak = maxf(seen.peak, home.y - lp._scroll.position.y)
	assert_true(seen.done)
	assert_gt(seen.peak, 1.0, "springs up past the bottom")
	assert_lte(seen.peak, ListPicker.OVERSCROLL_PX + 1.0, "about 4 px")
	assert_eq(lp._scroll.position, home, "back in place")
	GameState.reduce_motion = true
	await lp.bounce(1)
	assert_eq(lp._scroll.position, home, "still under reduced motion")
	lp.picked.emit(-1)
