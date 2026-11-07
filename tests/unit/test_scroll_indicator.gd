extends GutTest
## Plan area 6, item 2426: a 1 px scroll indicator at the right edge of long lists shows while
## scrolling and goes 0.8 s after.

func test_indicator_runs_from_top_to_bottom() -> void:
	var r := Rect2(0, 10, 100, 50)
	var top: Rect2 = ListPicker.indicator_rect(r, 0.0, 50.0, 200.0)
	assert_eq(top.size.x, 1.0, "one pixel wide")
	assert_eq(top.position.x, 99.0, "on the right edge")
	assert_eq(top.position.y, 10.0)
	assert_almost_eq(top.size.y, 13.0, 1.0, "a quarter of the list is in view")
	var bottom: Rect2 = ListPicker.indicator_rect(r, 150.0, 50.0, 200.0)
	assert_almost_eq(bottom.end.y, 60.0, 0.5, "ends at the bottom edge")

func test_short_list_has_none() -> void:
	assert_eq(ListPicker.indicator_rect(Rect2(0, 0, 100, 50), 0.0, 50.0, 40.0), Rect2())
	assert_gte(ListPicker.indicator_rect(Rect2(0, 0, 100, 50), 0.0, 1.0, 1000.0).size.y, ListPicker.SCROLL_MIN_PX, "never thinner than 3 px")

func test_scrolling_shows_it_for_a_while() -> void:
	var lp := ListPicker.new()
	add_child_autofree(lp)
	var rows: Array[Dictionary] = []
	for i: int in 40:
		rows.append({"text": "Row %d" % i})
	var run := func() -> void: await lp.pick("Long", rows)
	run.call()
	lp._scroll.get_v_scroll_bar().value_changed.emit(5.0)
	assert_eq(lp.scroll_shown, 0.0, "the list scrolling itself in place shows nothing")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(lp.scroll_shown, 0.0, "opening the list is no scrolling")
	lp._scroll_quiet = 0
	lp._scroll.get_v_scroll_bar().value_changed.emit(10.0)
	assert_eq(lp.scroll_shown, ListPicker.SCROLL_SHOW_TIME)
	lp._process(0.5)
	assert_almost_eq(lp.scroll_shown, 0.3, 0.001)
	lp._process(0.5)
	assert_eq(lp.scroll_shown, 0.0, "gone after 0.8 s")
	lp.picked.emit(-1)
