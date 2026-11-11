extends GutTest
## Online 100 plan points 71, 72, 78, 79 and 95: ReplayLibrary and the maintenance notice.

func before_all() -> void:
	Database.load_all()

func _snap(sd: int) -> Dictionary:
	var m: BattleModel = BattleModel.new([BattleFixtures.make("Kindlop", 20)] as Array[Spirling],
		[BattleFixtures.make("Mossling", 20)] as Array[Spirling], false, sd, 1)
	return BattleReplay.snapshot(m, "battle", "lake")

func _win(won: bool) -> Dictionary:
	return {"winner": "player" if won else "foe", "rounds": 3, "hp": [[1], [0]]}

func test_keeps_only_the_newest_ones() -> void:
	var rec: Dictionary = {}
	var keep: int = int(ReplayLibrary.cfg().keep)
	for i: int in keep + 3:
		ReplayLibrary.add(rec, "league_fair", _snap(i + 1), _win(true))
	var list: Array = ReplayLibrary.entries(rec)
	assert_eq(list.size(), keep)
	assert_eq(int(list[0].snap.seed), keep + 3, "newest first")

func test_empty_snapshot_is_not_kept() -> void:
	var rec: Dictionary = {}
	ReplayLibrary.add(rec, "raid", {}, _win(true))
	assert_eq(ReplayLibrary.entries(rec).size(), 0)

func test_share_code_round_trip_replays_the_same_battle() -> void:
	var snap: Dictionary = _snap(42)
	var code: String = ReplayLibrary.share_code(snap)
	assert_true(code.begins_with(str(ReplayLibrary.cfg().code_prefix)))
	var back: Dictionary = ReplayLibrary.from_code(code)
	assert_eq(int(back.seed), 42)
	assert_eq(BattleReplay.simulate(back), BattleReplay.simulate(snap))

func test_broken_codes_give_nothing() -> void:
	assert_eq(ReplayLibrary.from_code(""), {})
	assert_eq(ReplayLibrary.from_code("hello"), {})
	assert_eq(ReplayLibrary.from_code(str(ReplayLibrary.cfg().code_prefix) + "!!!"), {})

func test_win_rate_per_spirling() -> void:
	var rec: Dictionary = {}
	ReplayLibrary.add(rec, "league_fair", _snap(1), _win(true))
	ReplayLibrary.add(rec, "league_fair", _snap(2), _win(false))
	ReplayLibrary.add(rec, "echo_duel", _snap(3), _win(true))
	assert_eq(ReplayLibrary.win_rates(rec), {"Kindlop": [2, 3]})
	assert_eq(ReplayLibrary.win_rate_lines(rec).size(), 1)

func test_usage_counts_opponents() -> void:
	var rec: Dictionary = {}
	ReplayLibrary.add(rec, "league_fair", _snap(1), _win(true), "s1")
	ReplayLibrary.add(rec, "league_fair", _snap(2), _win(true), "s2")
	assert_eq(ReplayLibrary.usage(rec), [["Mossling", 2]])
	assert_eq(ReplayLibrary.usage(rec, "s1"), [["Mossling", 1]])

func test_maintenance_notice_window() -> void:
	var h: int = int(ReplayLibrary.cfg().maintenance_warn_hours)
	assert_eq(ReplayLibrary.maintenance_text(1000, 0), "", "none planned")
	assert_eq(ReplayLibrary.maintenance_text(1000, 900), "", "already past")
	assert_eq(ReplayLibrary.maintenance_text(0, h * 3600 + 1), "", "too far away")
	assert_string_contains(ReplayLibrary.maintenance_text(0, 2 * 3600), "2")

func test_local_server_gives_maintenance_time() -> void:
	var s := LocalBackend.new()
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	assert_eq(int(s.call_fn("maintenance_info").data.at), 0)
	s.db.config["maintenance_at"] = 1900000000
	assert_eq(int(s.call_fn("maintenance_info").data.at), 1900000000)
