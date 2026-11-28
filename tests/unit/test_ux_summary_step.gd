extends GutTest
## Plan item 1893: up and down in the summary go straight to the team's next Spirling.

const MAX_FRAMES: int = 200

var _unlocked: int
var _retro: int

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter

func after_each() -> void:
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)
	GameState.in_game = false

func _key(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev

## Opens the summary of team slot 0 in era [param e], presses [param keys] one per view,
## then Back; returns the names shown in order.
func _walk(e: int, keys: Array[String]) -> Array[String]:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.party.append(Spirling.new(Database.species("Mossling"), 5))
	GameState.party.append(Spirling.new(Database.species("Zippit"), 5))
	EraManager.unlocked_era = e
	EraManager.set_retro_filter(0)
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	add_child_autofree(menu)
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await menu.run_summary(GameState.party[0], true, 0)
		state.done = true
	runner.call()
	var shown: Array[String] = []
	var frames: int = 0
	var last: Object = null
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		var view: EraSummary = null
		for c: Node in menu.get_children():
			if c is EraSummary and not c.is_queued_for_deletion():
				view = c
		var current: Object = view if view != null else (menu if menu._info_wait else null)
		if current == null or (current == last and view != null) or (view == null and not menu._info_wait):
			continue
		if view != null:
			shown.append(view.spirling.display_name())
		else:
			shown.append(menu._info_source if "_info_source" in menu else "")
		last = current
		var key: String = keys.pop_front() if not keys.is_empty() else "ui_cancel"
		if view != null:
			view._unhandled_input(_key(key))
		else:
			menu._unhandled_input(_key(key))
		await wait_process_frames(2)
	assert_true(state.done, "era %d summary closes" % e)
	return shown

func test_tabbed_summary_steps_down_and_wraps_up() -> void:
	var names: Array[String] = await _walk(4, ["ui_down", "ui_up", "ui_up"] as Array[String])
	assert_eq(names.size(), 4)
	assert_eq(names[0], GameState.party[0].display_name())
	assert_eq(names[1], GameState.party[1].display_name(), "down: the next team member")
	assert_eq(names[2], GameState.party[0].display_name(), "up: back to the first")
	assert_eq(names[3], GameState.party[2].display_name(), "up from the first wraps to the last")

func test_text_summary_steps_too() -> void:
	var names: Array[String] = await _walk(1, ["ui_up"] as Array[String])
	assert_eq(names.size(), 2, "up opened another summary, then Back closed it")

func test_without_a_team_slot_up_and_down_do_nothing() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.party.append(Spirling.new(Database.species("Mossling"), 5))
	var view := EraSummary.new()
	view.spirling = GameState.party[0]
	view.lay = EraMenus.layout(4, "summary")
	add_child_autofree(view)
	view.build()
	view._unhandled_input(_key("ui_down"))
	assert_eq(view.step, 0)
