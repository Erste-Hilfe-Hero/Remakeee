extends SceneTree
## Balancing simulator (headless):
##   godot --headless --path . -s res://tools/balance_sim.gd -- --level 36 --rounds 10 --mode duel
## Named switches (plan area 2, item 808):
##   --level N     ring of every Spirling (default 20)
##   --rounds N    duel: battles per species pair (default 10); team: battles in all (default 500);
##                 warden: battles per team, Warden and difficulty (default 100)
##   --seed N      seed of the run (default 1234)
##   --mode M      duel (1-on-1 within an evolution stage), team (random teams of 3 and 5) or
##                 warden (tools/balance/ref_teams.json against every Warden per difficulty, item 810)
##   --ai N        AI tier for both sides (duel default 1, team default 2; warden: the reference side)
##   --section S   warden: only this section of ref_teams.json (pre_orrin, pre_maelis, post_rifts)
##   --out PATH    also write the Markdown report there
##   --json PATH   also write every number as JSON there
## The old positional form "[level] [rounds] [out.md]" still works.
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
			_write(args[2], report)
		print(report)
		quit()
		return
	var opts: Dictionary = parse_args(args)
	var mode: String = str(opts.get("mode", "duel"))
	var level: int = int(opts.get("level", 20))
	var seed_value: int = int(opts.get("seed", 1234))
	var bs: GDScript = load("res://scripts/core/BalanceSim.gd")
	var result: Dictionary
	if mode == "warden":
		var secs: Array[String] = []
		if opts.has("section"):
			secs.append(str(opts.section))
		result = bs.call("run_warden", int(opts.get("rounds", 100)), seed_value, int(opts.get("ai", 2)), [] as Array[int], secs)
		var wtext: String = bs.call("warden_report", result)
		if opts.has("out"):
			_write(str(opts.out), wtext)
		if opts.has("json"):
			_write(str(opts.json), JSON.stringify(result, " ", true))
		print(wtext)
		quit()
		return
	if mode == "team":
		result = bs.call("run_team", level, int(opts.get("rounds", 500)), seed_value, int(opts.get("ai", 2)))
	else:
		result = bs.call("run", level, int(opts.get("rounds", 10)), seed_value, [] as Array[String], int(opts.get("ai", 1)))
	var text: String = bs.call("report", result)
	if opts.has("out"):
		_write(str(opts.out), text)
	if opts.has("json"):
		_write(str(opts.json), bs.call("to_json", result))
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
