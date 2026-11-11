extends GutTest
## Plan 1379 (master plan, bugs): turning the phone clock back and forth gives no advantage.
## Once-a-day rewards only pay again on a day after the stored one.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_tip_not_paid_again_after_clock_back() -> void:
	assert_eq(GameState.pay_tip("orrin", 60, 100), 60)
	assert_eq(GameState.pay_tip("orrin", 60, 99), 0, "clock turned back a day")
	assert_eq(GameState.pay_tip("orrin", 60, 100), 0, "and forward again")
	assert_eq(GameState.pay_tip("orrin", 60, 101), 60, "a real new day pays")

func test_tip_default_day_uses_server_clock() -> void:
	var day: int = int(Online.unix_now() / 86400.0)
	GameState.story_vars["tip_wim"] = day
	assert_eq(GameState.pay_tip("wim", 80), 0)

func test_fish_trap_stays_empty_after_clock_back() -> void:
	FishTrap.empty("reed_trap_a", "2026-11-07")
	assert_true(FishTrap.catch("reed_trap_a", "2026-11-06").is_empty())
	assert_true(FishTrap.catch("reed_trap_a", "2026-11-07").is_empty())
	assert_false(FishTrap.catch("reed_trap_a", "2026-11-08").is_empty())

func test_wake_counts_as_held_after_clock_back() -> void:
	GameState.records[Wake.DAY] = "2026-11-07"
	assert_true(Wake.held_today("2026-11-06"))
	assert_true(Wake.held_today("2026-11-07"))
	assert_false(Wake.held_today("2026-11-08"))

func test_no_extra_rematch_after_clock_back() -> void:
	var def: Dictionary = {"id": "bram", "trainer": "Ridgewalker Bram", "team": [{"species": "Puddlet", "level": 7}]}
	var flag: String = TrainerData.beaten_flag(def, "crowcrest")
	var flags: Dictionary = {flag: true}
	var records: Dictionary = {"rematch": {flag: "2026-11-07"}}
	assert_false(TrainerData.can_rematch(def, "crowcrest", flags, records, "2026-11-06"))
	assert_true(TrainerData.can_rematch(def, "crowcrest", flags, {}, "2026-11-06"), "never fought again")
	assert_true(TrainerData.can_rematch(def, "crowcrest", flags, records, "2026-11-08"))
