extends SceneTree
## Screens of the new shop (pay-to-win shop rebuild, 27.11.2026) in any languages, at the window
## size given to Godot: Featured home, every tab, two detail pages, the Starter Pack and First Catch Pack notes and the
## locked shop of a child account.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/p2w_shop_shots.gd -- out_dir de,en [era: 1, 1,4 or all]

var _out: String = "user://p2w_shop_shots"
var _langs: PackedStringArray = ["de", "en"]
var _eras: Array[int] = [1]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_langs = args[1].split(",")
	if args.size() > 2:
		_eras = []
		for e: String in (["1", "2", "3", "4", "5"] if args[2] == "all" else Array(args[2].split(","))):
			_eras.append(int(e))
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/p2w_shop_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("langs", _langs)
	runner.set("eras", _eras)
	root.add_child(runner)
