extends GutTest
## Earlier saves (plan area 7, item 3009) on the local stand-in of the server; the same cases as
## tools/online/sql_test/test_save_history.sql.

var s: LocalBackend

func before_each() -> void:
	s = LocalBackend.new()
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	s._saves()["1"] = {"rev": 1, "data": {"play_time": 60, "n": 1}, "summary": "Ashdown  0:01", "saved_at": s.now()}
	for i: int in range(2, 9):
		var cur: Dictionary = s._saves()["1"]
		s.keep_history(1, cur, {"play_time": 60 * i, "n": i})
		s._saves()["1"] = {"rev": i, "data": {"play_time": 60 * i, "n": i}, "summary": "Ashdown  0:0%d" % i, "saved_at": s.now()}
	s.keep_history(1, s._saves()["1"], {"play_time": 480, "n": 8})

func test_the_last_5_versions_newest_first() -> void:
	var l: Array = s.call_fn("save_history_list", {"p_slot": 1}).data.saves
	assert_eq(l.size(), 5)
	assert_eq(int(l[0].rev), 7)
	assert_eq(int(l[4].rev), 3)
	assert_eq(float(l[0].play_time), 420.0)
	assert_true(s.call_fn("save_history_list", {"p_slot": 2}).data.saves.is_empty())

func test_bringing_one_back_can_be_undone() -> void:
	var l: Array = s.call_fn("save_history_list", {"p_slot": 1}).data.saves
	var r: Dictionary = s.call_fn("save_restore", {"p_slot": 1, "p_id": l[2].id}).data
	assert_eq(int(r.rev), 9)
	assert_eq(int(s._saves()["1"].data.n), 5)
	assert_eq(int(s.call_fn("save_history_list", {"p_slot": 1}).data.saves[0].rev), 8, "the replaced version is kept")
	assert_eq(s.call_fn("save_restore", {"p_slot": 2, "p_id": l[0].id}).data.error, "no_such_save")

func test_a_normal_save_and_a_trade_keep_the_old_version() -> void:
	var before: int = s.call_fn("save_history_list", {"p_slot": 1}).data.saves.size()
	s._saves()["2"] = {"rev": 1, "data": {"play_time": 10, "inventory": {"tonic": 2}}, "summary": "", "saved_at": s.now()}
	s._trade_bag(2, 1, {"tonic": -1})
	var l: Array = s.call_fn("save_history_list", {"p_slot": 2}).data.saves
	assert_eq(l.size(), 1)
	assert_eq(int(l[0].rev), 1)
	assert_eq(s.call_fn("save_history_list", {"p_slot": 1}).data.saves.size(), before)

func test_entry_lines_show_date_place_and_time() -> void:
	var line: String = SaveHistoryMenu.entry_line({"saved_at": 0, "summary": "Ashdown  1:05"})
	assert_true(line.ends_with("Ashdown  1:05"))
	assert_eq(line.length(), "01.01. 00:00  Ashdown  1:05".length())
