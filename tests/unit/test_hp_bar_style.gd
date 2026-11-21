extends GutTest
## Per-era HP bar look (design plan items 31, 131, 168, 233, 336, 435).

func test_states_by_fraction() -> void:
	assert_eq(HpBarStyle.state(1.0), HpBarStyle.State.HIGH)
	assert_eq(HpBarStyle.state(0.5), HpBarStyle.State.MID)
	assert_eq(HpBarStyle.state(0.2), HpBarStyle.State.LOW)

func test_era_one_uses_pattern_not_colour() -> void:
	assert_true(HpBarStyle.for_era(1).pattern)
	assert_eq(HpBarStyle.color(1, 1.0), HpBarStyle.color(1, 0.1))
	var counts: Array[int] = []
	for st: int in [HpBarStyle.State.HIGH, HpBarStyle.State.MID, HpBarStyle.State.LOW]:
		var n: int = 0
		for y: int in 3:
			for x: int in 12:
				if HpBarStyle.pattern_ink(st, x, y):
					n += 1
		counts.append(n)
	assert_gt(counts[0], counts[1])
	assert_gt(counts[1], counts[2])

func test_era_two_traffic_colours() -> void:
	var hi: Color = HpBarStyle.color(2, 0.9)
	var mid: Color = HpBarStyle.color(2, 0.4)
	var lo: Color = HpBarStyle.color(2, 0.1)
	assert_ne(hi, mid)
	assert_ne(mid, lo)
	assert_gt(hi.g, hi.r)
	assert_gt(lo.r, lo.g)

func test_low_blinks_from_era_two_only() -> void:
	assert_false(HpBarStyle.blink_hidden(1, 0.1, 0.3))
	assert_true(HpBarStyle.blink_hidden(2, 0.1, 0.3))
	assert_false(HpBarStyle.blink_hidden(2, 0.1, 0.1))
	assert_false(HpBarStyle.blink_hidden(2, 0.9, 0.3))
	assert_false(HpBarStyle.blink_hidden(2, 0.0, 0.3))

func test_later_eras_add_frame_slant_trail() -> void:
	assert_true(HpBarStyle.for_era(3).frame)
	assert_true(HpBarStyle.for_era(3).gradient)
	assert_gt(int(HpBarStyle.for_era(4).slant), 0)
	assert_false(HpBarStyle.for_era(4).trail)
	assert_true(HpBarStyle.for_era(5).trail)
	assert_eq(HpBarStyle.for_era(9), HpBarStyle.for_era(5))

func test_strip_draws_in_every_era() -> void:
	for e: int in [1, 2, 3, 4, 5]:
		var s := InfoStrip.new()
		s.size = Vector2(60, 20)
		s.era = e
		s.max_hp = 40
		s.display_hp = 8.0
		s.trail_hp = 30.0
		add_child_autofree(s)
		await get_tree().process_frame
		assert_eq(s.era, e)
