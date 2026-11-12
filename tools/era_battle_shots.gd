extends SceneTree
## Battle screen per era for design review (docs/ERA_FEEL_BATTLE.md): the demo battle in each of
## the five eras, once mid-intro and once settled, on each terrain.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_battle_shots.gd -- out_dir

var _out: String = "user://era_shots"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/era_battle_shots_runner.gd").new()
	runner.set("out", _out)
	root.add_child(runner)
