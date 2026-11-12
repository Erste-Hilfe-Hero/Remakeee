extends SceneTree
## Era moments for design review (docs/ERA_LOOK_TITLE.md): title, boot card, change scene, finale
## card and save cards of every era as frame strips.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_title_shots.gd -- out_dir [lang]

var _out: String = "user://era_title_shots"
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
	var runner: Node = load("res://tools/era_title_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("lang", _lang)
	root.add_child(runner)
