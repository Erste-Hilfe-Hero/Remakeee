extends GutTest
## Online step 1 on the local stand-in of the server: Spirling trading between friends, the
## weekly Rift and league boards and the daily online gift. The same cases as
## tools/online/sql_test/test_online_step1.sql.

var s: LocalBackend
var codes: Dictionary = {}
var tid: int = 0

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.switch_user("ben")
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	for f: String in ["trade", "trade_spirling", "rift_board", "league_board", "daily_gift"]:
		s.db.flags[f] = {"enabled": true, "min_version": 1}

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _save(who: String) -> Dictionary:
	s.switch_user(who)
	return s._saves()["1"].data

func _ready_pair() -> void:
	var f: Dictionary = s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]
	f.points = 30
	f.accepted_at = s.now() - 8 * 86400
	s.switch_user("ann")
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {"tonic": 1},
		"party": [{"uid": "a1", "species": "Kindlop", "level": 12, "nickname": "Bob", "origin_era": 2, "box": 3},
			{"uid": "a2", "species": "Zippit", "level": 9}],
		"storage": [{"uid": "a3", "species": "Wickit", "level": 5, "held": "keen_lens"},
			{"uid": "a4", "species": "Wickit", "level": 5, "gleam": true},
			{"uid": "a5", "species": "Wickit", "level": 5, "favorite": true}]}}
	s.switch_user("ben")
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {},
		"party": [{"uid": "b1", "species": "Zippit", "level": 20}],
		"storage": [{"uid": "b2", "species": "Kindlop", "level": 15}]}}
	tid = int(_as("ann", "trade_open", {"p_code": codes.ben}).trade)

func _put(who: String, rev: int, uids: Array) -> Dictionary:
	return _as(who, "trade_put_spirlings", {"p_trade": tid, "p_slot": 1, "p_rev": rev, "p_uids": uids})

func _find(list: Array, uid: String) -> Dictionary:
	for m: Dictionary in list:
		if str(m.uid) == uid:
			return m
	return {}

func test_only_tradeable_spirlings_leave_the_save() -> void:
	_ready_pair()
	assert_eq(_put("ann", 1, ["a3"]).error, "holds_item")
	assert_eq(_put("ann", 1, ["a4"]).error, "shop_boosted")
	assert_eq(_put("ann", 1, ["a5"]).error, "favorite")
	assert_eq(_put("ann", 1, ["zz"]).error, "no_spirling")
	assert_eq(_put("ann", 1, ["a1", "a2"]).error, "last_one")
	assert_eq(_put("ann", 1, ["a1", "a2", "a3", "a4"]).error, "too_many_spirlings")
	assert_eq(_put("ann", 0, ["a1"]).error, "sync_first")
	var r: Dictionary = _put("ann", 1, ["a1"])
	assert_eq(r.took, ["a1"])
	assert_eq(int(r.rev), 2)
	assert_true(_find(_save("ann").party, "a1").is_empty(), "a1 waits on the server")
	s.db.flags["trade_spirling"] = {"enabled": false, "min_version": 1}
	assert_eq(_put("ann", 2, []).error, "feature_off")

func test_both_confirm_and_the_origin_era_stays() -> void:
	_ready_pair()
	_put("ann", 1, ["a1"])
	_put("ben", 1, ["b2"])
	var seen: Dictionary = _as("ben", "trade_list").trades[0]
	assert_eq(seen.theirs_mons[0].uid, "a1")
	assert_false(seen.theirs_mons[0].has("nickname"), "no nickname travels")
	assert_eq(_as("ann", "trade_confirm", {"p_trade": tid, "p_theirs": {}}).error, "changed", "older builds cannot confirm unseen Spirlings")
	assert_eq(_as("ann", "trade_confirm", {"p_trade": tid, "p_theirs": {}, "p_their_mons": ["b1"]}).error, "changed")
	assert_false(bool(_as("ann", "trade_confirm", {"p_trade": tid, "p_theirs": {}, "p_their_mons": ["b2"]}).done))
	assert_true(bool(_as("ben", "trade_confirm", {"p_trade": tid, "p_theirs": {}, "p_their_mons": ["a1"]}).done))
	assert_eq(_as("ben", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 2}).mons[0].uid, "a1")
	assert_eq(_as("ann", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 2}).mons[0].uid, "b2")
	var got: Dictionary = _find(_save("ben").storage, "a1")
	assert_eq(int(got.origin_era), 2, "origin era kept")
	assert_eq(int(got.level), 12, "values kept")
	assert_false(got.has("box"))
	assert_eq(int(_find(_save("ann").storage, "b2").origin_era), 1, "older saves count as era 1")
	assert_eq(_save("ann").party.size(), 1)

func test_cancel_gives_the_spirling_back() -> void:
	_ready_pair()
	_put("ann", 1, ["a1"])
	assert_true(bool(_as("ann", "trade_cancel", {"p_trade": tid}).ok))
	var r: Dictionary = _as("ann", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 2})
	assert_eq(r.mons[0].uid, "a1")
	assert_false(_find(_save("ann").storage, "a1").is_empty(), "back in storage")

func test_mon_rules_match_the_server() -> void:
	assert_eq(LocalBackend.trade_mon_why({"uid": "x", "species": "Kindlop", "crystal": {"atk": 1}}), "shop_boosted")
	assert_eq(LocalBackend.trade_mon_why({"uid": "x", "species": "Kindlop", "core": true}), "shop_boosted")
	assert_eq(LocalBackend.trade_mon_why({"uid": "x", "species": "Kindlop", "crystal": {}}), "")
	var c: Dictionary = LocalBackend.trade_mon_clean({"uid": "x", "nickname": "Hi", "origin_era": 9, "favorite": false})
	assert_eq(c, {"uid": "x", "origin_era": 1})

func test_spirling_keeps_origin_era_in_saves() -> void:
	var sp := Spirling.new(Database.species("Kindlop"), 5)
	sp.origin_era = 3
	assert_eq(Spirling.from_dict(sp.to_dict()).origin_era, 3)
	var d: Dictionary = sp.to_dict()
	d.erase("origin_era")
	assert_eq(Spirling.from_dict(d).origin_era, 1, "older saves: era I")

func test_rift_board_counts_checked_wins_only() -> void:
	s.referee_waits = true
	var claim: Dictionary = {"winner": "player", "rounds": 7}
	assert_eq(_as("ann", "battle_submit", {"p_kind": "rift", "p_ref": "nowhere", "p_replay": {"teams": []}, "p_claim": claim}).error, "no_such_rift")
	assert_eq(_as("ann", "battle_submit", {"p_kind": "rift", "p_ref": "cinder", "p_replay": {"teams": []},
		"p_claim": {"winner": "foe", "rounds": 7}}).error, "bad_battle")
	var a1: int = int(_as("ann", "battle_submit", {"p_kind": "rift", "p_ref": "cinder", "p_replay": {"teams": []}, "p_claim": claim}).battle_id)
	var a2: int = int(_as("ann", "battle_submit", {"p_kind": "rift", "p_ref": "cinder", "p_replay": {"teams": []},
		"p_claim": {"winner": "player", "rounds": 9}}).battle_id)
	var b1: int = int(_as("ben", "battle_submit", {"p_kind": "rift", "p_ref": "cinder", "p_replay": {"teams": []},
		"p_claim": {"winner": "player", "rounds": 5}}).battle_id)
	var b2: int = int(_as("ben", "battle_submit", {"p_kind": "rift", "p_ref": "cinder", "p_replay": {"teams": []},
		"p_claim": {"winner": "player", "rounds": 8}}).battle_id)
	assert_eq(_as("ben", "rift_board", {"p_rift": "cinder", "p_friends": true}).rows, [], "nothing before the referee")
	for id: int in [a1, a2, b2]:
		s.db.battles[str(id)].status = "ok"
	s.db.battles[str(b1)].status = "mismatch"
	var rows: Array = _as("ben", "rift_board", {"p_rift": "cinder", "p_friends": true}).rows
	assert_eq(rows.size(), 2)
	assert_eq(int(rows[0].score), 7)
	assert_false(bool(rows[0].me))
	assert_eq(int(rows[1].score), 8)
	assert_true(bool(rows[1].me))
	var world: Array = _as("cid", "rift_board", {"p_rift": "cinder", "p_friends": false}).rows
	assert_eq(world.size(), 2)
	assert_eq(str(world[0].name), "", "strangers have no name")
	assert_eq(_as("cid", "rift_board", {"p_rift": "cinder", "p_friends": true}).rows, [])

func test_league_board_counts_rated_wins_of_this_week() -> void:
	var ann: String = s.uid_for_code(codes.ann)
	var ben: String = s.uid_for_code(codes.ben)
	var m: Dictionary = s._table("league_matches", {})
	var rows: Array = [[ann, "done", true, 1.0, 0], [ann, "done", true, 1.0, 0], [ann, "done", true, 0.0, 0],
		[ben, "done", true, 1.0, 0], [ben, "done", false, 1.0, 0], [ben, "done", true, 1.0, 8 * 86400]]
	for i: int in rows.size():
		var r: Array = rows[i]
		m[str(i + 1)] = {"league": "fair", "season": 1, "user": r[0], "state": r[1], "rated": r[2], "score": r[3],
			"created_at": s.now() - int(r[4])}
	var b: Array = _as("ben", "league_board", {"p_league": "fair", "p_friends": true}).rows
	assert_eq(int(b[0].score), 2)
	assert_eq(int(b[1].score), 1)
	assert_true(bool(b[1].me))
	assert_eq(_as("ben", "league_board", {"p_league": "gold", "p_friends": true}).error, "bad_league")

func test_daily_gift_once_a_day_into_the_saved_bag() -> void:
	s.switch_user("ben")
	s._saves()["1"] = {"rev": 3, "summary": "", "saved_at": 0, "data": {"inventory": {}}}
	s.db.flags["daily_gift"] = {"enabled": false, "min_version": 1}
	assert_eq(_as("ben", "daily_gift_claim", {"p_slot": 1, "p_rev": 3}).error, "feature_off")
	s.db.flags["daily_gift"] = {"enabled": true, "min_version": 1}
	assert_true(bool(_as("ben", "daily_gift_state").ready))
	assert_eq(_as("ben", "daily_gift_claim", {"p_slot": 1, "p_rev": 1}).error, "sync_first")
	var r: Dictionary = _as("ben", "daily_gift_claim", {"p_slot": 1, "p_rev": 3})
	assert_true(bool(r.ok))
	assert_eq(int(_save("ben").inventory.get(str(r.item), 0)), 1)
	assert_eq(_as("ben", "daily_gift_claim", {"p_slot": 1, "p_rev": 4}).error, "already_today")
	assert_false(bool(_as("ben", "daily_gift_state").ready))
	s.clock_offset += 86400
	assert_true(bool(_as("ben", "daily_gift_state").ready), "a new gift the next day")

func test_daily_gift_table_has_no_shop_items_and_matches_the_server() -> void:
	var table: Array = LocalBackend.DEFAULT_CONFIG.daily_gift_table
	var ids: Array = table.map(func(e: Dictionary) -> String: return str(e.item))
	var shop: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop.json"))
	for o: Dictionary in shop.offers:
		for g: Dictionary in o.get("grants", []):
			assert_false(ids.has(str(g.get("id", ""))), "shop item %s is never a daily gift" % g.get("id"))
	for id: String in ids:
		assert_false(Database.item(id).is_empty(), "%s is a game item" % id)
	var sql: String = FileAccess.get_file_as_string("res://supabase/migrations/20261111000001_online_step1.sql")
	var at: int = sql.find("('daily_gift_table', '")
	var listed: Variant = JSON.parse_string(sql.substr(at + 22, sql.find("')", at) - at - 22))
	assert_true(listed is Array and (listed as Array).size() == table.size(), "the migration seeds the same table")
	for i: int in mini(table.size(), (listed as Array).size() if listed is Array else 0):
		assert_eq(str(listed[i].item), str(table[i].item))
		assert_eq(int(listed[i].w), int(table[i].w))

func test_known_rifts_come_from_the_maps() -> void:
	var rifts: Array = LocalBackend.known_rifts()
	for r: String in ["cinder", "mist", "tide"]:
		assert_true(rifts.has(r), r)

func test_trade_menu_texts() -> void:
	assert_eq(TradeMenu.mons_text([{"species": "Kindlop", "level": 12, "origin_era": 2}]), "Kindlop R12 Era II")
	assert_eq(TradeMenu.side_text({"tonic": 2}, [{"species": "Zippit", "level": 3}]), "Tonic x2, Zippit R3 Era I")
	assert_eq(TradeMenu.uids([{"uid": "a"}, {"uid": "b"}]), ["a", "b"] as Array[String])
	assert_eq(FriendsMenu.rift_name("cinder"), "Cinder Rift")
