extends GutTest
## Safety and fairness (Online 100, area 9, points 83, 85, 86, 88) on the local stand-in of the
## server. The same cases as tools/online/sql_test/test_safety.sql.

var s: LocalBackend
var codes: Dictionary = {}
const TEAM: Array = [{"species": "Kindlop", "level": 10, "moves": []}, {"species": "Zippit", "level": 10, "moves": []},
	{"species": "Mossling", "level": 10, "moves": []}]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	for who: String in ["ann", "ben", "kid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	for k: String in ["bund", "raid", "live_duel", "league_fair", "league_open"]:
		s.db.flags[k] = {"enabled": true, "min_version": 1}
	# kid is 14: the shop's age question put them in band 13.
	LocalShop.of(s)._shop("kid").band = 13

func _as(who: String, fn: String, args: Dictionary = {}) -> Variant:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func test_under_16_friends_and_fair_league_by_default() -> void:
	var flags: Array = _as("kid", "hello", {"p_version": 1}).flags
	assert_false(flags.has("league_open"), "open league hidden under 16")
	assert_false(flags.has("bund"), "bunds hidden under 16")
	assert_true(flags.has("league_fair"), "fair league stays")
	assert_true(flags.has("raid"), "raids with friends stay")
	var pg: Dictionary = _as("kid", "parent_get")
	assert_true(bool(pg.young))
	assert_false(bool(pg.custom))
	assert_eq(_as("kid", "league_info", {"p_league": "open"}).error, "parent_off")
	assert_true(bool(_as("kid", "league_info", {"p_league": "fair"}).ok))
	assert_eq(_as("kid", "bund_search", {"p_lang": ""}).error, "parent_off")
	var ps: Dictionary = _as("kid", "parent_set", {"p_off": ["bund"], "p_version": 1})
	assert_true((ps.flags as Array).has("league_open"), "a parent can allow the open league")
	assert_true(bool(_as("kid", "league_info", {"p_league": "open"}).ok))
	assert_true(bool(_as("ann", "parent_get").ok))
	assert_false(bool(_as("ann", "parent_get").young), "age not asked counts as grown-up")

func test_parent_switches() -> void:
	assert_eq(_as("ann", "parent_set", {"p_off": ["shop"], "p_version": 1}).error, "bad_key")
	_as("ann", "parent_set", {"p_off": ["raid", "live_duel"], "p_version": 1})
	var h: Dictionary = _as("ann", "hello", {"p_version": 1})
	assert_false((h.flags as Array).has("raid") or (h.flags as Array).has("live_duel"))
	assert_eq(h.parent_off, ["raid", "live_duel"])
	assert_eq(_as("ann", "raid_list").error, "parent_off")
	_as("ann", "parent_set", {"p_off": [], "p_version": 1})
	assert_true(bool(_as("ann", "raid_list").ok), "switched on again")
	assert_eq(SafetyMenu.switch_line("raid", ["raid"]), "Raid Rifts: Off")

func test_no_live_duel_with_a_switched_off_friend() -> void:
	s.switch_user("ben")
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.call_fn("team_set", {"p_team": TEAM})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	s.call_fn("team_set", {"p_team": TEAM})
	_as("ann", "parent_set", {"p_off": ["live_duel"], "p_version": 1})
	assert_eq(_as("ben", "live_invite", {"p_code": codes.ann}).error, "parent_off")
	_as("ann", "parent_set", {"p_off": [], "p_version": 1})
	var r: Dictionary = _as("ben", "live_invite", {"p_code": codes.ann})
	assert_true(bool(r.ok), str(r))
	_as("ann", "parent_set", {"p_off": ["live_duel"], "p_version": 1})
	assert_eq(_as("ann", "live_answer", {"p_id": int(r.id), "p_accept": true}).error, "parent_off", "cannot accept either")
	# 83: report the duel rival.
	var rep: Dictionary = _as("ben", "report_battle", {"p_kind": "duel", "p_ref": str(int(r.id)), "p_reason": 1})
	assert_true(bool(rep.ok))
	assert_eq(str(s.db.reports[-1].target), "ann")
	assert_eq(str(s.db.reports[-1].context), "duel")

func _entry(who: String, rating: float) -> void:
	var sn: int = int(s.league_season().id)
	s._table("league_fair", {})["%d|%s" % [sn, who]] = {"team": [{"species": "Kindlop", "level": 50, "moves": []}],
		"rating": rating, "rd": 50.0, "vol": 0.06, "games": 10, "wins": 5}

func test_a_pair_counts_three_times_a_day() -> void:
	_entry("ann", 7100.0)
	_entry("ben", 7110.0)
	var m: Dictionary = s._table("league_matches", {})
	for i: int in 3:
		m[str(500 + i)] = {"league": "fair", "season": int(s.league_season().id), "user": "ann", "opponent": "ben", "seed": i,
			"teams": [], "created_at": s.now(), "state": "done", "rated": true}
	var f: Dictionary = _as("ann", "league_find", {"p_league": "fair", "p_waited": 0})
	assert_true(bool(f.found))
	assert_false(bool(f.rated), "fourth battle against the same rival does not count")
	assert_true(bool(f.pair_limit))

func test_sandbagged_battles_are_not_rated_and_noted() -> void:
	_entry("ann", 7100.0)
	_entry("ben", 7110.0)
	var sn: int = int(s.league_season().id)
	var lost: Dictionary = {"winner": "foe", "rounds": 1, "foe_damage": 0}
	for i: int in 3:
		var m: Dictionary = {"league": "fair", "season": sn, "user": "ann", "opponent": "ben", "seed": i, "teams": [],
			"created_at": s.now(), "state": "submitted", "rated": true}
		s._table("league_matches", {})[str(600 + i)] = m
		s._league_apply(m, lost)
		assert_true(bool(m.sandbagged))
		assert_false(bool(m.rated))
	var real: Dictionary = {"league": "fair", "season": sn, "user": "ann", "opponent": "ben", "seed": 9, "teams": [],
		"created_at": s.now(), "state": "submitted", "rated": true}
	s._table("league_matches", {})["609"] = real
	s._league_apply(real, {"winner": "foe", "rounds": 6, "foe_damage": 40})
	assert_eq(int(s.league_entry("fair", sn, "ann").games), 11, "only the real loss is rated")
	var notes: Array = (s.db.users.ann.get("cheat_flags", []) as Array).filter(func(x: Dictionary) -> bool: return x.reason == "league_sandbag")
	assert_eq(notes.size(), 1, "noted from the third sandbagged battle")
	assert_true(SafetyRules.sandbagged(lost))
	assert_false(SafetyRules.sandbagged({"winner": "player", "foe_damage": 0}))
	assert_false(SafetyRules.sandbagged({"winner": "foe"}), "no damage count, no judgement")
	# 83: report the league rival, not someone else's battle.
	var rep: Dictionary = _as("ann", "report_battle", {"p_kind": "league", "p_ref": "609", "p_reason": 2})
	assert_true(bool(rep.ok))
	assert_eq(str(s.db.reports[-1].target), "ben")
	assert_eq(_as("kid", "report_battle", {"p_kind": "league", "p_ref": "609", "p_reason": 2}).error, "no_such_battle")
	assert_eq(_as("ann", "report_battle", {"p_kind": "shop", "p_ref": "1", "p_reason": 2}).error, "bad_context")
	assert_eq(_as("ann", "report_battle", {"p_kind": "league", "p_ref": "x1", "p_reason": 2}).error, "no_such_battle")

func test_suggestions_respect_the_switch() -> void:
	var sn: int = int(s.league_season().id)
	s._table("league_matches", {})["701"] = {"league": "fair", "season": sn, "user": "ann", "opponent": "kid", "seed": 1,
		"teams": [], "created_at": s.now(), "state": "done"}
	assert_eq(_as("ann", "friend_suggestions").rows, [], "a child is never suggested")
	_as("kid", "parent_set", {"p_off": [], "p_version": 1})
	assert_eq(_as("ann", "friend_suggestions").rows.size(), 1)
