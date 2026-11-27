extends SceneTree
## Chimora 1.3.2 adaptive screen: the overworld, a battle, the pause menu and the shop at the
## window size given with --resolution, saved as the whole window (bars would show).
##   xvfb-run -a -s "-screen 0 2400x2400x24" godot --path . --rendering-driver opengl3 \
##     --resolution 412x915 -s res://tools/adaptive_shots.gd -- out_dir [name]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runner: Node = load("res://tools/adaptive_shots_runner.gd").new()
	runner.set("out", args[0] if args.size() > 0 else "user://adaptive_shots")
	if args.size() > 1:
		runner.set("tag", args[1])
	DirAccess.make_dir_recursive_absolute(runner.get("out"))
	root.add_child.call_deferred(runner)
