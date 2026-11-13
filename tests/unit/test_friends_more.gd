extends GutTest
## Friends and the shared world (Online 100, area 6, points 53, 55, 56, 57, 59, 60) on the local
## stand-in of the server. The same cases as tools/online/sql_test/test_friends_more.sql.

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	for who: String in ["ann", "ben", "cid", "dan", "eve"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	for who: String in ["ben", "cid"]:
		s.switch_user(who)
		s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	s.call_fn("friend_respond", {"p_code": codes.cid, "p_accept": true})
	s.db.config["friends_more"] = {"favorites_max": 1, "pair_tasks": ["wave"]}
	s._saves()["1"] = {"rev": 4, "summary": "", "saved_at": 0, "data": {"inventory": {"tonic": 1}}}
	s.switch_user("ben")
	s._saves()["2"] = {"rev": 9, "summary": "", "saved_at": 0, "data": {"inventory": {}}}
	s.switch_user("eve")
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {}}}
	_pair("ann", "ben").points = 160
	var sn: Dictionary = s.league_season()
	s._table("league_fair", {})["%d|ben" % int(sn.id)] = {"team": [], "rating": 1720.0, "rd": 50.0, "vol": 0.06, "games": 10, "wins": 6}

func _as(who: String, fn: String, args: Dictionary = {}) -> Variant:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _pair(x: String, y: String) -> Dictionary:
	return s.db.friendships[LocalBackend.pair_key(x, y)]

func _friend(list: Dictionary, code: String) -> Dictionary:
	for f: Dictionary in list.friends:
		if str(f.code) == code:
			return f
	return {}

func _inv(who: String, slot: String) -> Dictionary:
	s.switch_user(who)
	return s._saves()[slot].data.inventory

func test_levels_6_to_10_and_their_rewards() -> void:
	assert_eq(LocalBackend.level_for(0), 1)
	assert_eq(LocalBackend.level_for(100), 5, "levels 1-5 stay")
	assert_eq(LocalBackend.level_for(149), 5)
	assert_eq(LocalBackend.level_for(150), 6)
	assert_eq(LocalBackend.level_for(519), 9)
	assert_eq(LocalBackend.level_for(520), 10)
	assert_eq(LocalBackend.level_for(100000), 10)
	var ben: Dictionary = _friend(_as("ann", "friends_list"), codes.ben)
	assert_eq(int(ben.level), 6)
	assert_eq(ben.level_ready, [6])
	assert_eq(int(ben.rank), 4, "card shows the league rank")
	assert_eq(_as("ann", "friend_level_claim", {"p_code": codes.ben, "p_level": 7, "p_slot": 1, "p_rev": 4}).error, "friend_level")
	var r: Dictionary = _as("ann", "friend_level_claim", {"p_code": codes.ben, "p_level": 6, "p_slot": 1, "p_rev": 4})
	assert_eq(str(r.item), "strong_tonic")
	assert_eq(int(r.rev), 5)
	assert_eq(r.bag, {"strong_tonic": 3})
	assert_eq(_as("ann", "friend_level_claim", {"p_code": codes.ben, "p_level": 6, "p_slot": 1, "p_rev": 5}).error, "already")
	assert_eq(_as("ann", "friend_level_claim", {"p_code": codes.cid, "p_level": 6, "p_slot": 1, "p_rev": 5}).error, "friend_level")
	assert_eq(int(_inv("ann", "1").strong_tonic), 3, "reward in the bag")
	assert_eq(_friend(_as("ann", "friends_list"), codes.ben).level_ready, [], "taken reward is gone")
	assert_true("friend_level_claim" in LocalBackend.SAVE_WRITERS)

func test_favourites_come_first() -> void:
	assert_true(bool(_as("ann", "friend_favorite", {"p_code": codes.cid, "p_on": true}).fav))
	assert_eq(_as("ann", "friend_favorite", {"p_code": codes.ben, "p_on": true}).error, "favorites_full")
	assert_eq(_as("ann", "friend_favorite", {"p_code": codes.dan, "p_on": true}).error, "not_friends")
	var list: Dictionary = _as("ann", "friends_list")
	assert_eq(str(list.friends[0].code), codes.cid, "favourite first")
	assert_true(bool(list.friends[0].fav))
	assert_true(FriendsMenu.friend_line(list.friends[0]).contains("+"), "marked in the list")
	_as("ann", "friend_favorite", {"p_code": codes.cid, "p_on": false})
	assert_true(bool(_as("ann", "friend_favorite", {"p_code": codes.ben, "p_on": true}).ok), "room again")

func test_joint_task_of_the_day() -> void:
	_as("ann", "mail_send", {"p_code": codes.ben, "p_kind": "wave", "p_phrase": 0})
	assert_eq(_as("ann", "pair_task_claim", {"p_code": codes.ben, "p_slot": 1, "p_rev": 4}).error, "not_done")
	_as("ben", "mail_send", {"p_code": codes.ann, "p_kind": "wave", "p_phrase": 0})
	var ben: Dictionary = _friend(_as("ann", "friends_list"), codes.ben)
	assert_true(FriendsMoreMenu.has_ready(ben), "the list shows the reward")
	var r: Dictionary = _as("ann", "pair_task_claim", {"p_code": codes.ben, "p_slot": 1, "p_rev": 4})
	assert_eq(str(r.item), "tonic")
	assert_eq(int(r.count), 2)
	assert_eq(_as("ann", "pair_task_claim", {"p_code": codes.ben, "p_slot": 1, "p_rev": 5}).error, "already_today")
	assert_true(bool(_as("ben", "pair_task_claim", {"p_code": codes.ann, "p_slot": 2, "p_rev": 9}).ok), "the friend takes it too")
	assert_eq(int(_pair("ann", "ben").points), 163, "pair points once")
	ben = _friend(_as("ann", "friends_list"), codes.ben)
	assert_eq(ben.task, {"kind": "wave", "mine": true, "theirs": true, "claimed": true})
	assert_string_contains(FriendsMoreMenu.task_text(ben), "Wave to each other")

func test_pair_kind_turns_by_day() -> void:
	var c: Dictionary = {"pair_tasks": ["wave", "phrase", "gift"]}
	assert_eq(FriendRules.pair_kind(c, 0), "wave")
	assert_eq(FriendRules.pair_kind(c, 86400), "phrase")
	assert_eq(FriendRules.pair_kind(c, 2 * 86400 + 5), "gift")
	assert_eq(FriendRules.pair_kind(c, 3 * 86400), "wave")

func test_recent_league_opponents_as_suggestions() -> void:
	var sn: int = int(s.league_season().id)
	var m: Dictionary = s._table("league_matches", {})
	m["101"] = {"league": "fair", "season": sn, "user": "ann", "opponent": "dan", "seed": 1, "teams": [], "created_at": s.now(), "state": "done"}
	m["102"] = {"league": "fair", "season": sn, "user": "ann", "opponent": "ben", "seed": 2, "teams": [], "created_at": s.now(), "state": "done"}
	m["103"] = {"league": "fair", "season": sn, "user": "cid", "opponent": "dan", "seed": 3, "teams": [], "created_at": s.now(), "state": "done"}
	m["104"] = {"league": "fair", "season": sn, "user": "ann", "opponent": "eve", "seed": 4, "teams": [], "created_at": s.now() - 20 * 86400, "state": "done"}
	var rows: Array = _as("ann", "friend_suggestions").rows
	assert_eq(rows.size(), 1, "friends and old battles are no suggestion")
	assert_eq(int(rows[0].ref), 101)
	assert_false(rows[0].has("name") or rows[0].has("code"), "no name, no code")
	assert_false(FriendsMoreMenu.suggestion_line(rows[0]).contains(codes.dan))
	assert_eq(_as("ann", "friend_suggest_request", {"p_match": 103}).error, "no_such_code", "only own matches")
	assert_eq(str(_as("ann", "friend_suggest_request", {"p_match": 101}).status), "pending")
	assert_eq(_as("ann", "friend_suggestions").rows, [], "asked once")

func test_invite_reward_for_both() -> void:
	s.db.flags["invite"] = {"enabled": true, "min_version": 1}
	s.switch_user("cid")
	s.profile_of("cid").created_at = s.now() - 30 * 86400
	assert_eq(_as("cid", "invite_redeem", {"p_code": codes.ann}).error, "too_late", "only new accounts")
	assert_eq(_as("eve", "invite_redeem", {"p_code": codes.eve}).error, "no_such_code")
	assert_eq(str(_as("eve", "invite_redeem", {"p_code": codes.ann}).status), "pending")
	assert_eq(_as("eve", "invite_redeem", {"p_code": codes.ann}).error, "already", "once per account")
	assert_eq(_as("eve", "invite_claim", {"p_slot": 1, "p_rev": 1}).error, "nothing", "not before the friendship")
	_as("ann", "friend_respond", {"p_code": codes.eve, "p_accept": true})
	var st: Dictionary = _as("ann", "invite_state")
	assert_eq(int(st.ready), 1)
	assert_eq(int(st.invited), 1)
	var r: Dictionary = _as("ann", "invite_claim", {"p_slot": 1, "p_rev": 4})
	assert_eq(str(r.item), "strong_tonic")
	assert_eq(int(r.times), 1)
	assert_eq(_as("ann", "invite_claim", {"p_slot": 1, "p_rev": 5}).error, "nothing", "paid once")
	assert_eq(int(_as("eve", "invite_claim", {"p_slot": 1, "p_rev": 1}).count), 2, "the new player gets it too")
	s.db.flags["invite"] = {"enabled": false, "min_version": 1}
	assert_eq(_as("ann", "invite_state").error, "feature_off")

func test_invite_link_opens_the_invite() -> void:
	assert_eq(FriendRules.invite_link("ABCD2345"), "chimora://friend/ABCD2345")
	assert_eq(DeepLink.parse("chimora://friend/abcd-2345"), {"route": "friend", "code": "ABCD2345"})
	assert_eq(DeepLink.parse("chimora://friend/abc"), {"route": "open"})
	assert_true(DeepLink.handle("chimora://friend/ABCD2345"))
	assert_eq(DeepLink.friend_code, "ABCD2345")
	assert_eq(DeepLink.take(), "friend")
	DeepLink.friend_code = ""

func test_card_shows_rank_line() -> void:
	var cfg: Dictionary = LeagueRules.ranks_config()
	var f: Dictionary = {"name": "Ben", "code": "ABCD2345", "rank": 4, "card": {}}
	assert_string_contains(FriendsMenu.card_text(f), "League rank: %s" % LeagueRules.rank_name(cfg, 4))
	f.rank = -1
	assert_string_contains(FriendsMenu.card_text(f), "League rank: -")
