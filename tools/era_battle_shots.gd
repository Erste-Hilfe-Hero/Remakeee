extends SceneTree
## Battle screen per era for design review (docs/ERA_FEEL_BATTLE.md): the demo battle in each of
## the five eras: mid-intro and settled on each terrain, under each sky (rain, storm, wind), as
## 1v1, 2v2 and 3v3 after everyone has stepped out, each move effect, and under reduced motion.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_battle_shots.gd -- out_dir [groups]
## groups: "all" or a comma list of terrain, sky, formation, fx, scenes, fields, reduced.

var _out: String = "user://era_shots"
var _only: String = "all"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_only = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/era_battle_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("only", _only)
	root.add_child(runner)
