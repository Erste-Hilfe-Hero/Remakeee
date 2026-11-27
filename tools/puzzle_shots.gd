extends SceneTree
## Riddle stones and puzzle boards (data/puzzle_spots.json) in the real overworld UI, upscaled x3:
## a stone's intro, a pick riddle, a typed riddle and the lamp, slide, push, steps and bell boards.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/puzzle_shots.gd -- out_dir de,en [era]

var _out: String = "user://puzzle_shots"
var _langs: PackedStringArray = ["de"]
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
	var runner: Node = load("res://tools/puzzle_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("langs", _langs)
	runner.set("era", _era)
	root.add_child(runner)
