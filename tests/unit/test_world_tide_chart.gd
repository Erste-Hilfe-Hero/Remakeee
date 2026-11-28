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

## Item 985: the Sablecove tide stone at the entrance tells the next low tide.
func test_tide_stone_in_sablecove() -> void:
	var m: MapData = MapData.load_map("sablecove")
	var s: Dictionary = m.sign_at(Vector2i(3, 7))
	assert_eq(str(s.get("dialogue", "")), "sablecove/tide_stone")
	assert_eq(str(Dialogue.get_entry("sablecove/tide_stone").get("action", "")), "tide_stone")

func test_tide_stone_lines() -> void:
	var low: Array[String] = TideChart.stone_lines(13)
	assert_true(low[0].contains("low tide") and low[0].contains("18:00"), low[0])
	var high: Array[String] = TideChart.stone_lines(7)
	assert_true(high[1].contains("Next low tide: 12:00 to 18:00"), high[1])
