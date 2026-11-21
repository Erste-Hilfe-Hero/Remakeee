extends GutTest
## Plan area 6: hopping dots while a server call takes longer than 200 ms (item 2290).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false

func after_each() -> void:
	GameState.settings_from_dict(_saved)

func test_dots_show_only_after_200_ms() -> void:
	var w := WaitDots.new()
	add_child_autofree(w)
	w.begin()
	w._process(0.1)
	assert_false(w.is_showing(), "quick answers show nothing")
	w._process(0.15)
	assert_true(w.is_showing())
	w.end()
	assert_false(w.is_showing())

func test_two_calls_keep_the_dots_until_both_answer() -> void:
	var w := WaitDots.new()
	add_child_autofree(w)
	w.begin()
	w.begin()
	w._process(0.3)
	w.end()
	assert_true(w.is_showing())
	w.end()
	assert_false(w.is_showing())
	w.end()
	assert_eq(w.pending, 0, "never below zero")

func test_dots_hop_one_after_another() -> void:
	var third: float = WaitDots.PERIOD / 3.0
	for i: int in 3:
		var t: float = i * third + 0.01
		for j: int in 3:
			assert_eq(WaitDots.hop(j, t, false), WaitDots.HOP_PX if i == j else 0)
	assert_eq(WaitDots.hop(0, 0.01, true), 0, "reduced motion: still")

func test_online_has_the_dots() -> void:
	assert_not_null(Online.wait_dots)
	assert_eq(Online.wait_dots.pending, 0, "no call left hanging")
