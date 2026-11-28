extends GutTest
## docs/OFFLINE.md: Chimora plays offline without a setting. A first start without internet
## starts a new journey that is saved on the phone; once the connection is there the account is
## made in the background and the save goes up through the normal save_put, with the same server
## checks as any other save. A drop while playing only switches to offline, it never pauses.

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
	Online.kicked = false
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
	Online.kicked = false
	Online.conflicts.clear()
	Online._retry = 0.0
	Online._tries = 0
	Online._retry_count = 0
	Online._retry_wait = Online.RETRY_SECONDS
	Online._offline_for = 0.0
	GameState.in_game = false
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 1, "")

func after_each() -> void:
	GameState.in_game = false
	Online.kicked = false
	Online.offline_mark.visible = false
	get_tree().paused = false

func _wipe_slots() -> void:
	for n: int in range(1, SaveManager.SLOTS + 1):
		SaveManager.set_slot(n)
		SaveManager.delete_save()
	SaveManager.set_slot(1)

## Title, New Game, slot 1 saved on the phone, all without a connection.
func _start_offline() -> void:
	assert_eq(await Online.connect_now(), Online.State.OFFLINE)
	SaveManager.set_slot(1)
	assert_true(SaveManager.start_fresh_slot())
	GameState.in_game = true

func test_new_game_offline_plays_without_any_screen() -> void:
	await _start_offline()
	assert_false(_server.signed_in(), "no account yet")
	assert_true(Online.dirty.has(1), "the local save waits to go up")
	Online._offline_for = OfflineMark.SHOW_AFTER
	await wait_process_frames(3)
	assert_false(get_tree().paused, "nothing pauses offline")
	assert_true(Online.offline_mark.visible, "only the small mark says so")
	assert_eq(Online.offline_mark.mark.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it takes no taps")

## The whole path: start offline, new game, play, the connection comes, the save is synced.
func test_start_offline_play_then_online_syncs_the_journey() -> void:
	await _start_offline()
	# Playing: a bond, some money, a save on the phone.
	GameState.money += 800
	GameState.set_flag("offline_test_step")
	assert_true(SaveManager.save_game())
	assert_true(Online.dirty.has(1))
	# The connection comes back; the next background try finds it.
	_server.offline = false
	Online._retry = 99.0
	for i: int in 30:
		await wait_process_frames(1)
		if Online.is_online() and not Online.dirty.has(1):
			break
	assert_eq(Online.state, Online.State.ONLINE, "online by itself, nothing to tap")
	assert_true(_server.signed_in(), "the account was made in the background")
	var got: Dictionary = (await _server.call_fn("save_get", {"p_slot": 1})).data
	assert_eq(int(got.data.money), GameState.money, "the offline progress reached the server")
	assert_true(bool(got.data.flags.get("offline_test_step", false)))
	assert_eq(int(Online.revs[1]), int(got.rev))
	assert_false(Online.dirty.has(1))
	assert_false(get_tree().paused)

func test_save_point_tries_the_connection_at_once() -> void:
	await _start_offline()
	_server.offline = false
	Online.offline_save_point()
	await wait_process_frames(5)
	assert_eq(Online.state, Online.State.ONLINE)
	assert_false(Online.dirty.has(1))

func test_still_offline_after_the_save_point_the_game_goes_on() -> void:
	await _start_offline()
	Online.offline_save_point()
	await wait_process_frames(3)
	Online._offline_for = OfflineMark.SHOW_AFTER + 120.0
	await wait_process_frames(3)
	assert_false(get_tree().paused, "no reconnect screen any more, even after minutes")
	assert_eq(Online.state, Online.State.OFFLINE)
	assert_true(Online.dirty.has(1), "the save still waits")

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

## Played offline here while another device saved the same slot: nothing is overwritten on
## either side; the slot becomes a conflict the title asks about (Online.conflicts).
func test_offline_progress_meeting_another_devices_save_is_kept_as_a_conflict() -> void:
	_server.offline = false
	assert_eq(await Online.connect_now(), Online.State.ONLINE)
	SaveManager.set_slot(1)
	assert_true(SaveManager.start_fresh_slot())
	GameState.in_game = true
	await wait_process_frames(3)
	assert_false(Online.dirty.has(1))
	var base: int = int(Online.revs[1])
	# The other device plays on and saves.
	var other: Dictionary = (await _server.call_fn("save_get", {"p_slot": 1})).data.data
	other["money"] = int(other.money) + 10
	var put: Dictionary = await _server.call_fn("save_put", {"p_slot": 1, "p_data": other, "p_summary": "other",
		"p_base_rev": base, "p_force": false, "p_request_id": "other-device"})
	assert_true(bool(put.data.ok))
	# This phone goes offline, plays and saves.
	_server.offline = true
	await Online.call_fn("presence", {"p_place": "x"})
	assert_eq(Online.state, Online.State.OFFLINE)
	GameState.money += 300
	var mine: int = GameState.money
	SaveManager.save_game()
	_server.offline = false
	await Online._reconnect()
	assert_true(Online.conflicts.has(1), "both journeys changed: the player decides")
	assert_true(Online.dirty.has(1), "this phone's journey is still waiting, not dropped")
	assert_eq(int(SaveManager.read_save(SaveManager.path_for_slot(1)).money), mine, "the local save is untouched")
	var on_server: Dictionary = (await _server.call_fn("save_get", {"p_slot": 1})).data
	assert_eq(int(on_server.data.money), int(other.money), "the other device's save is untouched")

## Another device took the account while this phone plays: it goes on offline instead of
## leaving for the title, and stops syncing until the title asks.
func test_other_device_mid_game_keeps_playing_offline() -> void:
	await _start_offline()
	var scene: Node = get_tree().current_scene
	Online._other_device()
	assert_true(Online.kicked)
	assert_eq(Online.state, Online.State.OFFLINE)
	assert_true(GameState.in_game, "still in the journey")
	assert_eq(get_tree().current_scene, scene, "no jump to the title")
	_server.offline = false
	Online._retry = 99.0
	await wait_process_frames(5)
	assert_eq(Online.state, Online.State.OFFLINE, "no automatic take-back of the account")

func test_update_checks_only_apply_online() -> void:
	# Offline there is no version to compare: the state stays OFFLINE and the game runs.
	await _start_offline()
	assert_ne(Online.state, Online.State.UPDATE_REQUIRED)
	assert_false(get_tree().paused)
