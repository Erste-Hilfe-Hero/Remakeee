extends SceneTree
## The terms step before the first connection: a new player (empty, ticked, a link tapped, then the
## title) and a player with a save who sees it once on the next start. Local test server, fresh
## user folder:
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/c100_terms_shots.gd -- out_dir lang tag

var _out: String = "user://c100_terms_shots"
var _lang: String = "en"
var _tag: String = "916"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_lang = args[1]
	if args.size() > 2:
		_tag = args[2]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/c100_terms_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("lang", _lang)
	runner.set("tag", _tag)
	root.add_child(runner)
