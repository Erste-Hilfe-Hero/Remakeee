extends SceneTree
## Weather in the real overworld for design review (data/weather.json, data/era_light.json):
## every weather kind in maps of several eras, at the window size given to Godot.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/weather_shots.gd -- out_dir [prefix] [only]
## prefix goes in front of every file name ("before", "after"); only is a comma list of name parts.

var _out: String = "user://weather_shots"
var _prefix: String = "after"
var _only: PackedStringArray = []

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_prefix = args[1]
	if args.size() > 2:
		_only = args[2].split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/weather_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("prefix", _prefix)
	runner.set("only", _only)
	root.add_child(runner)
