extends GutTest
## Bond minigame scoring (pure part).

func test_window_is_five_seconds_with_several_pulses() -> void:
	var times: Array[float] = BondTiming.pulse_times()
	assert_gte(times.size(), 4)
	assert_lte(times[times.size() - 1] + BondTiming.SHRINK_TIME, BondTiming.DURATION)

func test_ring_reaches_target_after_shrink_time() -> void:
	assert_almost_eq(BondTiming.radius_at(0.0), BondTiming.START_RADIUS, 0.001)
	assert_almost_eq(BondTiming.radius_at(BondTiming.SHRINK_TIME), BondTiming.TARGET_RADIUS, 0.001)

func test_tap_score_peaks_on_the_beat() -> void:
	assert_eq(BondTiming.tap_score(BondTiming.TARGET_RADIUS), 1.0)
	assert_eq(BondTiming.tap_score(BondTiming.TARGET_RADIUS + BondTiming.TOLERANCE), 0.0)
	assert_between(BondTiming.tap_score(BondTiming.TARGET_RADIUS + BondTiming.TOLERANCE / 2.0), 0.49, 0.51)

func test_perfect_run_scores_one_and_mashing_does_not_pay() -> void:
	var n: int = BondTiming.pulse_times().size()
	var perfect: Array[float] = []
	for i: int in n:
		perfect.append(1.0)
	assert_eq(BondTiming.final_score(perfect, n, 0), 1.0)
	assert_lt(BondTiming.final_score(perfect, n, 10), 0.5)
	assert_eq(BondTiming.final_score([] as Array[float], n, 0), 0.0)
