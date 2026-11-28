extends SceneTree
## Chimora 100 items 25-36, 45, 52, 54 and the 1.3.2 opening: the new start, screen by screen (terms
## step with the privacy note, title, the first walk in the ferns, the storm Spirlings, partner
## pick, Mine!, Aldo, then in Brindlewick the storm card, look and name, the first goal).
## Runs the real Title and Overworld scenes on the local test server, in a fresh user folder:
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 440x956 \
##     -s res://tools/c100_start_shots.gd -- out_dir lang tag
## Prints the text boxes the player taps through until the walk to the village and the first goal.

var _out: String = "user://c100_start_shots"
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
	var runner: Node = load("res://tools/c100_start_shots_runner.gd").new()
	runner.set("out", _out)
	runner.set("lang", _lang)
	runner.set("tag", _tag)
	root.add_child(runner)
