extends SceneTree
## Timing of the everyday screen changes and the overworld frame (1.3.2 perf pass):
## cold start to title, title to world, area change, battle start, shop, Spirlog with every
## kind seen, the pause menu, the overworld frame with weather on, and memory.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/perf_probe.gd -- out.json
## Without an out file it only prints. The numbers are this machine's; compare runs on one box.

var _out: String = ""

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/perf_probe_runner.gd").new()
	runner.set("out", _out)
	root.add_child(runner)
