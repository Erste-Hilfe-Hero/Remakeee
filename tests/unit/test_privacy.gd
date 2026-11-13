extends GutTest
## data_export and delete_account (plan area 7, items 2972, 2973) on the local stand-in of the
## server. The same cases as tools/online/sql_test/test_privacy.sql.

var s: LocalBackend
var ann_code: String
var ben_code: String

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	s.switch_user("ben")
	ben_code = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.switch_user("ann")
	ann_code = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.call_fn("save_put", {"p_slot": 1, "p_data": {"schema": 1, "money": 5, "play_time": 1}, "p_summary": "A", "p_base_rev": 0})
	s.call_fn("team_set", {"p_team": [{"species": "Kindlop", "level": 10, "moves": []}]})
	s.switch_user("ben")
	s.call_fn("friend_request", {"p_code": ann_code})
	s.call_fn("report", {"p_code": ann_code, "p_reason": 0})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": ben_code, "p_accept": true})
	s.call_fn("mail_send", {"p_code": ben_code, "p_kind": "greeting", "p_phrase": 1})
	s.call_fn("league_join", {"p_league": "fair", "p_pick": ["Kindlop"]})

func test_the_export_holds_own_rows_and_hides_other_players() -> void:
	var e: Dictionary = s.call_fn("data_export").data
	assert_true(bool(e.ok))
	for name: String in s._shared_tables():
		assert_true((e.tables as Dictionary).has(name), "export misses " + name)
	assert_eq((e.tables.account.saves as Dictionary).size(), 1, "own save")
	assert_false((e.tables.reports as Array).is_empty(), "reports against the account are in it")
	assert_false((e.tables.league_fair as Array).is_empty(), "league row")
	var text: String = JSON.stringify(e)
	assert_false(text.contains("\"ben\""), "never names another player")
	assert_false(text.contains("\"ann\""), "own id reads you")
	assert_string_contains(text, "another player")

func test_delete_leaves_no_row_with_the_account() -> void:
	s.call_fn("delete_account")
	for name: String in s._shared_tables():
		var t: Variant = s.db[name]
		if t is Dictionary:
			for k: Variant in t:
				assert_false(s._mentions(t[k], "ann", str(k)), "%s still holds ann" % name)
		else:
			for row: Variant in t:
				assert_false(s._mentions(row, "ann"), "%s still holds ann" % name)
	assert_true(s.db.users.has("ben"), "others stay")

func test_the_export_file_can_be_written() -> void:
	var path: String = AccountMenu.write_export("{\"ok\": true}")
	assert_false(path.is_empty())
	assert_eq(FileAccess.get_file_as_string(path), "{\"ok\": true}")
	DirAccess.remove_absolute(path)
