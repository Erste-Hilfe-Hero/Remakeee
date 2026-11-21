extends SceneTree
## Every menu screen in every era for design review (docs/ERA_FEEL_MENUS.md): start menu, team,
## summary, satchel, Spirlog list and page, save screen, settings, shop list and world map, in
## English and German, at each era's own phone resolution. Prints what does not fit
## (EraMenuKit.fit_problems) and exits 1 when a screen has a problem.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_menu_shots.gd -- out_dir

var _out: String = "user://era_menu_shots"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/era_menu_shots_runner.gd").new()
	runner.set("out", _out)
	root.add_child(runner)
