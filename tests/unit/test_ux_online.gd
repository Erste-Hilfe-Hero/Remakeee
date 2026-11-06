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

func test_reconnect_screen_counts_tries_and_offers_title_after_a_minute() -> void:
	var o := ReconnectOverlay.new()
	add_child_autofree(o)
	o.show_overlay()
	o.update_view(1, 4.2, 1.0)
	assert_false(o.is_big(), "a short drop only shows the small mark")
	assert_false(get_tree().paused)
	o.update_view(3, 4.2, ReconnectOverlay.SHORT_DROP)
	assert_true(o.is_big())
	assert_true(get_tree().paused)
	assert_string_contains(o._label.text, "Try 3. Next try in 5 s.")
	assert_true(o._try_button.visible)
	assert_false(o._title_button.visible)
	o.update_view(9, 1.0, ReconnectOverlay.TITLE_AFTER)
	assert_true(o._title_button.visible)
	o.hide_overlay()
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
