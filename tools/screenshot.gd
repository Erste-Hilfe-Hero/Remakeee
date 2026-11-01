extends SceneTree
## Renders a few key screens and saves PNGs (for design review in PRs).
## Needs a real display (e.g. `xvfb-run godot --path . -s res://tools/screenshot.gd -- out_dir`).
## Shots: title, overworld in several maps, battle, bond minigame.
## A second argument picks the language: `-- out_dir de`.

const SCALE: int = 3

var _out: String = "user://shots"
var _lang: String = "en"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_lang = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()

func _run() -> void:
	var db: Object = root.get_node("/root/GameState")
	Database.load_all()
	Loc.set_language(_lang)
	await _shot_scene("res://scenes/ui/Title.tscn", "01_title", 40)
	db.new_game(1, "Rowan", 0, "Kindlop")
	for entry: Array in [["lighthouse", Vector2i(4, 4)], ["brindlewick", Vector2i(5, 8)], ["fernstair", Vector2i(8, 6)], ["crowcrest", Vector2i(8, 11)], ["saltmarsh", Vector2i(7, 10)], ["thornridge", Vector2i(6, 9)], ["cinder_rift", Vector2i(6, 10)]]:
		db.current_map = entry[0]
		db.player_cell = entry[1]
		await _shot_scene("res://scenes/overworld/Overworld.tscn", "02_ow_%s" % entry[0], 30)
	await _shot_scene("res://scenes/battle/Battle.tscn", "03_battle", 420, "", 40)
	await _shot_scene("res://scenes/battle/BondMinigame.tscn", "04_bond", 70, "run")
	# Story battles with several Spirlings per side (formation layout).
	for d: String in ["boss", "duel3", "tag", "horde"]:
		await _shot_scene("res://scenes/battle/Battle.tscn", "05_battle_%s" % d, 600, "", 40, {"demo": d})
	quit()

## [param tap_every] > 0 presses ui_accept every that many frames (advances battle text).
func _shot_scene(path: String, name: String, frames: int, start_method: String = "", tap_every: int = 0, props: Dictionary = {}) -> void:
	var packed: PackedScene = load(path)
	var inst: Node = packed.instantiate()
	for k: String in props:
		inst.set(k, props[k])
	root.add_child(inst)
	current_scene = inst
	if inst is Control:
		(inst as Control).theme = UITheme.get_theme()
	if inst.has_method("run") and "target" in inst:
		inst.set("target", load("res://art/era1/spirlings/zippit_front.png"))
	if not start_method.is_empty():
		inst.call(start_method)
	for i: int in frames:
		if tap_every > 0 and i % tap_every == tap_every - 1:
			var ev := InputEventAction.new()
			ev.action = "ui_accept"
			ev.pressed = true
			Input.parse_input_event(ev)
			await process_frame
			var up := InputEventAction.new()
			up.action = "ui_accept"
			Input.parse_input_event(up)
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [_out, name])
	print("saved ", name)
	inst.queue_free()
	await process_frame
