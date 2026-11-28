extends SceneTree
## The boot card (EraBoot) at real phone sizes, for review: one PNG per frame and size, drawn by
## hand at fixed seconds so the shots are the same each run. Sizes are view pixels, the size
## ScreenFit gives a phone (390 x 844 pt iPhone: 146 x 317; 375 x 667 pt iPhone SE: 150 x 267).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/boot_shots.gd -- out_dir [langs] [sizes] [seconds] [era]
## langs "de,es", sizes "146x317,150x267", seconds "0.3,0.6,1.5" (the last one is also saved alone).

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runner: Node = load("res://tools/boot_shots_runner.gd").new()
	if args.size() > 0:
		runner.set("out", args[0])
	if args.size() > 1:
		runner.set("langs", args[1].split(","))
	if args.size() > 2:
		runner.set("sizes", args[2].split(","))
	if args.size() > 3:
		runner.set("seconds", args[3].split(","))
	if args.size() > 4:
		runner.set("era", args[4].to_int())
	_start.call_deferred(runner)

func _start(runner: Node) -> void:
	root.add_child(runner)
