extends SceneTree
## Raw screens for the store screenshots, in one language (the list is in tools/store_shots_runner.gd).
## tools/store/make_store_images.py frames them with the captions of each store locale.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/store_shots.gd -- out_dir lang [groups]

var _out: String = "user://store_shots"
var _lang: String = "en"
var _only: String = "all"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_lang = args[1]
	if args.size() > 2:
		_only = args[2]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/store_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("lang", _lang)
	runner.set("only", _only)
	root.add_child(runner)
