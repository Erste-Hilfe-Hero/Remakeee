extends SceneTree
## Menu screens of the Chimora 100 menu fixes (plan items 46-48, 51, 56, 60-62, 64) in any
## languages, at the window size given to Godot: pause with a festival, satchel, Spirlog page,
## display settings, shop list and Riftglass tab (online and offline), account, update panel
## and the short-drop connection mark. Long titles that would pop up first are shot as they are.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/c100_menu_shots.gd -- out_dir en,de,ja [era]

var _out: String = "user://c100_menu_shots"
var _langs: PackedStringArray = ["en", "de"]
var _era: int = 1

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_langs = args[1].split(",")
	if args.size() > 2:
		_era = int(args[2])
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/c100_menu_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("langs", _langs)
	runner.set("era", _era)
	root.add_child(runner)
