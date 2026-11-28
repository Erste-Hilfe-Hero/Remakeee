extends GutTest
## Plan area 8, P2 batch: weekly echo score, target bonus, preview, archive, item prizes,
## partial wins and three prize tries a week.

const WEEK: String = "2026-W45"

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Online.clock_offset = 0

func _ch() -> WeeklyChallenge:
	return WeeklyChallenge.new(WEEK, 30)

func _rec() -> Dictionary:
	return {"week": WEEK, "best": 0, "claimed": false}

func test_prize_list_has_twelve_real_items() -> void:
	assert_eq(WeeklyChallenge.REWARDS.size(), 12)
	for id: String in WeeklyChallenge.REWARDS:
		assert_false(Database.item(id).is_empty(), id)

func test_score_lower_is_better_and_only_for_clears() -> void:
	var party: Array[Spirling] = GameState.party
	assert_eq(WeeklyChallenge.run_score(4, 12, party), 0)
	var full: int = WeeklyChallenge.run_score(5, 15, party)
	assert_eq(full, 150 + (100 - int(round(100.0 * party[0].hp_fraction()))))
	assert_lt(full, WeeklyChallenge.run_score(5, 20, party))
	var t: int = WeeklyChallenge.target(WEEK)
	assert_between(t, 180, 260)
	assert_eq(t, WeeklyChallenge.target(WEEK), "same target for everyone")

func test_best_score_is_kept_and_target_pays_once() -> void:
	var ch := _ch()
	var rec := _rec()
	var t: int = WeeklyChallenge.target(WEEK)
	var fast: int = (t - 100) / 10
	ch.finish_run(rec, 5, fast + 5, GameState.party, true)
	var first: int = int(rec.score)
	assert_eq(int(GameState.records.weekly_best.score), first)
	assert_true(bool(rec.target_paid))
	var paid: int = GameState.waymarks
	assert_eq(paid, WeeklyChallenge.PARTIAL_WAYMARKS + WeeklyChallenge.TARGET_WAYMARKS)
	ch.finish_run(rec, 5, fast, GameState.party, true)
	assert_lt(int(rec.score), first, "a better run replaces the best score")
	assert_eq(GameState.waymarks, paid, "partial share and target bonus pay once a week")
	ch.finish_run(rec, 5, fast + 30, GameState.party, true)
	assert_lt(int(rec.score), first, "a worse run keeps the best")

func test_partial_win_and_full_share() -> void:
	var ch := _ch()
	var rec := _rec()
	ch.finish_run(rec, 2, 8, GameState.party, true)
	assert_eq(GameState.waymarks, 0, "round 2 pays nothing")
	assert_eq(WeeklyChallenge.full_waymarks(rec), WeeklyChallenge.WAYMARKS)
	ch.finish_run(rec, 3, 12, GameState.party, true)
	assert_eq(GameState.waymarks, WeeklyChallenge.PARTIAL_WAYMARKS)
	assert_eq(WeeklyChallenge.full_waymarks(rec), WeeklyChallenge.WAYMARKS - WeeklyChallenge.PARTIAL_WAYMARKS, "the full win tops up to 60")

func test_three_prize_tries_a_week() -> void:
	var rec := _rec()
	for i: int in WeeklyChallenge.PRIZE_TRIES:
		assert_true(WeeklyChallenge.start_try(rec))
	assert_eq(WeeklyChallenge.prize_tries_left(rec), 0)
	assert_false(WeeklyChallenge.start_try(rec), "the fourth try only counts for the score")
	var ch := _ch()
	ch.finish_run(rec, 5, 10, GameState.party, false)
	assert_eq(GameState.waymarks, 0)
	assert_gt(int(rec.score), 0, "the best score still counts")

func test_preview_names_field_rule_and_three_teams() -> void:
	var ch := _ch()
	var text: String = ch.preview_text()
	assert_string_contains(text, str(BattleRules.FIELDS[ch.field].label))
	assert_string_contains(text, str(BattleRules.RULES[ch.rule].label))
	for i: int in 3:
		assert_string_contains(text, "Echo %d:" % (i + 1))
	assert_false(text.contains("Echo 4:"))

func test_archive_keeps_eight_weeks_newest_first() -> void:
	assert_string_contains(WeeklyChallenge.archive_text(), "No weekly echo")
	for w: int in range(30, 41):
		var ch := WeeklyChallenge.new("2026-W%02d" % w, 30)
		ch.finish_run({"week": ch.week, "best": 0}, w % 6, 10, GameState.party, false)
	var arch: Array = GameState.records.weekly_archive
	assert_eq(arch.size(), WeeklyChallenge.ARCHIVE_WEEKS)
	assert_eq(str(arch[0].week), "2026-W40")
	var again := WeeklyChallenge.new("2026-W40", 30)
	again.finish_run({"week": "2026-W40", "best": 5}, 5, 10, GameState.party, false)
	assert_eq((GameState.records.weekly_archive as Array).size(), WeeklyChallenge.ARCHIVE_WEEKS, "one entry per week")
	assert_string_contains(WeeklyChallenge.archive_text(), "2026-W40")
