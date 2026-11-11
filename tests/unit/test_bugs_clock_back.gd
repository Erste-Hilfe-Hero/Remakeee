
func test_daily_find_not_met_again_after_clock_back() -> void:
	var flags: Dictionary = {DailyFind.flag_for("2026-11-07"): true}
	assert_true(DailyFind.met(flags, "2026-11-06"), "earlier day after a later meeting")
	assert_true(DailyFind.met(flags, "2026-11-07"))
	assert_false(DailyFind.met(flags, "2026-11-08"))
	var p: Dictionary = DailyFind.pick("2026-11-06")
	if not p.is_empty():
		var rng := RandomNumberGenerator.new()
		for i: int in 40:
			assert_null(DailyFind.maybe_spawn(str(p.table), flags, rng, "2026-11-06"))
