extends SceneTree
## Balancing simulator (headless):
##   godot --headless --path . -s res://tools/balance_sim.gd -- --level 36 --rounds 10 --mode duel
## Named switches (plan area 2, item 808):
##   --level N     ring of every Spirling (default 20)
##   --rounds N    duel: battles per species pair (default 10); team: battles in all (default 500)
##   --seed N      seed of the run (default 1234)
##   --mode M      duel (1-on-1 within an evolution stage) or team (random teams of 3 and 5)
##   --ai N        AI tier for both sides (duel default 1, team default 2)
##   --out PATH    also write the Markdown report there
##   --json PATH   also write every number as JSON there
## The old positional form "[level] [rounds] [out.md]" still works.

func _init() -> void:
	var opts: Dictionary = parse_args(OS.get_cmdline_user_args())
	var mode: String = str(opts.get("mode", "duel"))
	var level: int = int(opts.get("level", 20))
	var seed_value: int = int(opts.get("seed", 1234))
	var result: Dictionary
	if mode == "team":
		result = BalanceSim.run_team(level, int(opts.get("rounds", 500)), seed_value, int(opts.get("ai", 2)))
	else:
		result = BalanceSim.run(level, int(opts.get("rounds", 10)), seed_value, [], int(opts.get("ai", 1)))
	var text: String = BalanceSim.report(result)
	if opts.has("out"):
		_write(str(opts.out), text)
	if opts.has("json"):
		_write(str(opts.json), BalanceSim.to_json(result))
	print(text)
	quit()

## "--key value" pairs into a Dictionary; bare positional values fill level, rounds, out.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var positional: Array[String] = ["level", "rounds", "out"]
	var i: int = 0
	while i < args.size():
		var a: String = args[i]
		if a.begins_with("--"):
			var key: String = a.substr(2)
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				out[key] = args[i + 1]
				i += 2
				continue
			out[key] = "true"
		elif not positional.is_empty():
			out[positional.pop_front()] = a
		i += 1
	return out

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
