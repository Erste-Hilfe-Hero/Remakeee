extends Node
## The work of tools/era_battle_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 2
var out: String = "user://era_shots"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	var em: Node = get_tree().root.get_node("/root/EraManager")
	em.set("unlocked_era", 5)
	for era: int in range(1, 6):
		em.call("set_retro_filter", era)
		for terrain: String in (["field", "lake", "ember"] if era > 1 else ["field"]):
			await _shot(era, terrain, 12, "intro")
			await _shot(era, terrain, 150, "settled")
		await _shot(era, "field", 150, "rain", "", "rain")
		await _shot(era, "ridge", 150, "storm", "", "storm")
		await _shot(era, "field", 300, "duel3", "duel3")
	get_tree().quit()

func _shot(era: int, terrain: String, frames: int, tag: String, demo: String = "", sky: String = "") -> void:
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	inst.backdrop = terrain
	inst.demo = demo
	if not sky.is_empty():
		var m: BattleModel = inst._demo_model()
		var f: Dictionary = WeatherCycle.battle_field(sky)
		m.field = str(f.field)
		m.field_intro = str(f.intro)
		inst.setup(m)
	get_tree().root.add_child(inst)
	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/era%d_%s_%s.png" % [out, era, terrain, tag])
	print("saved era%d %s %s" % [era, terrain, tag])
	inst.queue_free()
	await get_tree().process_frame
