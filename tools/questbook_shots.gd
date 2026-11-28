extends SceneTree
## Quest Book screens (Chimora 1.3.2): the Main, Side and Done tabs and the world map after
## "Where next?" with the quest ring and the open-quest flags, in any languages.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/questbook_shots.gd -- out_dir en,de,ja [era]

var _out: String = "user://questbook_shots"
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
	var runner: Node = load("res://tools/questbook_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("langs", _langs)
	runner.set("era", _era)
	root.add_child(runner)
