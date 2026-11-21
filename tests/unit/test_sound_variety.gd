extends GutTest
## Plan area 6: varied cursor and hit pitches (items 2510, 2533), the wall bump cool-down
## (item 2520), hit loudness by strength lost (item 2532) and the miss and dodge sounds
## (items 2531, 2536).

func test_cursor_picks_one_of_three_pitches() -> void:
	var seen: Dictionary = {}
	for i: int in 200:
		var p: float = Sound.varied_pitch("select", 1.0)
		assert_has(Sound.SELECT_PITCHES, p)
		seen[p] = true
	assert_eq(seen.size(), 3, "all three come up")

func test_hits_vary_within_five_percent() -> void:
	var lo: float = 2.0
	var hi: float = 0.0
	for i: int in 200:
		var p: float = Sound.varied_pitch("hit_ember", 1.0)
		lo = minf(lo, p)
		hi = maxf(hi, p)
	assert_gte(lo, 0.95)
	assert_lte(hi, 1.05)
	assert_gt(hi - lo, 0.02, "the pitch really moves")

func test_own_pitch_and_other_sounds_stay() -> void:
	assert_eq(Sound.varied_pitch("select", 1.2), 1.2, "a caller's pitch wins")
	assert_eq(Sound.varied_pitch("confirm", 1.0), 1.0)

func test_bump_waits_four_tenths() -> void:
	assert_almost_eq(Sound.gap_for("bump"), 0.4, 0.001)
	assert_almost_eq(Sound.gap_for("select"), Sound.SFX_MIN_GAP, 0.001)

func test_hit_loudness_by_share() -> void:
	assert_eq(Sound.hit_volume_db(0.05), -6.0)
	assert_eq(Sound.hit_volume_db(0.10), -6.0)
	assert_eq(Sound.hit_volume_db(0.2), -3.0)
	assert_eq(Sound.hit_volume_db(0.5), 0.0)

func test_miss_and_dodge_sounds_exist() -> void:
	for n: String in ["miss", "dodge"]:
		assert_true(ResourceLoader.exists(Sound.SFX_DIR % n), n)
