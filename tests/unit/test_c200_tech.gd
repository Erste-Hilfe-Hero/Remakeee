extends GutTest
## Chimora 200 list, tech package: anonymous crash report (184).

const DIR: String = "user://test_c200_tech"

class FakeBackend extends OnlineBackend:
	var calls: Array = []
	var answer: Dictionary = OnlineBackend.ok(null)
	func call_anon(name: String, args: Dictionary = {}) -> Dictionary:
		calls.append([name, args])
		return answer

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	CrashReport.reset()
	CrashReport.mark_path = DIR + "/mark.json"
	CrashReport.pending_path = DIR + "/pending.json"
	for p: String in [CrashReport.mark_path, CrashReport.pending_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

func after_each() -> void:
	for p: String in [CrashReport.mark_path, CrashReport.pending_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	CrashReport.reset()

func _restart() -> void:
	var mark: String = CrashReport.mark_path
	var pend: String = CrashReport.pending_path
	CrashReport.reset()
	CrashReport.mark_path = mark
	CrashReport.pending_path = pend
	CrashReport.begin("1.3.1")

func test_a_normal_end_leaves_no_report() -> void:
	CrashReport.begin("1.3.1")
	CrashReport.enter_scene("Overworld")
	CrashReport.app_left()
	_restart()
	assert_true(CrashReport.pending().is_empty())

func test_an_unexpected_end_keeps_version_platform_and_last_scene_only() -> void:
	CrashReport.begin("1.3.1")
	CrashReport.enter_scene("Overworld")
	CrashReport.set_battle(true)
	_restart()
	var p: Dictionary = CrashReport.pending()
	assert_eq(p, {"version": "1.3.1", "platform": OS.get_name(), "scene": "battle"})

func test_back_from_the_background_marks_the_run_again() -> void:
	CrashReport.begin("1.3.1")
	CrashReport.enter_scene("Title")
	CrashReport.app_left()
	CrashReport.app_back()
	_restart()
	assert_eq(str(CrashReport.pending().get("scene", "")), "Title")

func test_report_drops_every_other_key_and_cuts_long_values() -> void:
	var r: Dictionary = CrashReport.report_for({"version": "1.3.1", "platform": "Android",
		"scene": "x".repeat(100), "user_id": "abc", "name": "Mia"})
	assert_eq(r.keys().size(), 3)
	assert_eq(str(r.scene).length(), CrashReport.MAX_LEN)

func test_nothing_is_sent_until_the_server_switches_it_on() -> void:
	CrashReport.begin("1.3.1")
	_restart()
	var b := FakeBackend.new()
	await CrashReport.send(b, false)
	assert_eq(b.calls.size(), 0)
	assert_false(CrashReport.pending().is_empty())

func test_sent_once_without_ids_then_cleared() -> void:
	CrashReport.begin("1.3.1")
	_restart()
	var b := FakeBackend.new()
	await CrashReport.send(b, true)
	assert_eq(b.calls.size(), 1)
	assert_eq(b.calls[0][0], CrashReport.FN)
	assert_eq((b.calls[0][1] as Dictionary).keys(), ["p_version", "p_platform", "p_scene"])
	assert_true(CrashReport.pending().is_empty())
	await CrashReport.send(b, true)
	assert_eq(b.calls.size(), 1)

func test_kept_when_the_connection_drops() -> void:
	CrashReport.begin("1.3.1")
	_restart()
	var b := FakeBackend.new()
	b.answer = OnlineBackend.fail("offline", true)
	await CrashReport.send(b, true)
	assert_false(CrashReport.pending().is_empty())

func test_editor_and_test_runs_never_write_a_mark() -> void:
	CrashReport.enter_scene("Overworld")
	CrashReport.set_battle(true)
	assert_false(FileAccess.file_exists(CrashReport.mark_path))
