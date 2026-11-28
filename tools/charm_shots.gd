extends SceneTree
## Screens of the bond charms (release 1.3.2): the "Hold out a charm?" picker in a wild battle and
## the shop's Bond charms page, in any languages and eras, at the window size given to Godot.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 393x852 \
##     -s res://tools/charm_shots.gd -- out_dir de,en 1,4

var _out: String = "user://charm_shots"
var _langs: PackedStringArray = ["de"]
var _eras: Array[int] = [1, 4]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_langs = args[1].split(",")
	if args.size() > 2:
		_eras = []
		for e: String in args[2].split(","):
			_eras.append(int(e))
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/charm_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("langs", _langs)
	runner.set("eras", _eras)
	root.add_child(runner)
