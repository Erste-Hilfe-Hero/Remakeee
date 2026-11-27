extends SceneTree
## Chimora 200 list items 182, 187, 188: memory use and tablet layouts on the path title ->
## overworld -> pause menu -> bag -> battle, with a save on disk. Runs the real scenes:
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 2800x2100x24" godot --path . \
##     --rendering-driver opengl3 --resolution 2732x2048 -s res://tools/c200_tech_shots.gd -- out_dir tag [cycles]
## Saves <out_dir>/<tag>_<screen>.png and prints "mem <stage>: ..." lines (Performance monitors).
## With cycles > 1 the whole path runs again (pictures only the first time) to show leaks.

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runner: Node = load("res://tools/c200_tech_shots_runner.gd").new()
	if args.size() > 0:
		runner.set("out", args[0])
	if args.size() > 1:
		runner.set("tag", args[1])
	if args.size() > 2:
		runner.set("cycles", int(args[2]))
	DirAccess.make_dir_recursive_absolute(str(runner.get("out")))
	root.add_child.call_deferred(runner)
