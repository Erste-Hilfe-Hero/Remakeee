extends GutTest
## Plan item 2210: a walk through the menus. Every row of every settings page (the same pages
## the title screen opens) and every entry of the pause menu is picked once; each must do
## something (open a list or a text, change its row, show a note, or close the menu), and the
## menu must close again when Back is pressed, so no menu hangs.

const MAX_FRAMES: int = 300

var _settings: Dictionary
var _lang: String

func before_each() -> void:
	_settings = GameState.settings_to_dict()
	_lang = GameState.language

func after_each() -> void:
	GameState.settings_from_dict(_settings)
	GameState.language = _lang
	Loc.set_language(_lang if not _lang.is_empty() else "en")

## Runs [param start], answers the lists with [param path] and then Back until it ends.
## Returns {done, effect, rows (of the list the last pick came from)}.
func _walk(host: MenuHost, start: Callable, path: Array) -> Dictionary:
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await start.call()
		state.done = true
	runner.call()
	var seen: int = 0
	var judging: bool = false
	var effect: bool = false
	var before_title: String = ""
	var before_rows: Array[String] = []
	var rows: Array[String] = []
	var frames: int = 0
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		if state.done:
			break
		if host._info_wait:
			if judging:
				effect = true
				judging = false
			host._page_turn = -2
			host._close_info()
		elif host.picks > seen and host.picker.visible:
			seen = host.picks
			if judging:
				effect = host.last_title != before_title or host.last_rows != before_rows \
					or host.toast_text() != ""
				judging = false
			if not path.is_empty():
				var i: int = int(path.pop_front())
				if path.is_empty():
					judging = true
					before_title = host.last_title
					before_rows = host.last_rows.duplicate()
					rows = before_rows
				host.picker.picked.emit(i)
			else:
				host.picker.picked.emit(-1)
	if judging and state.done:
		effect = true
	return {"done": state.done, "effect": effect, "rows": rows}

func _settings_host() -> MenuHost:
	var host := MenuHost.new()
	add_child_autofree(host)
	return host

func test_every_settings_row_does_something_and_closes() -> void:
	var host: MenuHost = _settings_host()
	await wait_process_frames(1)
	var top: Dictionary = await _walk(host, host.run_settings, [0])
	assert_true(top.done, "settings close with Back")
	var groups: int = MenuHost.SETTINGS_GROUPS.size()
	var walked: int = 0
	for g: int in groups:
		var first: Dictionary = await _walk(host, host.run_settings, [g])
		assert_true(first.done, "group %d closes" % g)
		assert_true(first.effect, "group %d opens something" % g)
		var inner: Dictionary = await _walk(host, host.run_settings, [g, -1])
		var count: int = 0
		# How many rows the group shows: walk into it once and read them.
		var probe: Dictionary = await _walk(host, host.run_settings, [g, 0])
		count = probe.rows.size()
		assert_true(inner.done)
		for r: int in count:
			GameState.settings_from_dict(_settings)
			var res: Dictionary = await _walk(host, host.run_settings, [g, r])
			assert_true(res.done, "group %d row %d: menu closes again" % [g, r])
			assert_true(res.effect, "group %d row %d (%s) does something" % [g, r, res.rows[r] if r < res.rows.size() else "?"])
			walked += 1
	assert_gt(walked, 20, "a real walk, not an empty one")

func test_every_pause_entry_opens_something_and_closes() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.set_flag(PauseMenu.STORAGE_FLAG)
	GameState.set_flag("aldo_gift")
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	menu.encounter_table = "fernstair"
	add_child_autofree(menu)
	await wait_process_frames(1)
	var labels: Array[String] = PauseMenu.menu_labels(true, false, false, false, true)
	for i: int in labels.size():
		var res: Dictionary = await _walk(menu, menu.run, [i])
		assert_true(res.done, "%s: the pause menu closes again" % labels[i])
		assert_true(res.effect, "%s does something" % labels[i])
		menu.photo = false
	GameState.in_game = false
