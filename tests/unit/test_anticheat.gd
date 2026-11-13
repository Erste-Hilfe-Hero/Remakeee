extends GutTest
## Anti-cheat in save_put (plan area 7, items 2921-2925) on the local stand-in of the server.
## The same cases as tools/online/sql_test/test_anticheat.sql.

var s: LocalBackend

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})

func _put(data: Dictionary, base: int) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	d["schema"] = 1
	return s.call_fn("save_put", {"p_slot": 1, "p_data": d, "p_summary": "", "p_base_rev": base}).data

func _age(minutes: int) -> void:
	s.clock_offset += minutes * 60

func test_money_and_play_time_follow_the_clock() -> void:
	var r: Dictionary = _put({"money": 500, "play_time": 60, "gems": 999, "league": {"rating": 3000},
		"party": [{"species": "Kindlop", "level": 5, "moves": ["Kiln Strike"]}], "inventory": {"tonic": 2}}, 0)
	assert_true(bool(r.ok), str(r))
	var stored: Dictionary = s.call_fn("save_get", {"p_slot": 1}).data.data
	assert_false(stored.has("gems"), "server-kept values are dropped (2924)")
	assert_false(stored.has("league"))
	assert_eq(_put({"money": 20000, "play_time": 120}, 1).reason, "money_fast")
	assert_true(bool(_put({"money": 5400, "play_time": 120}, 1).ok), "4900 in one minute is fine")
	assert_eq(_put({"money": 5400, "play_time": 3000}, 2).reason, "play_time_fast")
	_age(60)
	assert_true(bool(_put({"money": 5400, "play_time": 3000}, 2).ok), "an hour later it is fine")

func test_unknown_ids_are_refused() -> void:
	_put({"money": 1, "play_time": 10}, 0)
	assert_eq(_put({"money": 1, "play_time": 10, "party": [{"species": "Pikachoo"}]}, 1).reason, "unknown_species")
	assert_eq(_put({"money": 1, "play_time": 10, "storage": [{"species": "Kindlop", "moves": ["Mega Blast 9000"]}]}, 1).reason, "unknown_move")
	assert_eq(_put({"money": 1, "play_time": 10, "inventory": {"golden_hack": 1}}, 1).reason, "unknown_item")
	assert_eq(_put({"money": 1, "play_time": 10, "party": [{"species": "Kindlop", "held": "golden_hack"}]}, 1).reason, "unknown_item")

func test_a_new_journey_starts_from_the_start_money() -> void:
	_put({"money": 400, "play_time": 600}, 0)
	assert_true(bool(_put({"money": 500, "play_time": 30}, 1).ok), "less play time: a new journey")
	assert_eq(_put({"money": 90000, "play_time": 10}, 2).reason, "money_fast")

func test_three_notes_take_the_account_out_of_leagues_until_cleared() -> void:
	_put({"money": 1, "play_time": 10}, 0)
	for i: int in 3:
		_put({"money": 999999, "play_time": 10}, 1)
	assert_eq((s.db.users.ann.cheat_flags as Array).size(), 1, "retries within 10 minutes count once")
	assert_false(s.cheat_held("ann"))
	_put({"money": 1, "play_time": 10, "party": [{"species": "Pikachoo"}]}, 1)
	_age(11)
	_put({"money": 999999, "play_time": 10}, 1)
	assert_eq(s.call_fn("league_info", {"p_league": "fair"}).data.error, "under_review")
	s.db.users.ann.cheat_cleared_at = s.now()
	_age(1)
	assert_true(bool(s.call_fn("league_info", {"p_league": "fair"}).data.ok), "cleared by Ali")
	s.db.users.ann.cheat_cleared_at = 0
	_age(8 * 24 * 60)
	assert_false(s.cheat_held("ann"), "notes older than 7 days do not count")

func test_the_real_game_saves_pass() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 1, "Puddlet")
	var d: Dictionary = GameState.to_dict()
	d["schema"] = 1
	var r: Dictionary = s.call_fn("save_put", {"p_slot": 1, "p_data": d, "p_summary": "", "p_base_rev": 0}).data
	assert_true(bool(r.ok), str(r))
