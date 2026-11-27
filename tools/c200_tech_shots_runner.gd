extends Node
## The work of tools/c200_tech_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 3
const MAX_FRAMES: int = 240
const MB: float = 1048576.0

var out: String = "user://c200_tech_shots"
var tag: String = "phone"
var cycles: int = 1
var eras: PackedInt32Array = [1, 5]
var _pictures: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	SaveManager.settings_path = "user://c200_tech_settings.json"
	load("res://tools/era_menu_shots_runner.gd").call("setup_state")
	GameState.language = "en"
	Loc.set_language("en")
	GameState.terms_version = LegalInfo.TERMS_VERSION
	Online.privacy_seen = true
	Online.backend = LocalBackend.new("user://c200_tech_server.json")
	EraBoot.shown = true
	GameState.set_flag("got_starter")
	GameState.weather = false
	GameState.battle_speed = 2
	_mem("boot")
	for c: int in cycles:
		for era: int in eras:
			_pictures = c == 0
			await _path(era, "c%d_era%d" % [c + 1, era])
	await _frames(30)
	_mem("end")
	print("mem peak static: %.1f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / MB))
	get_tree().quit()

func _path(era: int, stage: String) -> void:
	EraManager.unlocked_era = era
	EraManager.set_retro_filter(0 if era == 1 else era)
	GameState.current_map = "brindlewick" if era == 1 else "driftwick"
	GameState.player_cell = Vector2i(5, 9)
	SaveManager.save_game()
	var title: TitleScreen = load("res://scenes/ui/Title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await _until(func() -> bool: return title._menu.picker.visible and title._menu.picker._buttons.size() > 0)
	await _picture("era%d_title" % era)
	_mem(stage + "_title")
	title.queue_free()
	await _frames(2)
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	await _frames(150)
	await _picture("era%d_overworld" % era)
	_mem(stage + "_overworld")
	var m := PauseMenu.new()
	m.current_map = GameState.current_map
	m.encounter_table = GameState.current_map
	ow._ui.add_child(m)
	await get_tree().process_frame
	await _shoot(m, "era%d_pause" % era, m.run)
	await _shoot(m, "era%d_bag" % era, m.run_bag)
	_mem(stage + "_bag")
	m.queue_free()
	await _frames(2)
	var b: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	b.backdrop = "field"
	var model: BattleModel = b._demo_model()
	model.set_meta("quick", true)
	b.setup(model)
	b.auto_kind = "wild"
	ow._battle_layer.add_child(b)
	for i: int in 900:
		if b._menu._content.is_visible_in_tree() and not b._text._waiting:
			break
		if b._text._waiting:
			b._text.advance_now()
		await get_tree().process_frame
	await _frames(60)
	await _picture("era%d_battle" % era)
	_mem(stage + "_battle")
	b.queue_free()
	ow.queue_free()
	await _frames(10)
	_mem(stage + "_freed")

func _mem(stage: String) -> void:
	print("mem %s: static %.1f MB, static peak %.1f MB, texture %.1f MB, video %.1f MB, objects %d, resources %d, nodes %d, orphan nodes %d" % [
		stage, Performance.get_monitor(Performance.MEMORY_STATIC) / MB,
		Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / MB,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _until(cond: Callable) -> bool:
	for i: int in 900:
		if cond.call():
			return true
		await get_tree().process_frame
	push_warning("c200 tech shots: timed out")
	return false

func _picture(shot: String) -> void:
	await _frames(12)
	if not _pictures:
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s_%s.png" % [out, tag, shot])
	print("saved ", shot, " ", img.get_size() / SCALE, " window ", get_window().size)

## Like tools/c100_menu_shots_runner.gd: runs [param start], takes the picture of what opens
## first, then closes everything until the coroutine ends.
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
