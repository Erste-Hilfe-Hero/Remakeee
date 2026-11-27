extends SceneTree
## Chimora 200 list items 83, 103, 137: the Spirlog top with a percent row per era, a kind with
## the event lantern, and the team with held keepsake icons, per era and language.
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/c200_team_shots.gd -- out_dir en,de 1,2,4

var _out: String = "user://c200_team_shots"
var _langs: PackedStringArray = ["en", "de"]
var _eras: PackedStringArray = ["1", "2", "4"]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_langs = args[1].split(",")
	if args.size() > 2:
		_eras = args[2].split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/c200_team_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("langs", _langs)
	runner.set("eras", _eras)
	root.add_child(runner)
