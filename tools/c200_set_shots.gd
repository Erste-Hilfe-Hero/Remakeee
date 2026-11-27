extends SceneTree
## Chimora 200 items 126 and 127: the Sound page with its "Reset to default" row, and the display
## settings without and with night mode (Dim, Warm).
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/c200_set_shots.gd -- out_dir

var _out: String = "user://c200_set_shots"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/c200_set_shots_runner.gd").new()
	runner.set("out", _out)
	root.add_child(runner)
