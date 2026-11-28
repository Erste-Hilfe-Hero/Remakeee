extends Node
## The work of tools/questbook_shots.gd, run as a node so the autoloads exist.

const MAX_FRAMES: int = 240
const FLAGS: Array[String] = ["aldo_gift", "met_kestra", "page_1", "page_2", "page_3", "rift_cinder_sealed",
	"kestra_spar", "got_lantern", "hollow_find", "q_fisher_asked", "q_fisher_done"]
const VISITED: Array[String] = ["lighthouse", "brindlewick", "fernstair", "crowcrest", "thornridge", "cinder_rift", "murk_hollow"]
var out: String = "user://questbook_shots"
var langs: PackedStringArray = ["en", "de"]
var era: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://questbook_shots_settings.json"
	var runner: GDScript = load("res://tools/era_menu_shots_runner.gd")
	for lang: String in langs:
		runner.call("setup_state")
		for f: String in FLAGS:
			GameState.flags[f] = true
		for id: String in VISITED:
			GameState.map_cells[id] = PackedByteArray([1, 0])
		GameState.language = lang
		Loc.set_language(lang)
		EraManager.unlocked_era = era
		EraManager.set_retro_filter(0)
		await get_tree().process_frame
		await _screens("era%d_%s" % [era, lang])
	EraManager.unlocked_era = 1
	get_tree().quit(0)

func _screens(t: String) -> void:
	var m := PauseMenu.new()
	m.current_map = "brindlewick"
	add_child(m)
	await get_tree().process_frame
	for i: int in QuestLog.BOOK_TABS.size():
		var tab: String = QuestLog.BOOK_TABS[i]
		QuestLog.tracked = "pages" if tab == QuestLog.SIDE else ""
		await _shoot(m, "%s_0%d_book_%s" % [t, i + 1, tab.to_lower()], func() -> void:
			await m.pick_screen("quests", PauseMenu.QUEST_BOOK, PauseMenu.quest_book_rows(tab, GameState.flags), {"tabs": QuestLog.BOOK_TABS, "tab": i}))
	var g: Dictionary = QuestLog.find("fern")
	QuestLog.tracked = "fern"
	await _shoot(m, t + "_04_where_next_map", func() -> void:
		await WorldMapMenu.run(m, m.current_map, QuestLog.target_place(g, GameState.flags)))
	var line := GoalLine.new()
	m.add_child(line)
	await get_tree().process_frame
	line._process(1.0)
	line.visible = true
	await _picture(t + "_05_goal_line")
	print("%s goal line: %s | doors: %s" % [t, line.text, QuestLog.goal_maps(GameState.flags)])
	line.queue_free()
	QuestLog.tracked = ""
	m.queue_free()
	await get_tree().process_frame

func _picture(shot: String) -> void:
	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])

## Runs [param start], takes the picture of what opens first, then closes it.
func _shoot(m: PauseMenu, shot: String, start: Callable) -> void:
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await start.call()
		state.done = true
	runner.call()
	await _picture(shot)
	for i: int in MAX_FRAMES:
		if state.done:
			break
		if m._info_wait:
			m._page_turn = -2
			m._close_info()
		elif m.picker.visible:
			m.picker.picked.emit(-1)
		await get_tree().process_frame
	if not state.done:
		printerr("%s: did not close" % shot)
