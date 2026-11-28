extends Node
## The work of tools/store_video.gd, run as a node so the autoloads exist. Every part is the game
## running (battle scene, unfurl moment, overworld, live duel); only the order is chosen here.

const FPS: int = 30
const TEAM_MINE: Array[String] = ["Noonregent", "Glintheron", "Dewstag"]
const TEAM_FOE: Array[String] = ["Eaveprowl", "Gildaurus", "Orremarch"]
const UNFURL: Array[String] = ["Glintwader", "Glintheron"]
const GLEAM_FOE: String = "Orremarch"
## [era, seconds]
const ERAS: Array = [[1, 1.5], [2, 1.5], [3, 1.5], [4, 2.0]]
var out: String = "user://store_video"
var _frame: int = 0
## Off while a scene is only warmed up (the first map shows the live event note once).
var _recording: bool = true

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	RenderingServer.frame_post_draw.connect(_grab)
	_run.call_deferred()

## Every drawn frame, as the screen shows it (run with --fixed-fps 30 so game time is steady).
func _grab() -> void:
	if not _recording:
		return
	var img: Image = get_tree().root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/f%05d.png" % [out, _frame])
	_frame += 1

func _wait(seconds: float) -> void:
	for i: int in int(seconds * FPS):
		await get_tree().process_frame

func _run() -> void:
	SaveManager.settings_path = "user://store_video_settings.json"
	Database.load_all()
	GameState.language = "en"
	Loc.set_language("en")
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	GameState.set_flag("got_starter")
	GameState.weather = false
	GameState.tips_enabled = false
	GameState.reduce_motion = false
	GameState.battle_speed = 2
	var em: Node = get_tree().root.get_node("/root/EraManager")
	em.set("unlocked_era", 5)
	em.call("set_retro_filter", 5)
	Era45Look.biome_override = "route"
	await _battle()
	await _gleam()
	await _unfurl()
	Era45Look.biome_override = ""
	await _eras(em)
	em.call("set_retro_filter", 5)
	await _duel()
	get_tree().quit()

func _team(names: Array[String], level: int) -> Array[Spirling]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out: Array[Spirling] = []
	for n: String in names:
		out.append(Spirling.new(Database.species(n), level, rng))
	return out

## Era V 3v3: the teams step out, then the battle runs on Auto for a few turns.
func _battle() -> void:
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	inst.backdrop = "field"
	var m := BattleModel.new(_team(TEAM_MINE, 40), _team(TEAM_FOE, 40), false, BattleScene.DEMO_SEED, 1)
	m.front_size = [3, 3]
	m.trainer_name = "Rift Mystic Ilka"
	inst.setup(m)
	inst.auto_kind = "wayfarer"
	get_tree().root.add_child(inst)
	for i: int in 9 * FPS:
		await get_tree().process_frame
		# Auto takes the orders once the menu is up, as a tap on the Auto tab does.
		if not inst._auto_on and inst._menu != null and inst._menu._content != null and inst._menu._content.visible:
			inst._on_auto_tab()
	inst.queue_free()
	Juice.calm()
	await get_tree().process_frame

## A wild Gleam steps in with its glints.
func _gleam() -> void:
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	inst.backdrop = "field"
	var foe: Array[Spirling] = _team([GLEAM_FOE], 38)
	foe[0].gleam = true
	var m := BattleModel.new(_team(["Noonregent"], 40), foe, true, BattleScene.DEMO_SEED, 0)
	inst.setup(m)
	get_tree().root.add_child(inst)
	await _wait(3.5)
	inst.queue_free()
	Juice.calm()
	await get_tree().process_frame

func _unfurl() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var u := UnfurlSequence.new()
	layer.add_child(u)
	await _wait(0.4)
	await u.play(Database.species(UNFURL[0]), Database.species(UNFURL[1]))
	await _wait(1.2)
	layer.queue_free()
	await get_tree().process_frame

## One town, era after era.
func _eras(em: Node) -> void:
	GameState.current_map = "brindlewick"
	GameState.player_cell = Vector2i(5, 8)
	var ow_tool: Node = _helper("res://tools/era45_overworld_shots_runner.gd")
	var m: MapData = MapData.load_map("brindlewick")
	if not m.is_walkable(GameState.player_cell):
		GameState.player_cell = ow_tool.call("_free_cell", m, GameState.player_cell)
	_recording = false
	em.call("set_retro_filter", 1)
	var warm: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(warm)
	await _wait(5.0)
	warm.queue_free()
	await get_tree().process_frame
	_recording = true
	for e: Array in ERAS:
		em.call("set_retro_filter", int(e[0]))
		var inst: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
		# The map's own fade-in is cut, so the eras follow each other directly.
		_recording = false
		get_tree().root.add_child(inst)
		await _wait(0.5)
		_recording = true
		await _wait(float(e[1]))
		inst.queue_free()
		await get_tree().process_frame

func _helper(path: String) -> Node:
	var s := GDScript.new()
	s.source_code = "extends \"%s\"\nfunc _run() -> void:\n\tpass\n" % path
	s.reload()
	var n := Node.new()
	n.set_script(s)
	add_child(n)
	return n

## The live duel of the store pictures (tools/store_shots_runner.gd), running for a few seconds.
func _duel() -> void:
	var shots: GDScript = load("res://tools/store_shots_runner.gd")
	var duel: Array = shots.start_duel(TEAM_MINE, TEAM_FOE, "Mara")
	get_tree().root.add_child(duel[0])
	await shots.wave_and_pick(get_tree(), duel)
	await _wait(3.0)
	shots.end_duel(duel)
	Juice.calm()
	await get_tree().process_frame
