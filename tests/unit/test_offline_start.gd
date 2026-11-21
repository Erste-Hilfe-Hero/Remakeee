extends GutTest
## Plan Chimora 100, item 77: a new journey starts offline and plays the prologue; at its save
## point (or when the connection comes back) the account is made and the save goes up through the
## normal save_put, with the same server checks as any first save.

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_revs: Dictionary
var _old_dirty: Dictionary
var _server: LocalBackend
var _kept: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_revs = Online.revs.duplicate()
	_old_dirty = Online.dirty.duplicate()
	for n: int in range(1, SaveManager.SLOTS + 1):
		var p: String = SaveManager.path_for_slot(n)
		if FileAccess.file_exists(p):
			_kept[p] = FileAccess.get_file_as_string(p)

func after_all() -> void:
	_wipe_slots()
	for p: String in _kept:
		SaveManager.write_atomic(p, _kept[p])
	Online.backend = _old_backend
	Online.state = _old_state
	Online.revs = _old_revs
	Online.dirty = _old_dirty
	Online.offline_start = false
	Online.offline_play = false
	GameState.in_game = false
	get_tree().paused = false

func before_each() -> void:
	_wipe_slots()
	_server = LocalBackend.new()
	_server.rng.seed = 1
	_server.offline = true
	Online.backend = _server
	Online.state = Online.State.OFFLINE
	Online.revs = {}
	Online.dirty = {}
	Online.conflicts.clear()
	Online.offline_start = false
	Online.offline_play = false
	Online._retry = 0.0
	Online._retry_count = 0
	Online._retry_wait = Online.RETRY_SECONDS
	GameState.in_game = false
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 1, "")

func after_each() -> void:
	GameState.in_game = false
	Online.offline_play = false
	Online.offline_start = false
	Online._overlay.visible = false
	get_tree().paused = false

func _wipe_slots() -> void:
	for n: int in range(1, SaveManager.SLOTS + 1):
		SaveManager.set_slot(n)
		SaveManager.delete_save()
	SaveManager.set_slot(1)

## Title, New Game, slot 1 saved locally (start_fresh_slot) while there is no connection.
func _start_offline() -> void:
	assert_eq(await Online.connect_now(), Online.State.OFFLINE)
	assert_true(Online.offline_start_allowed(0, Online.revs.size(), Online.kicked, Online.state))
	Online.begin_offline_start()
	SaveManager.set_slot(1)
	assert_true(SaveManager.start_fresh_slot())
	GameState.in_game = true

func test_offline_new_game_only_for_a_phone_without_journeys() -> void:
	var off := Online.State.OFFLINE
	assert_true(Online.offline_start_allowed(0, 0, false, off))
	assert_false(Online.offline_start_allowed(1, 0, false, off), "Continue and Load stay online only")
	assert_false(Online.offline_start_allowed(0, 1, false, off), "this device synced a slot before")
	assert_false(Online.offline_start_allowed(0, 0, true, off), "another device took the account")
	assert_false(Online.offline_start_allowed(0, 0, false, Online.State.UPDATE_REQUIRED))
	assert_false(Online.offline_start_allowed(0, 0, false, Online.State.ONLINE))

func test_prologue_plays_without_the_reconnect_screen() -> void:
	await _start_offline()
	assert_false(_server.signed_in(), "no account yet")
	assert_true(Online.dirty.has(1), "the local save waits to go up")
	await wait_process_frames(3)
	assert_false(Online._overlay.visible, "no reconnect screen in the offline prologue")
	assert_false(get_tree().paused)

func test_save_point_makes_the_account_and_syncs_the_save() -> void:
	await _start_offline()
	GameState.money = 1234
	SaveManager.save_game()
	_server.offline = false
	Online.offline_save_point()
	await wait_process_frames(5)
	assert_eq(Online.state, Online.State.ONLINE)
	assert_true(_server.signed_in(), "account made at the save point")
	var got: Dictionary = (await _server.call_fn("save_get", {"p_slot": 1})).data
	assert_eq(int(got.data.money), 1234, "the offline save reached the server")
	assert_eq(int(Online.revs[1]), int(got.rev))
	assert_false(Online.dirty.has(1))
	assert_false(Online.offline_start)
	assert_false(Online.offline_play)

func test_after_the_save_point_a_missing_connection_pauses_as_always() -> void:
	await _start_offline()
	Online.offline_save_point()
	assert_false(Online.offline_play)
	Online._offline_for = ReconnectOverlay.SHORT_DROP
	await wait_process_frames(3)
	assert_true(Online._overlay.visible, "the reconnect screen is back")
	assert_true(Online.offline_start, "still waiting for the first connection")

func test_connection_back_during_the_prologue_syncs_without_a_screen() -> void:
	await _start_offline()
	_server.offline = false
	await Online._reconnect()
	assert_eq(Online.state, Online.State.ONLINE)
	assert_false(Online.dirty.has(1))
	assert_false(Online.offline_start)
	assert_false(Online.offline_play)

## Anti-cheat: the first sync is a plain save_put, so the server's first-save checks still apply.
func test_an_offline_save_gets_no_more_than_the_server_accepts() -> void:
	await _start_offline()
	# 1 minute played: start money plus 5000 per minute is the most the server takes.
	GameState.money = 20_000
	SaveManager.save_game()
	_server.offline = false
	await Online._reconnect()
	assert_eq(Online.state, Online.State.ONLINE)
	assert_null((await _server.call_fn("save_get", {"p_slot": 1})).data, "refused: money_fast")
	assert_true(Online.dirty.has(1), "nothing was accepted")
	var flags: Array = _server._user().get("cheat_flags", [])
	assert_eq(flags.size(), 1)
	assert_eq(str(flags[0].reason), "money_fast")
	assert_push_error("Server refused save")
