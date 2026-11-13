extends GutTest
## Reports, decisions and objections (plan area 7, items 2895-2898, 2916) on the local stand-in
## of the server. The same cases as tools/online/sql_test/test_moderation.sql.

var s: LocalBackend
var ann_code: String

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	s.switch_user("ann")
	ann_code = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.switch_user("ben")
	s.call_fn("hello", {"p_version": 1})

func _report(reason: int, context: String = "friends") -> int:
	s.switch_user("ben")
	var r: Dictionary = s.call_fn("report_in", {"p_code": ann_code, "p_reason": reason, "p_context": context, "p_object": ""}).data
	assert_true(bool(r.ok), str(r))
	return int(r.report_id)

func _notices(user: String) -> Array:
	s.switch_user(user)
	return s.call_fn("notices_list").data.notices

func test_a_report_gets_a_number_and_a_place() -> void:
	var a: int = _report(0, "card")
	var b: int = _report(1)
	assert_gt(a, 0)
	assert_ne(a, b)
	assert_eq(s.call_fn("report_in", {"p_code": ann_code, "p_reason": 0, "p_context": "chat"}).data.error, "bad_context")
	assert_true(bool(s.call_fn("report", {"p_code": ann_code, "p_reason": 0}).data.report_id > 0), "old call still works")

func test_the_decision_reaches_both_sides() -> void:
	var id: int = _report(0, "card")
	var rejected: int = _report(1)
	assert_true(bool(s.moderation_decide(id, true, "name_reset").ok))
	assert_true(bool(s.moderation_decide(rejected, false).ok))
	assert_eq(s.moderation_decide(id, false).error, "decided")
	assert_string_starts_with(str(s.profile_of("ann").name), "Wanderer ")
	var mine: Array = _notices("ann")
	assert_eq(mine.size(), 1, "no notice for the rejected report")
	assert_eq(mine[0].body.rule, "4")
	var text: String = NoticesMenu.text_of(mine[0])
	assert_string_contains(text, "%d" % id)
	assert_string_contains(text, "Wayfarer card")
	assert_string_contains(text, "not a machine")
	assert_eq(_notices("ben").size(), 2, "the reporter hears both outcomes")

func test_an_objection_works_once_and_in_time() -> void:
	s.moderation_decide(_report(2, "league"), true, "league_block")
	assert_true(s.cheat_held("ann"), "league blocked")
	var n: Dictionary = _notices("ann")[0]
	s.switch_user("ben")
	assert_eq(s.call_fn("appeal", {"p_notice": n.id, "p_reason": 0}).data.error, "no_such_notice")
	s.switch_user("ann")
	var ap: Dictionary = s.call_fn("appeal", {"p_notice": n.id, "p_reason": 0}).data
	assert_true(bool(ap.ok))
	assert_eq(s.call_fn("appeal", {"p_notice": n.id, "p_reason": 0}).data.error, "appealed")
	s.clock_offset += 10
	s.appeal_answer(int(ap.appeal_id), true)
	assert_false(s.cheat_held("ann"), "lifted")
	var all: Array = _notices("ann")
	assert_eq(all[0].kind, "appeal_answer")
	assert_eq(NoticesMenu.text_of(all[0]), "Your objection to report %d: we changed the decision." % int(n.report_id))

func test_too_late_after_six_months() -> void:
	s.moderation_decide(_report(0), true, "warning")
	var n: Dictionary = _notices("ann")[0]
	s.clock_offset += 200 * 86400
	assert_eq(s.call_fn("appeal", {"p_notice": n.id, "p_reason": 1}).data.error, "too_late")
