extends GutTest
## Trading (plan area 7, items 2791-2795, 2900) on the local stand-in of the server. The same
## cases as tools/online/sql_test/test_trade.sql.

var s: LocalBackend
var codes: Dictionary = {}
var tid: int = 0

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.switch_user("ben")
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	s.db.flags["trade"] = {"enabled": true, "min_version": 1}

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _ready_pair() -> void:
	var f: Dictionary = s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]
	f.points = 30
	f.accepted_at = s.now() - 8 * 86400
	s.switch_user("ann")
	s._saves()["1"] = {"rev": 4, "data": {"inventory": {"tonic": 5, "keen_lens": 1, "grapple_line": 1}}, "summary": "", "saved_at": 0}
	s.switch_user("ben")
	s._saves()["2"] = {"rev": 9, "data": {"inventory": {"remedy": 2}}, "summary": "", "saved_at": 0}
	tid = int(_as("ann", "trade_open", {"p_code": codes.ben}).trade)

func _bag(who: String, slot: int) -> Dictionary:
	s.switch_user(who)
	return s._saves()[str(slot)].data.inventory

func test_only_older_friends_from_level_3() -> void:
	assert_eq(_as("ann", "trade_open", {"p_code": codes.ben}).error, "friend_level")
	assert_eq(_as("ann", "trade_open", {"p_code": codes.cid}).error, "no_such_code")
	var f: Dictionary = s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]
	assert_gt(int(f.accepted_at), 0, "accepting stores the time")
	f.points = 30
	assert_eq(_as("ann", "trade_open", {"p_code": codes.ben}).error, "too_new")
	f.accepted_at = s.now() - 8 * 86400
	var r: Dictionary = _as("ann", "trade_open", {"p_code": codes.ben})
	assert_true(bool(r.ok))
	assert_eq(int(_as("ben", "trade_open", {"p_code": codes.ann}).trade), int(r.trade), "one open trade per pair")
	s.db.flags["trade"] = {"enabled": false, "min_version": 1}
	assert_eq(_as("ann", "trade_open", {"p_code": codes.ben}).error, "feature_off")

func test_offers_leave_the_bag_and_changes_reset_both() -> void:
	_ready_pair()
	assert_eq(_as("ann", "trade_put", {"p_trade": tid, "p_slot": 1, "p_rev": 4, "p_items": {"grapple_line": 1}}).error, "not_tradeable")
	assert_eq(_as("ann", "trade_put", {"p_trade": tid, "p_slot": 1, "p_rev": 4, "p_items": {"rg_ring_tonic": 1}}).error, "not_tradeable")
	assert_eq(_as("ann", "trade_put", {"p_trade": tid, "p_slot": 1, "p_rev": 3, "p_items": {"tonic": 2}}).error, "sync_first")
	assert_eq(_as("ann", "trade_put", {"p_trade": tid, "p_slot": 1, "p_rev": 4, "p_items": {"tonic": 6}}).error, "not_enough")
	var r: Dictionary = _as("ann", "trade_put", {"p_trade": tid, "p_slot": 1, "p_rev": 4, "p_items": {"tonic": 3, "keen_lens": 1}})
	assert_eq(r.bag, {"tonic": -3, "keen_lens": -1})
	assert_eq(int(r.rev), 5)
	assert_eq(_bag("ann", 1), {"tonic": 2, "grapple_line": 1})
	_as("ben", "trade_put", {"p_trade": tid, "p_slot": 2, "p_rev": 9, "p_items": {"remedy": 2}})
	assert_false(bool(_as("ann", "trade_confirm", {"p_trade": tid, "p_theirs": {"remedy": 2}}).done))
	r = _as("ann", "trade_put", {"p_trade": tid, "p_slot": 1, "p_rev": 5, "p_items": {"tonic": 1}})
	assert_eq(r.bag, {"tonic": 2, "keen_lens": 1}, "the rest comes back")
	assert_eq(_as("ben", "trade_confirm", {"p_trade": tid, "p_theirs": {"tonic": 3, "keen_lens": 1}}).error, "changed")
	assert_false(bool(_as("ben", "trade_confirm", {"p_trade": tid, "p_theirs": {"tonic": 1}}).done), "ann has to confirm again")
	assert_false(bool(_as("ben", "trade_list").trades[0].their_ok))
	assert_true(bool(_as("ann", "trade_confirm", {"p_trade": tid, "p_theirs": {"remedy": 2}}).done))
	assert_eq(_as("ann", "trade_put", {"p_trade": tid, "p_slot": 1, "p_rev": 6, "p_items": {"tonic": 2}}).error, "no_such_trade")
	assert_eq(_as("ann", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 6}).bag, {"remedy": 2})
	assert_eq(_as("ann", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 7}).error, "already")
	assert_eq(_as("ben", "trade_collect", {"p_trade": tid, "p_slot": 2, "p_rev": 10}).bag, {"tonic": 1})
	assert_eq(_bag("ann", 1), {"tonic": 4, "keen_lens": 1, "remedy": 2, "grapple_line": 1})
	assert_eq(_bag("ben", 2), {"tonic": 1})
	assert_false((s.db.trades as Dictionary).has(str(tid)), "a collected trade goes away")

func test_blocking_ends_trading_and_ending_gives_items_back() -> void:
	_ready_pair()
	_as("ann", "trade_put", {"p_trade": tid, "p_slot": 1, "p_rev": 4, "p_items": {"tonic": 4}})
	_as("ben", "block", {"p_code": codes.ann})
	assert_eq(_as("ben", "trade_put", {"p_trade": tid, "p_slot": 2, "p_rev": 9, "p_items": {"remedy": 1}}).error, "partner_gone")
	assert_eq(_as("ben", "trade_open", {"p_code": codes.ann}).error, "no_such_code")
	assert_null(_as("ann", "trade_list").trades[0].name, "a blocked player's name is not shown")
	assert_true(bool(_as("ann", "trade_cancel", {"p_trade": tid}).ok))
	assert_eq(_as("ann", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 5}).bag, {"tonic": 4})
	assert_eq(int(_bag("ann", 1).tonic), 5)

func test_open_trades_end_after_7_days_and_deleting_keeps_the_other_side() -> void:
	_ready_pair()
	_as("ben", "trade_put", {"p_trade": tid, "p_slot": 2, "p_rev": 9, "p_items": {"remedy": 2}})
	_as("ann", "delete_account")
	var t: Dictionary = _as("ben", "trade_list").trades[0]
	assert_null(t.name)
	assert_eq(_as("ben", "trade_put", {"p_trade": tid, "p_slot": 2, "p_rev": 10, "p_items": {}}).error, "partner_gone")
	s.db.trades[str(tid)].closes_at = s.now() - 1
	t = _as("ben", "trade_list").trades[0]
	assert_eq(t.state, "cancelled")
	assert_true(bool(t.collect))
	assert_eq(_as("ben", "trade_collect", {"p_trade": tid, "p_slot": 2, "p_rev": 10}).bag, {"remedy": 2})

func test_tradeable_items_are_never_shop_items_and_match_the_server() -> void:
	var tradeable: Array = s.trade_items()
	assert_true(tradeable.has("tonic"))
	assert_false(tradeable.has("grapple_line"), "gear stays with its owner")
	var shop: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop.json"))
	for o: Dictionary in shop.offers:
		for g: Dictionary in o.get("grants", []):
			if str(g.get("t", "")) == "item":
				assert_false(tradeable.has(str(g.get("id", ""))), "shop item %s is never tradeable (2793)" % g.get("id"))
	var sql: String = FileAccess.get_file_as_string("res://supabase/migrations/20261110000012_trades.sql")
	var at: int = sql.find("('trade_items', '")
	var listed: Variant = JSON.parse_string(sql.substr(at + 17, sql.find("')", at) - at - 17))
	assert_eq(listed, tradeable, "the migration seeds the same list as data/items.json")

func test_offer_texts() -> void:
	assert_eq(TradeMenu.offer_text({}), "nothing")
	assert_eq(TradeMenu.offer_text({"tonic": 3, "keen_lens": 1}), "Whetstone, Tonic x3")
	assert_eq(TradeMenu.trade_line({"name": "Ben", "state": "open", "collect": false, "my_ok": true, "their_ok": false}), "Ben  you confirmed")
