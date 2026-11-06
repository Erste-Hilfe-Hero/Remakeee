extends GutTest
## Plan area 7, item 3011: small actions wait in a queue of up to 50 while the connection is
## weak, and each counts once on the server (the same cases as tools/online/sql_test/test_action_queue.sql).

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_actions: Array
var _server: LocalBackend

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_actions = Online.actions.duplicate()

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Online.actions = _old_actions
	Online._retry_count = 0
	Online.net_retry_seconds = 2.0
	Online._retry_wait = Online.RETRY_SECONDS
	Online._save_session()

func before_each() -> void:
	_server = LocalBackend.new()
	Online.backend = _server
	Online.state = Online.State.OFFLINE
	Online.actions = []
	Online.net_retry_seconds = 0.0

func test_the_server_counts_an_id_once() -> void:
	_server.switch_user("ann")
	_server.call_fn("hello", {"p_version": 1})
	var kind: String = str(_server.call_fn("community_get").data.kind)
	var a: Dictionary = {"p_id": "aaaa1111bbbb2222", "p_fn": "community_add", "p_args": {"p_kind": kind, "p_amount": 2}}
	assert_eq(int(_server.call_fn("action_once", a).data.mine), 2)
	assert_true(bool(_server.call_fn("action_once", a).data.repeat), "the same id again")
	assert_eq(int(_server.call_fn("community_get").data.mine), 2, "counted once")
	assert_eq(_server.call_fn("action_once", {"p_id": "cccc3333dddd4444", "p_fn": "gift_send", "p_args": {}}).data.error, "bad_action")
	assert_eq(_server.call_fn("action_once", {"p_id": "abc", "p_fn": "community_add", "p_args": {}}).data.error, "bad_id")

func test_actions_wait_while_offline_and_go_out_after_the_reconnect() -> void:
	await Online._reconnect()
	assert_eq(Online.state, Online.State.ONLINE)
	var kind: String = str((await Online.call_fn("community_get")).data.kind)
	_server.offline = true
	Online.state = Online.State.OFFLINE
	for i: int in 60:
		var r: Dictionary = await Online.send_small("community_add", {"p_kind": kind, "p_amount": 1})
		assert_true(bool(r.data.queued))
	assert_eq(Online.actions.size(), Online.ACTIONS_MAX, "up to 50 wait")
	var ids: Dictionary = {}
	for it: Dictionary in Online.actions:
		ids[it.id] = true
	assert_eq(ids.size(), 50, "each has its own id")
	_server.offline = false
	await Online._reconnect()
	assert_eq(Online.actions.size(), 0, "all went out")
	assert_eq(int((await Online.call_fn("community_get")).data.mine), 50)
