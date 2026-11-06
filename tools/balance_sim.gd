extends SceneTree
## Balancing simulator (headless):
##   godot --headless --path . -s res://tools/balance_sim.gd -- [level] [rounds] [out.md]
## Defaults: level 20, 10 rounds per pair, prints the report (and writes it if a path is given).
## Endgame economy (plan 3513): godot --headless --path . -s res://tools/balance_sim.gd -- endgame [days]
## The simulators are loaded at run time: compiling them together with this script would fail,
## because the autoloads they use (Online, GameState, ...) only exist once the tree is running.

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "endgame":
		load("res://scripts/core/Database.gd").call("load_all")
		var sim: GDScript = load("res://scripts/core/EndgameSim.gd")
		var days: int = int(args[1]) if args.size() > 1 else 90
		var r: Dictionary = sim.call("run", days)
		var report: String = sim.call("report", r)
		if args.size() > 2:
			var out := FileAccess.open(args[2], FileAccess.WRITE)
			out.store_string(report)
			out.close()
		print(report)
		quit()
		return
	var level: int = int(args[0]) if args.size() > 0 else 20
	var rounds: int = int(args[1]) if args.size() > 1 else 10
	var bs: GDScript = load("res://scripts/core/BalanceSim.gd")
	var result: Dictionary = bs.call("run", level, rounds, 1234)
	var text: String = bs.call("report", result)
	if args.size() > 2:
		var f := FileAccess.open(args[2], FileAccess.WRITE)
		f.store_string(text)
		f.close()
	print(text)
	quit()
