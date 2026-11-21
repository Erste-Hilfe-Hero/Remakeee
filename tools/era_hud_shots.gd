extends SceneTree
## Battle HUD per era for design review (docs/ERA_FEEL_HUD.md): every HUD state (commands, art
## info card, plates with status, team picker, ring-rise panel, Echo call, Mine!, formation,
## German) in each of the five eras. Same idea as tools/era_battle_shots.gd.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_hud_shots.gd -- out_dir [era] [langs] [states]
## langs and states (comma lists, e.g. en,de,ru and menu,auto,trainer,info) replace the default set.

var _out: String = "user://era_hud_shots"
var _only: int = 0
var _langs: String = ""
var _states: String = "menu,auto,trainer,info,status,team"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_only = int(args[1])
	if args.size() > 2:
		_langs = args[2]
	if args.size() > 3:
		_states = args[3]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/era_hud_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("only", _only)
	runner.set("langs", _langs)
	runner.set("states", _states)
	root.add_child(runner)
