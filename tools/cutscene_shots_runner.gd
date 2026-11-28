extends Node
## The work of tools/cutscene_shots.gd, run as a node so the autoloads exist.

## Cut-scene -> the map it plays on (tests/unit/test_cutscenes.gd HOSTS).
const SHOTS: Dictionary = {
	"cs_a1_pages": "lighthouse", "cs_a1_oar": "lighthouse", "cs_a1_cast_off": "brindlewick",
	"cs_a2_flock": "corvane_quay", "cs_a2_wide_rift": "wide_rift_edge",
	"cs_a3_ash": "ashmere_station", "cs_a3_plate": "gravers_hall", "cs_a3_seal": "wide_rift_far",
	"cs_a4_road": "ochrewell", "cs_a4_tower": "tower_rift", "cs_a4_caravan": "saltglass",
	"cs_f_edge": "undrawn_3", "cs_f_choir": "undrawn_3",
	"cs_e_guild": "madderby_guild", "cs_e_home": "lighthouse", "cs_e_open": "lighthouse",
}

var out: String = "user://cutscene_shots"
var lang: String = "en"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	Loc.set_language(lang)
	GameState.language = lang
	EraBoot.shown = true
	for n: int in range(1, SaveManager.SLOTS + 1):
		SaveManager.set_slot(n)
		SaveManager.delete_save()
	SaveManager.set_slot(1)
	var server := LocalBackend.new("user://cutscene_server.json")
	server.offline = true
	Online.backend = server
	Online.state = Online.State.OFFLINE
	Online.offline_play = true
	for id: String in SHOTS:
		await _scene(id, str(SHOTS[id]))
	get_tree().quit()

func _scene(id: String, map_id: String) -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Rowan", 0, "Kindlop")
	SaveManager.start_fresh_slot()
	for f: String in ["got_starter", "aldo_gift", Overworld.FIRST_WALK_FLAG]:
		GameState.set_flag(f)
	EraManager.retro_filter = 0
	EraManager.unlocked_era = int(ScenePlayer.load_scene(id).get("era", 1))
	EraManager._apply()
	GameState.current_map = map_id
	GameState.player_cell = _open_cell(MapData.load_map(map_id))
	GameState.facing = "down"
	GameState.in_game = true
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	await _frames(240)
	var sp := ScenePlayer.new()
	sp.overworld = ow
	ow.add_child(sp)
	var done: Array[bool] = [false]
	var run := func() -> void:
		await sp.play(id)
		done[0] = true
	run.call()
	var box: TextBox = ow.text_box()
	var shot: bool = false
	for i: int in 3000:
		if done[0]:
			break
		if box._waiting:
			print("rows %d: %s" % [box._label.get_line_count(), box._label.text.replace("\n", " ")])
			# The panel's first box (or the second box of a scene without a panel).
			if not shot and (sp.panel() != null or (id == "cs_a1_cast_off" and ow.scene_pan != Vector2.ZERO)):
				await _frames(20)
				await _shot(id)
				shot = true
			box.advance_now()
		await get_tree().process_frame
	if not shot:
		push_error("no shot of %s" % id)
	ow.queue_free()
	await _frames(4)

func _open_cell(m: MapData) -> Vector2i:
	var mid := Vector2i(m.width / 2, m.height / 2)
	for r: int in range(0, maxi(m.width, m.height)):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var c: Vector2i = mid + Vector2i(dx, dy)
				if m.in_bounds(c) and m.is_walkable(c) and m.warp_at(c).is_empty():
					return c
	return mid

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	var path: String = "%s/%s_%s.png" % [out, name, lang]
	img.save_png(path)
	print("saved ", path)
