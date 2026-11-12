extends SceneTree
## Era IV/V overworld depth for design review (data/era45_overworld.json): Era III, IV and V towns,
## each once without the building depth ("before") and once with it ("after").
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era45_overworld_shots.gd -- out_dir

var _out: String = "user://era45_overworld"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/era45_overworld_shots_runner.gd").new()
	runner.set("out", _out)
	root.add_child(runner)
