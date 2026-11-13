extends SceneTree
## Overworld terrain per era for design review (docs/ERA_FEEL_TILES.md): one or two maps of each
## era's region, once without the era terrain look ("before") and once with it ("after").
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_tiles_shots.gd -- out_dir

var _out: String = "user://era_tiles"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/era_tiles_shots_runner.gd").new()
	runner.set("out", _out)
	root.add_child(runner)
