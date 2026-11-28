extends SceneTree
## Frame strips of the UI flow (update 1.3.2, docs/FLOW.md): each strip is one transition, one
## frame per tile at 60 frames a second, so a hard cut shows as two tiles with nothing between.
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 60 \
##     --resolution 288x512 -s res://tools/flow_shots.gd -- out_dir [era ...]

var _out: String = "user://flow_shots"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var eras: Array[int] = []
	if args.size() > 0:
		_out = args[0]
	for i: int in range(1, args.size()):
		eras.append(int(args[i]))
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred(eras)

func _start(eras: Array[int]) -> void:
	var runner: Node = load("res://tools/flow_shots_runner.gd").new()
	runner.set("out", _out)
	if not eras.is_empty():
		runner.set("eras", eras)
	root.add_child(runner)
