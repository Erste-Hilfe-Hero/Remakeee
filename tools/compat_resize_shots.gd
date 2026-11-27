extends SceneTree
## Chimora 1.3.1 compat: the overworld while the window changes shape at runtime (fold, unfold,
## flip cover). One third scale of a phone, an unfolded fold and a flip cover display.
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a godot --path . --rendering-driver opengl3 \
##     -s res://tools/compat_resize_shots.gd -- out_dir

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runner: Node = load("res://tools/compat_resize_shots_runner.gd").new()
	runner.set("out", args[0] if args.size() > 0 else "user://compat_shots")
	DirAccess.make_dir_recursive_absolute(runner.get("out"))
	root.add_child.call_deferred(runner)
