extends GutTest
## Bunds (plan area 7, items 2817-2821, 2842, 2900) on the local stand-in of the server.
## The same cases as tools/online/sql_test/test_bunds.sql.

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	for who: String in ["ann", "ben", "cid", "dot"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.db.flags["bund"] = {"enabled": true, "min_version": 1}

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _bund_with(members: Array) -> void:
	assert_true(bool(_as("ann", "bund_create", {"p_a": 3, "p_b": 7}).ok))
	for who: String in members:
		_as("ann", "bund_invite", {"p_code": codes[who]})
		var inv: Array = _as(who, "bund_info").invites
		assert_true(bool(_as(who, "bund_answer", {"p_bund": inv[0].bund, "p_accept": true}).joined))

func test_flag_and_names() -> void:
	s.db.flags["bund"] = {"enabled": false, "min_version": 1}
	assert_eq(_as("ann", "bund_create", {"p_a": 1, "p_b": 2}).error, "feature_off")
	s.db.flags["bund"] = {"enabled": true, "min_version": 1}
	assert_eq(_as("ann", "bund_create", {"p_a": 1, "p_b": 500}).error, "bad_name")
	assert_true(bool(_as("ann", "bund_create", {"p_a": 1, "p_b": 2}).ok))
	assert_eq(_as("ann", "bund_create", {"p_a": 1, "p_b": 2}).error, "in_bund", "one bund per player")
	assert_eq(BundWords.FIRST.size(), 120)
	assert_eq(BundWords.SECOND.size(), 120)
	assert_eq(BundWords.FIRST_DE.size(), 120)
	assert_eq(BundWords.SECOND_DE.size(), 120)
	assert_eq(BundWords.name_of(0, 0), "Amber Badgers")

func test_requests_roles_and_blocks() -> void:
	_bund_with(["ben"])
	_as("dot", "block", {"p_code": codes.ann})
	assert_eq(_as("dot", "bund_request", {"p_code": codes.ben}).error, "no_such_bund", "blocked: no request")
	assert_eq(_as("ann", "bund_invite", {"p_code": codes.dot}).error, "no_such_code", "blocked: no invite")
	assert_false(bool(_as("cid", "bund_request", {"p_code": codes.ben}).joined))
	assert_eq(_as("ben", "bund_admit", {"p_code": codes.cid, "p_accept": true}).error, "not_allowed")
	assert_true(bool(_as("ann", "bund_role", {"p_code": codes.ben, "p_role": "helper"}).ok))
	assert_true(bool(_as("ben", "bund_admit", {"p_code": codes.cid, "p_accept": true}).joined))
	assert_eq(_as("ben", "bund_kick", {"p_code": codes.ann}).error, "not_allowed", "helpers cannot remove the leader")
	var b: Dictionary = _as("cid", "bund_info").bund
	assert_eq((b.members as Array).size(), 3)
	assert_eq(b.members[0].role, "leader")
	assert_true((_as("cid", "bund_info").bund.pending as Array).is_empty(), "members do not see requests")

func test_dissolve_waits_a_day_with_three() -> void:
	_bund_with(["ben", "cid"])
	assert_eq(_as("ben", "bund_dissolve").error, "not_allowed")
	assert_false(bool(_as("ann", "bund_dissolve").dissolved))
	assert_false(bool(_as("ann", "bund_dissolve").dissolved))
	s.clock_offset += 86401
	assert_true(bool(_as("ann", "bund_dissolve").dissolved))
	assert_null(_as("ben", "bund_info").bund, "members are free again")

func test_leaving_hands_over_and_last_one_closes() -> void:
	_bund_with(["ben"])
	assert_true(bool(_as("ann", "bund_leave").ok))
	assert_eq(_as("ben", "bund_info").bund.role, "leader")
	_as("ben", "bund_leave")
	assert_true((s.db.bunds as Dictionary).is_empty())

func test_deleting_the_leader_keeps_the_bund() -> void:
	_bund_with(["ben"])
	_as("ann", "delete_account")
	assert_eq(_as("ben", "bund_info").bund.role, "leader")

func test_menu_texts() -> void:
	assert_eq(BundMenu.role_text("helper"), "Helper")
	assert_string_contains(BundMenu.member_line({"name": "Mira", "role": "leader", "online": true, "me": false}), "Mira")
