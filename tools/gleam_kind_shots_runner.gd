extends Node
## The work of tools/gleam_kind_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 4
const READY_FRAMES: int = 1800
const SETTLE_FRAMES: int = 40
const SEED: int = 4321
var out: String = "user://gleam_kind_shots"
var era: int = 3

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	GameState.reduce_motion = false
	var em: Node = get_tree().root.get_node("/root/EraManager")
	em.set("unlocked_era", maxi(era, 1))
	em.call("set_retro_filter", era)
	for id: String in GleamRules.kind_ids():
		await _shot(id)
	get_tree().quit()

func _shot(id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var mine: Array[Spirling] = BattleScene._demo_team(rng, ["Mossling"] as Array[String], 14)
	var theirs: Array[Spirling] = BattleScene._demo_team(rng, ["Kindlop"] as Array[String], 12)
	GleamRules.apply(mine[0], id)
	GleamRules.apply(theirs[0], id)
	var m := BattleModel.new(mine, theirs, true, SEED, 0)
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	inst.backdrop = "field"
	inst.setup(m)
	get_tree().root.add_child(inst)
	for i: int in 3:
		await get_tree().process_frame
	var left: int = READY_FRAMES
	while not (inst._menu != null and inst._menu._content != null and inst._menu._content.visible) and left > 0:
		inst._text.advance_now()
		await get_tree().process_frame
		left -= 1
	if left <= 0:
		push_error("gleam %s: the command menu never opened" % id)
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/gleam_ingame_%s.png" % [out, id])
	print("saved gleam_ingame_%s" % id)
	inst.queue_free()
	Juice.calm()
	await get_tree().process_frame
