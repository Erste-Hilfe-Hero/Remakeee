extends GutTest
## Trading and gifting between friends (Online 100, area 5, points 41-50) on the local stand-in
## of the server. The same cases as tools/online/sql_test/test_trade_gifts.sql.

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	for who: String in ["ben", "cid"]:
		s.switch_user(who)
		s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	s.call_fn("friend_respond", {"p_code": codes.cid, "p_accept": true})
	s.db.flags["trade"] = {"enabled": true, "min_version": 1}
	s.db.flags["lend"] = {"enabled": true, "min_version": 1}
	s._saves()["1"] = {"rev": 4, "summary": "", "saved_at": 0, "data": {"inventory": {"tonic": 5, "remedy": 3},
		"party": [{"uid": "m1", "species": "Kindlop", "level": 12, "nickname": "Bob", "held": "keen_lens", "origin_era": 2},
			{"uid": "m2", "species": "Zippit", "level": 9, "gleam": true}],
		"storage": [{"uid": "m3", "species": "Mossling", "level": 5}]}}
	s.switch_user("ben")
	s._saves()["2"] = {"rev": 9, "summary": "", "saved_at": 0, "data": {"inventory": {"remedy": 4}}}

func _as(who: String, fn: String, args: Dictionary = {}) -> Variant:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _close_friends() -> void:
	var f: Dictionary = s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]
	f.points = 30
	f.accepted_at = s.now() - 8 * 86400

func _friend(list: Dictionary, code: String) -> Dictionary:
	for f: Dictionary in list.friends:
		if str(f.code) == code:
			return f
	return {}

func test_two_gifts_a_day_from_level_3_and_wish_lists() -> void:
	assert_eq(int(_as("ann", "gift_send", {"p_code": codes.ben}).left), 0, "level 1: one gift")
	assert_eq(_as("ann", "gift_send", {"p_code": codes.ben}).error, "already_today")
	assert_eq(_as("ben", "wish_set", {"p_items": ["grapple_line"]}).error, "bad_wish", "gear is no wish")
	assert_eq(_as("ben", "wish_set", {"p_items": ["tonic", "remedy", "spark_drop", "keen_lens"]}).error, "bad_wish", "three at most")
	assert_eq(_as("ben", "wish_set", {"p_items": ["tonic", "tonic"]}).error, "bad_wish", "no wish twice")
	assert_eq(_as("ben", "wish_set", {"p_items": ["tonic", "keen_lens"]}).wishes, ["tonic", "keen_lens"])
	assert_eq(_as("ben", "wish_get").wishes, ["tonic", "keen_lens"])
	_close_friends()
	assert_true(bool(_as("ann", "gift_send", {"p_code": codes.ben}).ok), "level 3: a second gift")
	assert_eq(_as("ann", "gift_send", {"p_code": codes.ben}).error, "already_today", "two at most")
	var list: Dictionary = _as("ann", "friends_list")
	var ben: Dictionary = _friend(list, codes.ben)
	assert_eq(ben.wishes, ["tonic", "keen_lens"], "friends see the wish list")
	assert_eq(int(ben.gifts_left), 0)
	assert_true(bool(ben.gift_sent))
	assert_eq(int(_friend(list, codes.cid).gifts_left), 1, "one gift for a new friend")

func test_cards_show_a_spirling_of_the_own_journey() -> void:
	assert_eq(_as("ann", "card_send", {"p_code": codes.ben, "p_species": "Voidmaw", "p_phrase": 1}).error, "no_species")
	assert_eq(_as("ann", "card_send", {"p_code": codes.ben, "p_species": "Mossling", "p_phrase": 31}).error, "bad_phrase")
	assert_eq(_as("ann", "card_send", {"p_code": "ZZZZZZZZ", "p_species": "Mossling", "p_phrase": 1}).error, "not_friends")
	assert_true(bool(_as("ann", "card_send", {"p_code": codes.ben, "p_species": "Mossling", "p_phrase": 1}).ok))
	var mail: Array = _as("ben", "mail_list")
	assert_eq(str(mail[0].kind), "card")
	assert_eq(str(mail[0].species), "Mossling")
	assert_eq(FriendsMenu.mail_line(mail[0]), "! %s sent a card with Mossling: %s" % [str(mail[0].name), Phrases.text(1)])

func test_thanks_for_a_gift_once_with_points_for_both() -> void:
	_close_friends()
	_as("ann", "gift_send", {"p_code": codes.ben})
	var id: int = int(_as("ben", "mail_list")[0].id)
	assert_eq(_as("ben", "gift_thank", {"p_id": id}).error, "open_first")
	_as("ben", "gift_open", {"p_id": id})
	assert_eq(int(_as("ben", "gift_thank", {"p_id": id}).points), 2)
	assert_eq(_as("ben", "gift_thank", {"p_id": id}).error, "already")
	assert_true(bool(_as("ben", "mail_list")[0].thanked))
	var f: Dictionary = s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]
	assert_eq(int(f.points), 33, "gift point plus 2 thanks points")
	assert_eq(str(_as("ann", "mail_list")[0].kind), "thanks", "the friend gets a thanks note")

func test_one_trade_a_day_when_the_limit_is_1_and_a_30_day_history() -> void:
	_close_friends()
	s.db.config["trade_gifts"] = {"trades_per_day": 1}
	var tid: int = int(_as("ann", "trade_open", {"p_code": codes.ben}).trade)
	_as("ann", "trade_put", {"p_trade": tid, "p_slot": 1, "p_rev": 4, "p_items": {"tonic": 2}})
	_as("ben", "trade_put", {"p_trade": tid, "p_slot": 2, "p_rev": 9, "p_items": {"remedy": 1}})
	_as("ben", "trade_confirm", {"p_trade": tid, "p_theirs": {"tonic": 2}, "p_their_mons": []})
	assert_true(bool(_as("ann", "trade_confirm", {"p_trade": tid, "p_theirs": {"remedy": 1}, "p_their_mons": []}).done))
	_as("ann", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 5})
	var t2: int = int(_as("ann", "trade_open", {"p_code": codes.ben}).trade)
	_as("ann", "trade_put", {"p_trade": t2, "p_slot": 1, "p_rev": 6, "p_items": {"tonic": 1}})
	assert_eq(_as("ann", "trade_confirm", {"p_trade": t2, "p_theirs": {}, "p_their_mons": []}).error, "day_limit")
	var h: Dictionary = _as("ann", "trade_history")
	assert_eq(h.rows.size(), 1)
	assert_eq(h.rows[0].gave, {"tonic": 2})
	assert_eq(h.rows[0].got, {"remedy": 1})
	assert_eq(int(h.today), 1)
	var h2: Dictionary = _as("ben", "trade_history")
	assert_eq(h2.rows[0].gave, {"remedy": 1}, "the other side sees its own view")
	assert_not_null(h2.rows[0].name)
	for r: Dictionary in s.db.trade_log:
		r.at = s.now() - 31 * 86400
	assert_eq(_as("ann", "trade_history").rows.size(), 0, "history keeps 30 days")

func test_lending_a_copy_for_one_raid_or_live_duel() -> void:
	assert_eq(_as("ann", "lend_offer", {"p_code": codes.cid, "p_slot": 1, "p_uid": "m3"}).error, "friend_level")
	_close_friends()
	assert_eq(_as("ann", "lend_offer", {"p_code": codes.ben, "p_slot": 1, "p_uid": "m2"}).error, "shop_boosted")
	assert_eq(_as("ann", "lend_offer", {"p_code": codes.ben, "p_slot": 1, "p_uid": "zz"}).error, "no_spirling")
	var loan: int = int(_as("ann", "lend_offer", {"p_code": codes.ben, "p_slot": 1, "p_uid": "m1"}).loan)
	assert_eq(_as("ann", "lend_offer", {"p_code": codes.ben, "p_slot": 1, "p_uid": "m3"}).error, "friend_has_one")
	var m: Dictionary = _as("ben", "lend_list").borrowed[0].mon
	assert_eq(str(m.species), "Kindlop")
	assert_eq(int(m.level), 12)
	assert_false(m.has("nickname"), "no nickname travels")
	assert_false(m.has("held"), "no Keepsake travels")
	assert_eq(_as("ben", "lend_use", {"p_loan": loan, "p_kind": "league"}).error, "bad_kind")
	assert_eq(str(_as("ben", "lend_use", {"p_loan": loan, "p_kind": "raid"}).mon.species), "Kindlop")
	assert_eq(_as("ben", "lend_use", {"p_loan": loan, "p_kind": "raid"}).error, "used", "one battle only")
	assert_eq(_as("ben", "lend_end", {"p_loan": loan}).error, "no_such_loan")
	s.switch_user("ann")
	assert_eq((s._saves()["1"].data.party as Array).size(), 2, "the original stays with the lender")
	s.clock_offset = 49 * 3600
	assert_eq(_as("ben", "lend_list").borrowed.size(), 0, "loans end after their time")

func test_lend_flag_starts_off_and_config_matches_the_server() -> void:
	var fresh := LocalBackend.new()
	assert_false(fresh.flag_on("lend", 99))
	var sql: String = FileAccess.get_file_as_string("res://supabase/migrations/20261112000050_trade_gifts.sql")
	var cfg: Dictionary = LocalTradeGifts.config()
	for k: String in LocalTradeGifts.DEFAULTS:
		assert_eq(int(cfg.get(k, -1)), int(LocalTradeGifts.DEFAULTS[k]), "data/trade_gifts.json has %s" % k)
		assert_true(sql.contains("\"%s\": %d" % [k, int(LocalTradeGifts.DEFAULTS[k])]), "the migration's default for %s" % k)

func test_history_and_card_texts() -> void:
	assert_eq(TradeMenu.history_line({"name": "Ben", "gave": {"tonic": 2}, "got": {"remedy": 1}, "gave_mons": [], "got_mons": []}),
		"Ben: gave Tonic x2, got Remedy")
	assert_eq(FriendsMenu.wish_text(["tonic", "remedy"]), "Wishes: Tonic, Remedy")
	assert_eq(FriendsMenu.wish_text([]), "Wishes: -")
