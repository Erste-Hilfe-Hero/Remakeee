extends GutTest
## KAMPF_PLAN_1000 items 493, 512, 543, 553 on the local stand-in of the server: weekly climb boards
## for the lighthouse stair and the echo tower, the challenge rule count on the Wanderer card and
## Wayfarer wins in the world goal. The same cases as tools/online/sql_test/test_climb_boards.sql.

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func test_climb_board_is_off_at_first() -> void:
	assert_eq(_as("ann", "climb_submit", {"p_kind": "stair", "p_floor": 5}).error, "feature_off")
	assert_eq(_as("ann", "climb_board", {"p_kind": "stair", "p_friends": true}).error, "feature_off")

func test_climb_board_keeps_the_best_floor_per_week() -> void:
	s.db.flags["climb_board"] = {"enabled": true, "min_version": 1}
	_as("ann", "friend_request", {"p_code": codes.ben})
	_as("ben", "friend_respond", {"p_code": codes.ann, "p_accept": true})
	assert_true(bool(_as("ann", "climb_submit", {"p_kind": "stair", "p_floor": 12}).ok))
	assert_true(bool(_as("ann", "climb_submit", {"p_kind": "stair", "p_floor": 9}).ok))
	assert_eq(_as("ann", "climb_submit", {"p_kind": "stair", "p_floor": 31}).error, "implausible", "the stair has 30 floors")
	assert_eq(_as("ann", "climb_submit", {"p_kind": "stair", "p_floor": 0}).error, "implausible")
	assert_eq(_as("ann", "climb_submit", {"p_kind": "roof", "p_floor": 3}).error, "bad_kind")
	assert_true(bool(_as("ann", "climb_submit", {"p_kind": "tower", "p_floor": 140}).ok))
	assert_eq(_as("ann", "climb_submit", {"p_kind": "tower", "p_floor": 1001}).error, "implausible")
	_as("ben", "climb_submit", {"p_kind": "stair", "p_floor": 20})
	_as("cid", "climb_submit", {"p_kind": "stair", "p_floor": 30})
	var r: Dictionary = _as("ann", "climb_board", {"p_kind": "stair", "p_friends": true})
	assert_true(bool(r.ok))
	assert_eq(r.rows.size(), 2)
	assert_ne(str(r.rows[0].name), "", "a friend shows with name")
	assert_eq(int(r.rows[0].score), 20)
	assert_eq(int(r.rows[1].score), 12, "the best floor counts")
	assert_true(bool(r.rows[1].me))
	r = _as("ann", "climb_board", {"p_kind": "stair", "p_friends": false})
	assert_eq(r.rows.size(), 3)
	assert_eq(int(r.rows[0].score), 30)
	assert_eq(str(r.rows[0].name), "", "strangers stay nameless")
	r = _as("ann", "climb_board", {"p_kind": "tower", "p_friends": false})
	assert_eq(r.rows.size(), 1)
	assert_eq(int(r.rows[0].score), 140)
	assert_eq(_as("ann", "climb_board", {"p_kind": "roof", "p_friends": true}).error, "bad_kind")

func test_card_carries_the_rule_count() -> void:
	s.switch_user("ann")
	var p: Dictionary = _as("ann", "profile_set", {"p_name": "Tia", "p_color": 0, "p_favorite": "", "p_card": {"rules": 3, "seen": 4}})
	assert_eq(int(p.card.rules), 3)
	assert_eq(int(p.card.seen), 4)
	assert_eq(int(_as("ann", "profile_set", {"p_name": "Tia", "p_card": {"rules": 99}}).card.rules), 20, "capped")
	assert_false((_as("ann", "profile_set", {"p_name": "Tia", "p_card": {"rules": 0}}).card as Dictionary).has("rules"))
	assert_false((_as("ann", "profile_set", {"p_name": "Tia", "p_card": {"rules": "many"}}).card as Dictionary).has("rules"))
	assert_eq(FriendsMenu.rules_line({"rules": 3}), "Challenge rules: 3\n")
	assert_eq(FriendsMenu.rules_line({}), "")
	assert_string_contains(FriendsMenu.card_text({"card": {"rules": 2}, "code": "ABC"}), "Challenge rules: 2")

func test_card_numbers_count_active_rules() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	assert_false(Online.card_numbers().has("rules"))
	var ids: Array = ChallengeRules.ids()
	ChallengeRules.toggle(str(ids[0]))
	ChallengeRules.toggle(str(ids[1]))
	assert_eq(int(Online.card_numbers().rules), ChallengeRules.active_ids().size())

func test_wayfarers_are_a_world_goal() -> void:
	assert_true(LocalBackend.DEFAULT_CONFIG.goal_rotation.any(func(g: Dictionary) -> bool: return g.kind == "wayfarers"))
	assert_true(FriendsMenu.GOAL_TEXT.has("wayfarers"))
	s.db.config.goal_rotation = [{"kind": "wayfarers", "target": 30}]
	var g: Dictionary = _as("ann", "community_add", {"p_kind": "wayfarers", "p_amount": 1})
	assert_eq(str(g.kind), "wayfarers")
	assert_eq(int(g.total), 1)
	assert_eq(int(_as("ann", "community_add", {"p_kind": "battles", "p_amount": 1}).total), 1, "other kinds do not count")
	var sql: String = FileAccess.get_file_as_string("res://supabase/migrations/20261113207070_climb_boards.sql")
	assert_string_contains(sql, "\"kind\":\"wayfarers\"")
