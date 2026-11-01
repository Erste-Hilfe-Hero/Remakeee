extends SceneTree
## Balancing simulator (headless):
##   godot --headless --path . -s res://tools/balance_sim.gd -- [level] [rounds] [out.md]
## Defaults: level 20, 10 rounds per pair, prints the report (and writes it if a path is given).

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level: int = int(args[0]) if args.size() > 0 else 20
	var rounds: int = int(args[1]) if args.size() > 1 else 10
	var result: Dictionary = BalanceSim.run(level, rounds, 1234)
	var text: String = BalanceSim.report(result)
	if args.size() > 2:
		var f := FileAccess.open(args[2], FileAccess.WRITE)
		f.store_string(text)
		f.close()
	print(text)
	quit()
