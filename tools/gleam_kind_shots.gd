extends SceneTree
## In-game battle shot per Gleam kind (data/gleam.json "kinds", 1.3.2): a wild battle in the era
## given (Era III shows the coloured glint; Era I maps all to four inks), foe and lead Gleams of
## that kind, settled at the command menu, scaled x4 nearest.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 144x256 \
##     -s res://tools/gleam_kind_shots.gd -- out_dir [era]

var _out: String = "user://gleam_kind_shots"
var _era: int = 3

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_era = int(args[1])
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/gleam_kind_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("era", _era)
	root.add_child(runner)
