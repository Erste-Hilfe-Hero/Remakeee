extends SceneTree
## Plan Chimora 100 (owner wish 23.11.): the talk box against the on-screen buttons and the
## overworld without the Spirling behind the Wayfarer, in Eras I, III and V.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 -s res://tools/c100_textpos_shots.gd -- out_dir [langs]

var _out: String = "user://c100_textpos_shots"
var _langs: String = "en,de,ja"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_langs = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/c100_textpos_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("langs", _langs)
	root.add_child(runner)
