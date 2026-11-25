extends SceneTree
## Chimora 200 list items 2, 11, 17: the Continue row with the team lead, the first battle's
## arrow at the first art and the place pictures in Earlier saves.
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/c200_start_shots.gd -- out_dir

var _out: String = "user://c200_start_shots"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/c200_start_shots_runner.gd").new()
	runner.set("out", _out)
	root.add_child(runner)
