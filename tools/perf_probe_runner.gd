extends Node
## The work of tools/perf_probe.gd, run as a node so the autoloads exist.

const FRAMES: int = 240
const SETTLE: int = 30
const AREAS: Array[String] = ["brindlewick", "saltmarsh", "hookwick", "tithe_road", "ledgerholm", "brightledge", "mossgate"]
var out: String = ""
var results: Dictionary = {}

func _ready() -> void:
	_run.call_deferred()

func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0

func _drawn() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var t0: int = Time.get_ticks_usec()
	var title: Node = load("res://scenes/ui/Title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await _drawn()
	results["cold_to_title_ms"] = Time.get_ticks_usec() / 1000.0
	results["title_build_ms"] = _ms(t0)
	_mem("mem_title")
	title.queue_free()
	await get_tree().process_frame
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	GameState.set_flag("got_starter")
	for id: String in Tips.TOPICS:
		GameState.set_flag(Tips.flag(id))
	GameState.reduce_motion = false
	GameState.day_night = true
	GameState.weather = true
	GameState.language = "en"
	Loc.set_language("en")
	EraManager.unlocked_era = 5
	GameState.current_map = "brindlewick"
	GameState.player_cell = _spot(MapData.load_map("brindlewick"))
	t0 = Time.get_ticks_usec()
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	await _drawn()
	results["title_to_world_ms"] = _ms(t0)
	await _frames(SETTLE)
	GameState.notices.clear()
	await _areas(ow)
	await _weather(ow)
	await _battle(ow)
	ow = await _fresh(ow)
	await _menu_open(ow, "pause", "pause_open_ms")
	ow = await _fresh(ow)
	await _menu_open(ow, "shop", "shop_open_ms")
	ow = await _fresh(ow)
	# Every region open and every kind seen, a third bonded: the Spirlog at its longest.
	for r: String in SpirlingData.REGIONS:
		GameState.set_flag("region_open_" + r)
	var i: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		GameState.mark_seen(sd.species_name, i % 3 == 0)
		i += 1
	results["spirlog_kinds"] = SpirlogBook.visible_kinds(GameState.flags).size()
	await _menu_open(ow, "spirlog", "spirlog_open_ms")
	_mem("mem_end")
	var text: String = JSON.stringify(results, "  ", true)
	print("PERF ", text)
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
	get_tree().quit()

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _mem(key: String) -> void:
	results[key] = {"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"texture_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)}

func _fresh(ow: Overworld) -> Overworld:
	ow.queue_free()
	await get_tree().process_frame
	var n: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(n)
	get_tree().current_scene = n
	await _frames(SETTLE)
	GameState.notices.clear()
	return n

func _spot(m: MapData) -> Vector2i:
	var mid := Vector2(m.width, m.height) / 2.0
	var best := Vector2i(1, 1)
	var best_d: float = INF
	for y: int in m.height:
		for x: int in m.rows[y].length():
			var c := Vector2i(x, y)
			var d: float = Vector2(c).distance_to(mid)
			if d < best_d and m.is_walkable(c) and m.warp_at(c).is_empty():
				best = c
				best_d = d
	return best

func _areas(ow: Overworld) -> void:
	var times: Array[float] = []
	for id: String in AREAS + AREAS:
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		var t0: int = Time.get_ticks_usec()
		ow.load_map(id, _spot(m), "down")
		await _drawn()
		times.append(_ms(t0))
		await _frames(5)
	results["area_change_ms"] = _stats(times)

func _stats(times: Array[float]) -> Dictionary:
	if times.is_empty():
		return {}
	var s: Array[float] = times.duplicate()
	s.sort()
	var sum: float = 0.0
	for t: float in s:
		sum += t
	return {"avg": snappedf(sum / s.size(), 0.01), "max": snappedf(s[-1], 0.01), "min": snappedf(s[0], 0.01), "n": s.size()}

## Average process time and wall frame time over FRAMES frames.
func _sample() -> Dictionary:
	var proc: Array[float] = []
	var wall: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for i: int in FRAMES:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		wall.append((now - last) / 1000.0)
		last = now
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	return {"process_ms": _stats(proc), "frame_ms": _stats(wall),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"canvas_items": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))}

func _weather(ow: Overworld) -> void:
	EraManager.set_retro_filter(3)
	EraLight.debug_weather = "rain"
	EraLight.debug_hour = 12.0
	var m: MapData = MapData.load_map("ledgerholm")
	ow.load_map("ledgerholm", _spot(m), "down")
	await _frames(SETTLE)
	results["overworld_rain_era3"] = await _sample()
	_mem("mem_overworld")
	EraManager.set_retro_filter(5)
	m = MapData.load_map("mossgate")
	ow.load_map("mossgate", _spot(m), "down")
	await _frames(SETTLE)
	results["overworld_rain_era5"] = await _sample()
	results["canvas_by_script_era5"] = _canvas_count()

func _all(n: Node) -> Array[Node]:
	var a: Array[Node] = [n]
	for c: Node in n.get_children():
		a.append_array(_all(c))
	return a

func _battle(ow: Overworld) -> void:
	EraLight.debug_weather = "clear"
	var times: Array[float] = []
	for i: int in 4:
		var foes: Array[Spirling] = [Spirling.new(Database.species("Mossling"), 5, GameState.rng)]
		var t0: int = Time.get_ticks_usec()
		var model: BattleModel = ow._new_model(foes, true, {})
		var scene: BattleScene = Overworld.BATTLE_SCENE.instantiate()
		scene.setup(model)
		scene.backdrop = ow.map.backdrop
		ow._battle_layer.add_child(scene)
		await _drawn()
		times.append(_ms(t0))
		await _frames(10)
		scene.queue_free()
		await _frames(3)
	results["battle_start_ms"] = _stats(times)

## Opens the pause menu, the shop or the Spirlog page and times it until the first drawn frame.
func _menu_open(ow: Overworld, what: String, key: String) -> void:
	var t0: int = Time.get_ticks_usec()
	if what == "pause":
		ow.open_menu()
	else:
		var menu := PauseMenu.new()
		menu.encounter_table = ow.map.encounter_table
		menu.current_map = ow.map.id
		ow._ui.add_child(menu)
		if what == "shop":
			ShopScreen.open(menu)
		else:
			menu.run_spirlog()
	await _drawn()
	results[key] = snappedf(_ms(t0), 0.01)
	await _frames(10)
	var settled: Dictionary = await _sample()
	results[key + "_settled_frame_ms"] = settled.frame_ms.avg

## Canvas items under the root, by script (or class), largest first.
func _canvas_count() -> Dictionary:
	var c: Dictionary = {}
	for n: Node in _all(get_tree().root):
		if not n is CanvasItem:
			continue
		var sc: Script = n.get_script()
		var key: String = sc.resource_path.get_file() if sc != null else n.get_class()
		c[key] = int(c.get(key, 0)) + 1
	var keys: Array = c.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(c[a]) > int(c[b]))
	var top: Dictionary = {}
	for k: String in keys.slice(0, 12):
		top[k] = c[k]
	return top
