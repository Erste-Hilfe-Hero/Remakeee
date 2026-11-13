extends GutTest
## Plan area 7, items 3005 and 3096 on the local stand-in of the server: the new functions are
## called 100 times in a row (well within a minute) and refuse from their limit on, and being away
## for months costs nothing (the same as tools/online/sql_test/test_pause.sql).

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	for who: String in ["ann", "ben"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
		s.call_fn("team_set", {"p_team": [{"species": "Kindlop", "level": 30, "moves": []}]})
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	for f: String in ["raid", "trade", "bund"]:
		s.db.flags[f] = {"enabled": true, "min_version": 1}

## Calls [param fn] 100 times and returns the number of the first refused call (0 if none).
func _first_refusal(fn: String, args: Callable) -> int:
	s.switch_user("ann")
	for i: int in 100:
		var r: Variant = s.call_fn(fn, args.call(i)).data
		if r is Dictionary and str((r as Dictionary).get("error", "")) == "slow_down":
			return i + 1
	return 0

func test_new_functions_refuse_from_their_limit() -> void:
	assert_eq(_first_refusal("mail_send", func(_i: int) -> Dictionary:
		return {"p_code": codes.ben, "p_kind": "phrase", "p_phrase": 0}), 31, "mail: 30 an hour")
	assert_eq(_first_refusal("report_in", func(_i: int) -> Dictionary:
		return {"p_code": codes.ben, "p_reason": 0, "p_context": "friends"}), 11, "reports: 10 an hour")
	assert_eq(_first_refusal("raid_open", func(_i: int) -> Dictionary:
		return {"p_codes": [codes.ben]}), 7, "raids: 6 an hour")
	assert_eq(_first_refusal("league_join", func(_i: int) -> Dictionary:
		return {"p_league": "fair", "p_pick": ["Kindlop"]}), 31, "league entries: 30 an hour")
	# Trading: a friendship of level 3 for 8 days, a stored save, then the same offer again and again.
	var f: Dictionary = s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]
	f.points = 30
	f.accepted_at = s.now() - 8 * 86400
	s.switch_user("ann")
	s._saves()["1"] = {"rev": 1, "data": {"inventory": {"tonic": 5}}, "summary": "", "saved_at": 0}
	var tid: int = int(s.call_fn("trade_open", {"p_code": codes.ben}).data.trade)
	assert_eq(_first_refusal("trade_put", func(i: int) -> Dictionary:
		return {"p_trade": tid, "p_slot": 1, "p_rev": i + 1, "p_items": {}}), 61, "offers: 60 an hour")

func test_being_away_costs_nothing() -> void:
	s.switch_user("ann")
	s.call_fn("league_join", {"p_league": "fair", "p_pick": ["Kindlop"]})
	var sn: Dictionary = s.league_season()
	s.league_entry("fair", int(sn.id), "ann").rating = 1800.0
	var raid: int = int(s.call_fn("raid_open", {"p_codes": [codes.ben]}).data.raid)
	s.db.raid_members["%d|%s" % [raid, s.uid_for_code(codes.ann)]].damage = 500
	# Half a year later (the season is kept running so only the absence counts).
	s.clock_offset += 180 * 86400
	sn.ends_at = s.now() + 86400
	s.switch_user("ann")
	assert_eq(int(s.call_fn("league_info", {"p_league": "fair"}).data.tier), LeagueRules.tier(1800), "the tier stays")
	assert_eq(float(s.league_entry("fair", int(sn.id), "ann").rating), 1800.0, "the rating does not fall")
	assert_eq(int(s.db.raid_members["%d|%s" % [raid, s.uid_for_code(codes.ann)]].damage), 500, "the raid share stays")

## Item 2732: the fair league allows no items at all, so nothing from the shop can count there.
func test_the_fair_league_takes_no_items() -> void:
	for who: String in ["ben", "ann"]:
		s.switch_user(who)
		s.call_fn("league_join", {"p_league": "fair", "p_pick": ["Kindlop"]})
	var f: Dictionary = s.call_fn("league_find", {"p_league": "fair", "p_waited": 0}).data
	assert_true(bool(f.found))
	assert_false(bool(f.get("items_allowed", false)), "no battle items")
	for team: Array in f.teams:
		for row: Dictionary in team:
			assert_false(row.has("held"), "no held items")
	assert_true(s.db.config.has("league_fair_blocked_sources"), "the list from plan area 10 is there for later item rules")
