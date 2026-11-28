extends GutTest
## Plan items 2015 (auto text), 2016 (talk box on top) and 2018 (B moves talk on).

var _auto_before: bool = false

func before_each() -> void:
	_auto_before = GameState.auto_text

func after_each() -> void:
	GameState.auto_text = _auto_before

func _box() -> TextBox:
	var box := TextBox.new()
	box.size = Vector2(240, 44)
	add_child_autofree(box)
	return box

func test_b_moves_a_waiting_line_on() -> void:
	var box := _box()
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await box.show_text("Hello there.")
		state.done = true
	runner.call()
	box.advance_now()
	await wait_process_frames(2)
	assert_true(box._waiting, "the line waits")
	var b := InputEventAction.new()
	b.action = "ui_cancel"
	b.pressed = true
	box._unhandled_input(b)
	await wait_process_frames(2)
	assert_true(state.done, "B goes on like A")

func test_auto_text_delay_grows_with_the_line() -> void:
	assert_almost_eq(TextBox.auto_text_delay(""), 1.5, 0.001)
	assert_almost_eq(TextBox.auto_text_delay("abcdefghij"), 2.0, 0.001)

func test_auto_text_moves_world_talk_on_by_itself() -> void:
	GameState.auto_text = true
	var box := _box()
	box.world_auto = true
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await box.show_text("Hi.")
		state.done = true
	runner.call()
	box.advance_now()
	await wait_seconds(TextBox.auto_text_delay("Hi.") + 0.4)
	assert_true(state.done, "the line went on without a press")

func test_without_auto_text_the_line_waits() -> void:
	GameState.auto_text = false
	var box := _box()
	box.world_auto = true
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await box.show_text("Hi.")
		state.done = true
	runner.call()
	box.advance_now()
	await wait_seconds(TextBox.auto_text_delay("Hi.") + 0.4)
	assert_false(state.done)
	box.advance_now()

func test_auto_text_is_a_kept_setting() -> void:
	GameState.auto_text = true
	var d: Dictionary = GameState.settings_to_dict()
	GameState.auto_text = false
	GameState.settings_from_dict(d)
	assert_true(GameState.auto_text)
	var keys: Array = MenuHost.settings_rows("game").map(func(r: Array) -> String: return str(r[0]))
	assert_has(keys, "auto_text")

func test_talk_box_goes_up_when_the_wayfarer_stands_low() -> void:
	assert_true(Overworld.text_on_top(150.0, 216.0))
	assert_false(Overworld.text_on_top(60.0, 216.0))

func test_name_tag_drops_under_a_box_at_the_top() -> void:
	assert_eq(TextBox.tag_offset_y(170.0, 44.0, 12.0), -10.0, "above a box at the bottom")
	assert_eq(TextBox.tag_offset_y(0.0, 44.0, 12.0), 42.0, "under a box at the top")
