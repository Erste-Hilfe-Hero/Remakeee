extends GutTest
## Wish lists, two gifts a day from friendship 3, thanks bonus, trade history (Online 100, points
## 46, 47, 49, 50). The same cases as tools/online/sql_test/test_gift_more.sql.

var s: LocalBackend
var codes: Dictionary = {}

func before_each() -> void:
	s = LocalBackend.new()
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	_as("ben", "friend_request", {"p_code": codes.ann})
	_as("ann", "friend_respond", {"p_code": codes.ben, "p_accept": true})

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _pair() -> Dictionary:
	return s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]

func test_two_gifts_from_friendship_three() -> void:
	assert_true(bool(_as("ann", "gift_send", {"p_code": codes.ben}).ok))
	assert_eq(_as("ann", "gift_send", {"p_code": codes.ben}).error, "already_today")
	_pair().points = 30
	assert_true(bool(_as("ann", "gift_send", {"p_code": codes.ben}).ok), "level 3: a second gift")
	assert_eq(_as("ann", "gift_send", {"p_code": codes.ben}).error, "already_today")

func test_thanks_gives_a_point_once_a_day() -> void:
	_as("ann", "gift_send", {"p_code": codes.ben})
	var before: int = int(_pair().points)
	assert_true(bool(_as("ben", "mail_send", {"p_code": codes.ann, "p_kind": "thanks", "p_phrase": 0}).bonus))
	assert_eq(int(_pair().points), before + 1)
	assert_false(bool(_as("ben", "mail_send", {"p_code": codes.ann, "p_kind": "thanks", "p_phrase": 0}).bonus))
	assert_false(bool(_as("ann", "mail_send", {"p_code": codes.ben, "p_kind": "thanks", "p_phrase": 0}).bonus), "no gift from ben")

func test_wish_list() -> void:
	assert_eq(_as("ann", "wish_set", {"p_items": ["tonic", "nothing_real"]}).error, "bad_wish")
	assert_eq(_as("ann", "wish_set", {"p_items": ["tonic", "tonic"]}).error, "bad_wish")
	assert_eq(_as("ann", "wish_set", {"p_items": ["tonic", "remedy", "wake_bell", "dry_towel"]}).error, "bad_wish")
	assert_true(bool(_as("ann", "wish_set", {"p_items": ["tonic", "revival_leaf"]}).ok))
	assert_eq(_as("ben", "wish_get", {"p_code": codes.ann}).wishes, ["tonic", "revival_leaf"])
	assert_eq(_as("cid", "wish_get", {"p_code": codes.ann}).error, "not_friends")
	assert_string_contains(FriendsMenu.wish_text("Ann", ["tonic"]), "Ann")

func test_trade_history_of_30_days() -> void:
	s.db["trades"] = {"7": {"state": "done", "created_at": s.now(), "closes_at": s.now(), "done_at": s.now()},
		"8": {"state": "done", "created_at": s.now(), "closes_at": s.now(), "done_at": s.now() - 31 * 86400}}
	var a: String = s.uid_for_code(codes.ann)
	var b: String = s.uid_for_code(codes.ben)
	s.db["trade_sides"] = {"7|" + a: {"items": {"tonic": 2}, "mons": []}, "7|" + b: {"items": {"remedy": 1}, "mons": [{}]},
		"8|" + a: {"items": {"tonic": 1}, "mons": []}, "8|" + b: {"items": {}, "mons": []}}
	var h: Array = _as("ann", "trade_history").trades
	assert_eq(h.size(), 1)
	assert_eq(h[0].gave, {"tonic": 2})
	assert_eq(h[0].got, {"remedy": 1})
	assert_eq(int(h[0].got_mons), 1)
	assert_string_contains(FriendsMenu.history_text(h), "Wanderer")
