extends GutTest
## Area 3 item 1063: the Tide Chart shows the next low and high tide by the device clock.

func test_next_change() -> void:
	assert_eq(TideChart.next_change(0), 6)
	assert_eq(TideChart.next_change(5), 6)
	assert_eq(TideChart.next_change(6), 12)
	assert_eq(TideChart.next_change(17), 18)
	assert_eq(TideChart.next_change(23), 0)

func test_page_at_low_tide() -> void:
	var l: Array[String] = TideChart.lines(3)
	assert_true(l[1].contains("low tide") and l[1].contains("06:00"), l[1])
	assert_true(l[2].contains("high tide") and l[2].contains("06:00 to 12:00"), l[2])
	assert_true(l[3].contains("low tide") and l[3].contains("12:00 to 18:00"), l[3])

func test_page_at_high_tide() -> void:
	var l: Array[String] = TideChart.lines(20)
	assert_true(l[1].contains("high tide") and l[1].contains("00:00"), l[1])
	assert_true(l[2].contains("low tide") and l[2].contains("00:00 to 06:00"), l[2])

func test_chart_is_gear_given_in_the_fen() -> void:
	assert_true(bool(Database.item(TideChart.ITEM).get("gear", false)))
	assert_true(str(Dialogue.get_entry("brackwater_fen/tidewatcher").get("action", "")).begins_with("give_item tide_chart"))
