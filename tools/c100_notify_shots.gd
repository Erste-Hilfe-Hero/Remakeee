extends SceneTree
## Screens of plan Chimora 100, item 76 (opt-in phone notes): the one question with its text, the
## settings row and the privacy note. A fake plugin stands in for the phone.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 -s res://tools/c100_notify_shots.gd -- out_dir [lang]
## Run it with its own XDG_DATA_HOME: it writes user://notify.json.

var _out: String = "user://c100_notify_shots"
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
	var runner: Node = load("res://tools/c100_notify_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("lang", _lang)
	root.add_child(runner)
