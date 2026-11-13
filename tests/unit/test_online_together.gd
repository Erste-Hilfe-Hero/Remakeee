extends GutTest
## Playing together (items 21-48, 81-85, 121-160): friends, blocking, Lantern Mail and gifts,
## echo teams, the world goal and the weekly board, on the local stand-in of the server.

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_profile: Dictionary
var s: LocalBackend
var ann: String
var ben: String
var ann_code: String
var ben_code: String

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_profile = Online.profile

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Online.profile = _old_profile

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	Online.backend = s
	Online.state = Online.State.OFFLINE
	ann = "ann"
	ben = "ben"
	s.switch_user(ben)
	ben_code = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.call_fn("profile_set", {"p_name": "Ben", "p_color": 1, "p_favorite": "Puddlet", "p_card": {"seals": 2}})
	s.switch_user(ann)
	ann_code = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.call_fn("profile_set", {"p_name": "Ann", "p_color": 0, "p_favorite": "Kindlop", "p_card": {}})

func _as(uid: String) -> void:
	s.switch_user(uid)

func _call(fn: String, args: Dictionary = {}) -> Variant:
	return s.call_fn(fn, args).data

func _befriend() -> void:
	_as(ann)
	_call("friend_request", {"p_code": ben_code})
	_as(ben)
	_call("friend_respond", {"p_code": ann_code, "p_accept": true})
	_as(ann)

func test_friend_request_and_accept() -> void:
	_as(ann)
	assert_eq(_call("friend_request", {"p_code": "ZZZZZZZZ"}).error, "no_such_code")
	assert_eq(_call("friend_request", {"p_code": ann_code}).error, "no_such_code", "not yourself")
	assert_eq(_call("friend_request", {"p_code": ben_code.to_lower().insert(4, "-")}).status, "pending")
	assert_eq(_call("gift_send", {"p_code": ben_code}).error, "not_friends")
	_as(ben)
	var list: Dictionary = _call("friends_list")
	assert_eq(list.incoming[0].name, "Ann")
	_call("friend_respond", {"p_code": ann_code, "p_accept": true})
	list = _call("friends_list")
	assert_eq(list.friends[0].name, "Ann")
	assert_eq(int(list.friends[0].level), 1)

func test_asking_back_accepts() -> void:
	_as(ann)
	_call("friend_request", {"p_code": ben_code})
	_as(ben)
	assert_eq(_call("friend_request", {"p_code": ann_code}).status, "accepted")

func test_daily_gift_once_per_friend_and_open_limit() -> void:
	_befriend()
	_call("presence", {"p_place": "Thornridge"})
	assert_true(_call("gift_send", {"p_code": ben_code}).ok)
	assert_eq(_call("gift_send", {"p_code": ben_code}).error, "already_today")
	assert_true(_call("friends_list").friends[0].gift_sent)
	_as(ben)
	var mail: Array = _call("mail_list")
	assert_eq(mail.size(), 1)
	assert_eq(mail[0].place, "Thornridge")
	assert_eq(mail[0].item, "", "hidden until opened")
	var r: Dictionary = _call("gift_open", {"p_id": mail[0].id})
	assert_true(r.ok)
	assert_true(Database.item(str(r.item)).has("name"), "gifts hold real items")
	assert_true(_call("gift_open", {"p_id": mail[0].id}).again, "opening twice gives nothing new")
	# Ten opens a day.
	_as(ann)
	for i: int in 12:
		s.clock_offset += 86400
		_call("gift_send", {"p_code": ben_code})
	s.clock_offset += 1
	_as(ben)
	var opened: int = 0
	var last: Dictionary = {}
	for m: Dictionary in _call("mail_list"):
		if not bool(m.opened):
			last = _call("gift_open", {"p_id": m.id})
			opened += 1 if last.ok else 0
	assert_eq(opened, 10)
	assert_eq(last.error, "limit_today")

func test_gift_table_is_shown_with_real_items_and_sums_to_100() -> void:
	var total: int = 0
	for e: Dictionary in LocalBackend.DEFAULT_CONFIG.gift_table:
		total += int(e.w)
		assert_false(Database.item(str(e.item)).is_empty(), "%s is an item" % e.item)
	assert_eq(total, 100)
	for it: String in LocalBackend.DEFAULT_CONFIG.goal_rewards:
		assert_false(Database.item(it).is_empty(), "%s is an item" % it)
	assert_string_contains(FriendsMenu.gift_table_text(), "%")
	# Same table as the SQL.
	var sql: String = FileAccess.get_file_as_string("res://supabase/migrations/20261101000002_online_together.sql")
	for e: Dictionary in LocalBackend.DEFAULT_CONFIG.gift_table:
		assert_true(sql.contains('{"item":"%s","w":%d}' % [e.item, int(e.w)]), "%s matches the SQL" % e.item)

func test_greetings_are_phrase_numbers_only() -> void:
	_befriend()
	assert_true(_call("mail_send", {"p_code": ben_code, "p_kind": "phrase", "p_phrase": 2}).ok)
	assert_eq(_call("mail_send", {"p_code": ben_code, "p_kind": "phrase", "p_phrase": 99}).error, "bad_phrase")
	assert_eq(_call("mail_send", {"p_code": ben_code, "p_kind": "shout", "p_phrase": 1}).error, "bad_kind")
	_as(ben)
	var m: Dictionary = _call("mail_list")[0]
	assert_eq(FriendsMenu.mail_line(m), "! Ann: Good luck!")
	assert_lt(Phrases.LIST.size(), 33, "the server accepts 0-31")

func test_blocking_ends_everything_and_hides_the_code() -> void:
	_befriend()
	_call("mail_send", {"p_code": ben_code, "p_kind": "wave", "p_phrase": 0})
	_as(ben)
	assert_true(_call("block", {"p_code": ann_code}).ok)
	assert_true(_call("friends_list").friends.is_empty())
	assert_true(_call("mail_list").is_empty(), "their mail is gone")
	assert_eq(_call("friends_list").blocked[0].name, "Ann")
	assert_true(_call("report", {"p_code": ann_code, "p_reason": 0}).ok)
	assert_eq(s.db.reports[0].target_name, "Ann")
	_as(ann)
	assert_eq(_call("friend_request", {"p_code": ben_code}).error, "no_such_code", "a block looks like a bad code")
	_as(ben)
	_call("unblock", {"p_code": ann_code})
	_as(ann)
	assert_eq(_call("friend_request", {"p_code": ben_code}).status, "pending")

func test_social_off_for_parents() -> void:
	_as(ann)
	_call("set_social", {"p_on": false})
	assert_eq(_call("friend_request", {"p_code": ben_code}).error, "social_off")
	_call("set_social", {"p_on": true})
	_as(ben)
	_call("set_social", {"p_on": false})
	_as(ann)
	assert_eq(_call("friend_request", {"p_code": ben_code}).error, "no_such_code")

func test_friend_requests_are_rate_limited() -> void:
	_as(ann)
	var r: Dictionary = {}
	for i: int in 25:
		r = _call("friend_request", {"p_code": "QQQQQQQQ"})
	assert_eq(r.error, "slow_down")

func test_echo_team_goes_online_without_nicknames_and_comes_back_capped() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Ann", 0, "Kindlop")
	GameState.party[0].nickname = "Rude Name"
	GameState.party[0].level = 40
	var snap: Array = EchoTeam.snapshot(GameState.party)
	assert_false(snap[0].has("nickname"))
	_befriend()
	_call("team_set", {"p_team": snap})
	_as(ben)
	var t: Dictionary = _call("friend_team", {"p_code": ann_code})
	assert_eq(t.name, "Ann")
	var echo: Array[Spirling] = EchoTeam.build(t.team, 18)
	assert_eq(echo[0].level, 18, "echo is capped to your level cap (item 76)")
	assert_eq(echo[0].nickname, "")
	assert_eq(echo[0].hp, echo[0].max_hp())
	var duel: Array[Spirling] = EchoTeam.build(t.team, 100, EchoTeam.DUEL_LEVEL)
	assert_eq(duel[0].level, EchoTeam.DUEL_LEVEL)
	_as(ann)
	_call("friend_remove", {"p_code": ben_code})
	_as(ben)
	assert_eq(_call("friend_team", {"p_code": ann_code}).error, "not_friends")

func test_duel_copies_never_change_the_real_team() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Ann", 0, "Kindlop")
	var real: Spirling = GameState.party[0]
	var lvl: int = real.level
	var copy: Array[Spirling] = EchoTeam.duel_copy(GameState.party)
	assert_ne(copy[0], real)
	copy[0].hp = 0
	copy[0].level = 99
	assert_eq(real.level, lvl)
	assert_gt(real.hp, 0)

func test_echo_reports_give_points_once_a_day_and_a_note() -> void:
	_befriend()
	assert_eq(int(_call("echo_report", {"p_code": ben_code, "p_kind": "echo", "p_won": true}).points), 3)
	assert_eq(int(_call("echo_report", {"p_code": ben_code, "p_kind": "echo", "p_won": true}).points), 0)
	assert_eq(int(_call("echo_report", {"p_code": ben_code, "p_kind": "duel", "p_won": false}).points), 2)
	assert_eq(_call("echo_report", {"p_code": ben_code, "p_kind": "trade", "p_won": true}).error, "bad_kind")
	assert_eq(int(_call("friends_list").friends[0].points), 5)
	_as(ben)
	var lines: Array[String] = []
	for m: Dictionary in _call("mail_list"):
		lines.append(FriendsMenu.mail_line(m))
	assert_has(lines, "! Ann's team fought beside your echo and won.")
	assert_has(lines, "! Your echo won a duel against Ann!")

func test_friendship_levels() -> void:
	assert_eq(LocalBackend.level_for(0), 1)
	assert_eq(LocalBackend.level_for(10), 2)
	assert_eq(LocalBackend.level_for(30), 3)
	assert_eq(LocalBackend.level_for(60), 4)
	assert_eq(LocalBackend.level_for(100), 5)

func test_world_goal_counts_caps_and_rewards() -> void:
	s.db.config.goal_rotation = [{"kind": "battles", "target": 20}]
	s.db.config.goal_user_cap = 12
	_as(ann)
	var g: Dictionary = _call("community_get")
	assert_eq(g.kind, "battles")
	assert_eq(_call("community_claim", {"p_tier": 1}).error, "not_helped")
	assert_eq(int(_call("community_add", {"p_kind": "bonds", "p_amount": 5}).total), 0, "other kinds do not count")
	g = _call("community_add", {"p_kind": "battles", "p_amount": 50})
	assert_eq(int(g.mine), 5, "at most 5 per call")
	assert_eq(FriendsMenu.open_tiers(g), [1] as Array[int])
	assert_eq(_call("community_claim", {"p_tier": 1}).item, "strong_tonic")
	assert_eq(_call("community_claim", {"p_tier": 1}).error, "claimed")
	_call("community_add", {"p_kind": "battles", "p_amount": 5})
	assert_eq(int(_call("community_add", {"p_kind": "battles", "p_amount": 5}).mine), 12, "weekly cap")
	_as(ben)
	_call("community_add", {"p_kind": "battles", "p_amount": 5})
	g = _call("community_add", {"p_kind": "battles", "p_amount": 5})
	assert_eq(int(g.total), 22)
	assert_eq(FriendsMenu.open_tiers(g), [1, 2, 3, 4] as Array[int])
	assert_string_contains(FriendsMenu.goal_text(g), "100%")

func test_contributions_go_through_online() -> void:
	s.db.config.goal_rotation = [{"kind": "rests", "target": 20}]
	await Online.connect_now()
	await Online.contribute("rests")
	assert_eq(int((await Online.call_fn("community_get")).data.mine), 1)

func test_weekly_board_scores_and_names() -> void:
	var w: String = WeeklyChallenge.week_key(s.now())
	_befriend()
	assert_eq(_call("weekly_submit", {"p_week": "2000-W01", "p_score": 300}).error, "wrong_week")
	assert_eq(_call("weekly_submit", {"p_week": w, "p_score": 9999}).error, "implausible")
	_call("weekly_submit", {"p_week": w, "p_score": 250})
	_call("weekly_submit", {"p_week": w, "p_score": 100})
	s.switch_user("cara")
	s.call_fn("hello", {"p_version": 1})
	_call("weekly_submit", {"p_week": w, "p_score": 320})
	var b: Dictionary = _call("weekly_board", {"p_friends": false})
	assert_eq(int(b.rows[0].score), 320)
	assert_true(b.rows[0].me)
	assert_eq(int(b.rows[1].score), 250, "best counts")
	assert_eq(b.rows[1].name, "", "strangers have no name")
	assert_eq((_call("weekly_board", {"p_friends": true}).rows as Array).size(), 1)
	_as(ben)
	assert_eq(_call("weekly_board", {"p_friends": false}).rows[1].name, "Ann")

func test_weekly_score_formula() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Ann", 0, "Kindlop")
	assert_eq(EchoTeam.weekly_score(2, GameState.party), 120)
	assert_eq(EchoTeam.weekly_score(5, GameState.party), 400)
	GameState.party[0].hp = 0
	assert_eq(EchoTeam.weekly_score(5, GameState.party), 300)

func test_transfer_keeps_friends_and_mail() -> void:
	_befriend()
	_call("gift_send", {"p_code": ben_code})
	_as(ben)
	var code: String = _call("transfer_create").code
	s.switch_user("ben_new_phone")
	s.call_fn("hello", {"p_version": 1})
	assert_true(_call("transfer_claim", {"p_code": code}).ok)
	assert_eq(_call("friends_list").friends[0].name, "Ann")
	assert_eq((_call("mail_list") as Array).size(), 1)
	assert_eq(_call("hello", {"p_version": 1}).profile.code, ben_code)

func test_deleting_an_account_removes_it_from_friends() -> void:
	_befriend()
	_as(ben)
	_call("delete_account")
	s.switch_user(ann)
	assert_true(_call("friends_list").friends.is_empty())

func test_card_and_lines_read_well() -> void:
	var f: Dictionary = {"code": "ABCDEFGH", "name": "Ben", "favorite": "Puddlet", "card": {"seals": 2, "seen": 9, "bonded": 4, "hours": 3},
		"level": 2, "points": 12, "online": true, "place": "Brindlewick", "last_seen": Online.unix_now()}
	assert_eq(FriendsMenu.friend_line(f), "* Ben  Bond 2  Brindlewick")
	assert_string_contains(FriendsMenu.card_text(f), "Rifts sealed: 2")
	f.online = false
	f.last_seen = Online.unix_now() - 7200
	assert_string_contains(FriendsMenu.friend_line(f), "seen 2 h ago")
