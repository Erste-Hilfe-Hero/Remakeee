extends GutTest
## Chimora 200 list, daily package: welcome-back gift in Goals (item 139).

var _keep: Dictionary

func before_each() -> void:
	_keep = {"day": GameState.last_play_day, "ready": GameState.comeback_ready, "money": GameState.money,
		"tonic": GameState.item_count(Comeback.GIFT_ITEM)}
	GameState.last_play_day = 0
	GameState.comeback_ready = false

func after_each() -> void:
	GameState.last_play_day = int(_keep.day)
	GameState.comeback_ready = bool(_keep.ready)
	GameState.money = int(_keep.money)

func test_first_day_and_short_breaks_bring_no_gift() -> void:
	Comeback.note_day(100)
	assert_false(GameState.comeback_ready, "a new journey has nothing to welcome back")
	Comeback.note_day(102)
	assert_false(GameState.comeback_ready, "two days away is not a break")
	assert_eq(GameState.last_play_day, 102)

func test_three_days_away_readies_one_gift_in_goals() -> void:
	Comeback.note_day(100)
	Comeback.note_day(103)
	assert_true(GameState.comeback_ready)
	assert_eq(Comeback.pending(), 1)
	var money: int = GameState.money
	var tonics: int = GameState.item_count(Comeback.GIFT_ITEM)
	var lines: Array[String] = Comeback.claim()
	assert_eq(lines.size(), 1)
	assert_eq(GameState.money, money + Comeback.GIFT_COINS)
	assert_eq(GameState.item_count(Comeback.GIFT_ITEM), tonics + Comeback.GIFT_COUNT)
	assert_eq(Comeback.claim().size(), 0, "paid once")

func test_clock_turned_back_does_not_move_the_day_back() -> void:
	Comeback.note_day(100)
	Comeback.note_day(90)
	assert_eq(GameState.last_play_day, 100)

func test_fields_survive_a_save_round_trip() -> void:
	GameState.last_play_day = 123
	GameState.comeback_ready = true
	var d: Dictionary = GameState.to_dict()
	GameState.last_play_day = 0
	GameState.comeback_ready = false
	GameState.from_dict(d)
	assert_eq(GameState.last_play_day, 123)
	assert_true(GameState.comeback_ready)
