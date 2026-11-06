extends GutTest
## Plan area 9, server sync: growing reconnect waits, request ids for save_put, save size limit.

var _old_backend: OnlineBackend
var _old_state: Online.State
var _server: LocalBackend

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Online._retry_count = 0
	Online._retry_wait = Online.RETRY_SECONDS

func before_each() -> void:
	_server = LocalBackend.new()
	Online.backend = _server
	Online.state = Online.State.OFFLINE

func test_reconnect_waits_grow_and_stop_at_30_seconds() -> void:
	assert_eq(Online.retry_wait(0, 0.0), 4.0)
	assert_eq(Online.retry_wait(1, 0.0), 8.0)
	assert_eq(Online.retry_wait(2, 0.0), 16.0)
	assert_eq(Online.retry_wait(3, 0.0), 30.0)
	assert_eq(Online.retry_wait(50, 0.0), 30.0)
	assert_almost_eq(Online.retry_wait(3, 1.0), 36.0, 0.001, "20 % up")
	assert_almost_eq(Online.retry_wait(3, -1.0), 24.0, 0.001, "20 % down")
	assert_almost_eq(Online.retry_wait(0, 9.0), 4.8, 0.001, "spread is clamped")

func test_failed_reconnects_raise_the_wait_and_success_resets_it() -> void:
	_server.offline = true
	Online._retry_count = 0
	await Online._reconnect()
	await Online._reconnect()
	assert_eq(Online._retry_count, 2)
	assert_between(Online._retry_wait, 16.0 * 0.8, 16.0 * 1.2)
	_server.offline = false
	await Online._reconnect()
	assert_eq(Online._retry_count, 0)
	assert_eq(Online._retry_wait, 4.0)

func test_request_id_is_stable_and_depends_on_content_and_base() -> void:
	var d: Dictionary = {"money": 5, "party": []}
	var a: String = Online.request_id(d, 1, 3)
	assert_eq(a.length(), 32)
	assert_eq(Online.request_id({"party": [], "money": 5}, 1, 3), a, "key order does not matter")
	assert_ne(Online.request_id(d, 1, 4), a)
	assert_ne(Online.request_id(d, 2, 3), a)
	assert_ne(Online.request_id({"money": 6, "party": []}, 1, 3), a)

func test_resent_upload_counts_once() -> void:
	await Online.connect_now()
	var d: Dictionary = {"schema": Online.SAVE_SCHEMA, "money": 1, "party": []}
	var args: Dictionary = {"p_slot": 1, "p_data": d, "p_summary": "", "p_base_rev": 0, "p_force": false,
		"p_request_id": Online.request_id(d, 1, 0)}
	var first: Dictionary = await Online.call_fn("save_put", args)
	assert_eq(int(first.data.rev), 1)
	# The answer was lost on the way; the game sends the same upload again.
	var again: Dictionary = await Online.call_fn("save_put", args)
	assert_true(bool(again.data.ok), "not a conflict")
	assert_eq(int(again.data.rev), 1, "stored only once")
	var stale: Dictionary = await Online.call_fn("save_put", {"p_slot": 1, "p_data": {"schema": Online.SAVE_SCHEMA, "money": 2}, "p_summary": "",
		"p_base_rev": 0, "p_force": false, "p_request_id": "other"})
	assert_true(bool(stale.data.get("conflict", false)), "a different upload on an old base still conflicts")

func test_too_big_save_is_refused() -> void:
	await Online.connect_now()
	var r: Dictionary = await Online.call_fn("save_put", {"p_slot": 2, "p_data": {"note": "x".repeat(LocalBackend.SAVE_MAX_BYTES)},
		"p_summary": "", "p_base_rev": 0})
	assert_eq(str(r.data.error), "too_big")

func test_connect_reports_the_platform() -> void:
	await Online.connect_now()
	assert_eq(Online.platform_name(), "app", "tests run outside the browser")
	assert_eq(str(Online.profile.get("platform", "")), "app", "new accounts count as app")
	# The account was used in the browser before and now comes back on a phone.
	await Online.call_fn("platform_set", {"p_platform": "web"})
	assert_eq(str(_server.profile_of(_server.me()).platform), "web")
	Online.state = Online.State.OFFLINE
	await Online.connect_now()
	assert_eq(str(_server.profile_of(_server.me()).platform), "app", "reported again after hello")
	var r: Dictionary = await Online.call_fn("platform_set", {"p_platform": "moon"})
	assert_eq(str(r.data.error), "bad_platform")
