extends SceneTree
## One frame of every story cut-scene (data/scenes/cs_*.json, docs/STORY.md "Cut-scenes"): the
## panel and its first text box, each in its act's era.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 -s res://tools/cutscene_shots.gd -- out_dir [lang]
## Run it with its own XDG_DATA_HOME: it wipes the save slots of user://.

var _out: String = "user://cutscene_shots"
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
	var runner: Node = load("res://tools/cutscene_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("lang", _lang)
	root.add_child(runner)
