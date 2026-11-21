extends SceneTree
## Screens of plan Chimora 100, items 37-44 for review: the overworld with the goal line, the goal
## door marks and the minimap, the Era I pause menu with More and Map, the world map, the Spirlog
## legend and the Welcome back card.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 432x768 -s res://tools/goal_shots.gd -- out_dir [lang]

var _out: String = "user://goal_shots"
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
	var runner: Node = load("res://tools/goal_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("lang", _lang)
	root.add_child(runner)
