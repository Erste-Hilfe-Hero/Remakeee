extends SceneTree
## Raw screens for the store screenshots of the current version, in one language:
## title, overworld in Eras I to V, 3v3 battles in Eras II, IV and V, a Spirlog page and an offer's
## contents in the shop (Bond Lure I). The framing with captions per store locale is done outside the game repo
## (same look as tools/store/make_store_images.py).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/store_shots.gd -- out_dir lang

var _out: String = "user://store_shots"
var _lang: String = "en"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_lang = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/store_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("lang", _lang)
	root.add_child(runner)
