extends SceneTree
## Overworld light, weather and screen effects per era for design review (data/era_light.json):
## maps of each era's own region under set weather and hours.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_light_shots.gd -- out_dir

var _out: String = "user://era_light_shots"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/era_light_shots_runner.gd").new()
	runner.set("out", _out)
	root.add_child(runner)
