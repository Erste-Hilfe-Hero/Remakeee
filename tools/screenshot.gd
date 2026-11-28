extends SceneTree
## Renders a few key screens and saves PNGs (for design review in PRs).
## Needs a real display (e.g. `xvfb-run godot --path . -s res://tools/screenshot.gd -- out_dir`).
## Shots: title, overworld in several maps, battle, bond minigame.
## A second argument picks the language: `-- out_dir de`.

var _out: String = "user://shots"
var _lang: String = "en"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_lang = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/screenshot_runner.gd").new()
	runner.set("out", _out)
	runner.set("lang", _lang)
	root.add_child(runner)
