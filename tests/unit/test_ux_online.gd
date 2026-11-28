extends GutTest
## Plan area 5: clear online error texts, the reconnect screen, toasts and honest saving.

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_retry: float

func before_all() -> void:
	_old_backend = Online.backend
	_old_state = Online.state
	_old_retry = Online.net_retry_seconds

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Online.net_retry_seconds = _old_retry
	GameState.in_game = false

func test_error_text_tells_problems_apart() -> void:
	var seen: Dictionary[String, bool] = {}
	for code: String in ["no_internet", "unreachable", "server_503", "timeout", "401", "slow_down", "network"]:
		var t: String = OnlineErrors.text(code)
		assert_false(seen.has(t), "%s has its own sentence" % code)
		seen[t] = true
		assert_true(t in OnlineErrors.ALL)
	assert_eq(OnlineErrors.text("server_500"), OnlineErrors.UNREACHABLE)
	assert_eq(OnlineErrors.text("too_many_tries"), OnlineErrors.TOO_MANY)
	assert_eq(OnlineErrors.code_for_result(HTTPRequest.RESULT_CANT_RESOLVE), "no_internet")
	assert_eq(OnlineErrors.code_for_result(HTTPRequest.RESULT_TIMEOUT), "timeout")

func test_every_error_text_has_german() -> void:
	var t: PatternTranslation = Loc.load_translation("de")
	for line: String in OnlineErrors.ALL:
		var de: String = t.lookup(line)
		assert_false(de.is_empty() or de == line, "German for: " + line)

func test_no_menu_says_only_no_connection_any_more() -> void:
	for path: String in ["res://scripts/ui/AccountMenu.gd", "res://scripts/ui/FriendsMenu.gd", "res://scripts/ui/TitleScreen.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("No connection right now. Try again in a moment."), path)

func test_call_fn_tries_once_more_after_a_drop() -> void:
	var server := LocalBackend.new("user://test_ux_online.json")
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	server.rng.seed = 1
	Online.backend = server
	Online.net_retry_seconds = 0.05
	await Online.connect_now()
	assert_true(Online.is_online())
	server.offline = true
	var flip := func() -> void:
		await get_tree().create_timer(0.02).timeout
		server.offline = false
	flip.call()
	var r: Dictionary = await Online.call_fn("presence", {"p_place": "x"})
	assert_true(r.ok, "the second try went through, no message needed")
	assert_true(Online.is_online())
	DirAccess.remove_absolute("user://test_ux_online.json")

## docs/OFFLINE.md: no reconnect screen any more. A short drop shows nothing, a longer one only
## the small mark; nothing pauses, there is no button to press and no way back to the title.
func test_offline_shows_only_the_small_mark_and_never_pauses() -> void:
	var o := OfflineMark.new()
	add_child_autofree(o)
	o.update_view(1.0)
	assert_false(o.visible, "a short drop shows nothing")
	assert_false(get_tree().paused)
	o.update_view(OfflineMark.SHOW_AFTER)
	assert_true(o.visible)
	assert_false(get_tree().paused)
	o.update_view(3600.0)
	assert_false(get_tree().paused, "an hour offline still plays")
	assert_eq(o.get_children().filter(func(c: Node) -> bool: return c is Button).size(), 0, "nothing to tap")
	o.hide_mark()
	assert_false(get_tree().paused)

func test_toast_goes_away_by_itself() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	host.toast("Saved.", 0.05)
	assert_eq(host.toast_text(), "Saved.")
	await wait_seconds(0.15)
	assert_eq(host.toast_text(), "")

func test_connecting_text_moves_and_explains() -> void:
	assert_ne(TitleScreen.connecting_text(0.0), TitleScreen.connecting_text(0.6), "the dots move")
	assert_false(TitleScreen.connecting_text(1.0).contains("slowly"))
	assert_true(TitleScreen.connecting_text(6.0).contains("slowly"))
	assert_true(TitleScreen.connecting_text(16.0).contains("Still trying"))

func test_store_url_has_a_fallback() -> void:
	assert_true(Online.store_url().contains("://"))
