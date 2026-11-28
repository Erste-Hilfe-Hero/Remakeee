extends SceneTree
## Chimora 1.3.2 adaptive screen: the overworld, a battle, the pause menu and the shop at the
## window size given with --resolution, saved as the whole window (bars would show).
##   xvfb-run -a -s "-screen 0 2400x2400x24" godot --path . --rendering-driver opengl3 \
##     --resolution 412x915 -s res://tools/adaptive_shots.gd -- out_dir [name] [top,bottom,left,right]
## The last argument simulates a notch / gesture bar in window pixels and tints it on the shots.
## Screens: title, overworld, pause, shop list and offer, Spirlog, settings, friends, a question
## and a text box, battle, the Mine! tug and the echo call. Exits 1 on a layout problem.

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runner: Node = load("res://tools/adaptive_shots_runner.gd").new()
	runner.set("out", args[0] if args.size() > 0 else "user://adaptive_shots")
	if args.size() > 1:
		runner.set("tag", args[1])
	if args.size() > 2:
		var ins: Array[float] = []
		for v: String in args[2].split(","):
			ins.append(v.to_float())
		ins.resize(4)
		runner.set("insets", ins)
	DirAccess.make_dir_recursive_absolute(runner.get("out"))
	root.add_child.call_deferred(runner)
