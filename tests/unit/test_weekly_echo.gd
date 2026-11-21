extends GutTest
## Plan area 8: weekly echo with five rounds, interim prizes, Waymarks and ring-cap levels.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_five_rounds_and_board_stays_within_server_limit() -> void:
	assert_eq(WeeklyChallenge.ROUNDS, 5)
	assert_lte(WeeklyChallenge.ROUNDS * WeeklyChallenge.POINTS_PER_ROUND + 100, 400)
	assert_eq(WeeklyChallenge.WAYMARKS, 60)

func test_level_uses_story_cap_not_the_strongest_spirling() -> void:
	GameState.party[0].level = 55
	assert_eq(GameState.progress_cap(), GameState.LEVEL_CAPS[0])
	var a := WeeklyChallenge.new("2026-W45", GameState.progress_cap())
	GameState.party[0].level = 6
	var b := WeeklyChallenge.new("2026-W45", GameState.progress_cap())
	assert_eq(a.level, b.level, "raising one Spirling changes nothing")
	GameState.seal_rift("cinder")
	assert_eq(GameState.progress_cap(), GameState.LEVEL_CAPS[1])

func test_interim_prizes_once_a_week() -> void:
	var rec: Dictionary = {"week": "2026-W45", "best": 0, "claimed": false}
	var coins: int = GameState.money
	assert_eq(WeeklyChallenge.claim_interim(rec, 2), 0)
	assert_eq(WeeklyChallenge.claim_interim(rec, 3), 100)
	assert_eq(WeeklyChallenge.claim_interim(rec, 4), 150)
	assert_eq(WeeklyChallenge.claim_interim(rec, 3), 0, "only once a week")
	assert_eq(WeeklyChallenge.claim_interim(rec, 5), 0, "round 5 pays the main prize instead")
	assert_eq(GameState.money, coins + 250)

func test_round_text() -> void:
	GameState.party[0].hp = 0
	var t: String = WeeklyChallenge.round_text(2, 7, GameState.party)
	assert_eq(t, "Round 2 of 5: 7 turns, 0% power left, 1 fainted.")
