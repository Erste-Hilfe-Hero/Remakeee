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
##                 ladder (AI tier n against n-1 on the same teams, item 817), mono (one-element teams,
##                 item 818) or goals (every bonus goal with its reference team on Tamer, item 820)
##   --field F     duel, team, ladder, mono: every battle on this field (item 821)
##   --variant V   duel, team, ladder, mono: these rule variants, comma-separated (item 821)
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
	var why: String = apply_switches(bs, opts)
	if not why.is_empty():
		push_error(why)
		quit(1)
		return
	var extra: Dictionary = {"ladder": ["run_ladder", "ladder_report"], "mono": ["run_mono", "mono_report"], "goals": ["run_goals", "goals_report"]}
	if extra.has(mode):
		var fns: Array = extra[mode]
		if mode == "ladder":
			result = bs.call(fns[0], level, int(opts.get("rounds", 200)), seed_value)
		elif mode == "mono":
			result = bs.call(fns[0], level, int(opts.get("rounds", 400)), seed_value, int(opts.get("ai", 2)))
		else:
			result = bs.call(fns[0], int(opts.get("rounds", 20)), seed_value)
		var etext: String = bs.call(fns[1], result)
		if opts.has("out"):
			_write(str(opts.out), etext)
		if opts.has("json"):
			_write(str(opts.json), JSON.stringify(result, " ", true))
		print(etext)
		quit()
		return
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

## Sets the --field and --variant switches on the simulator (item 821); returns why they can't
## be used ("" when fine): an unknown field, an unknown variant or variants that clash.
static func apply_switches(bs: GDScript, opts: Dictionary) -> String:
	var rules: GDScript = load("res://scripts/battle/BattleRules.gd")
	var field: String = str(opts.get("field", ""))
	if not field.is_empty() and not (rules.get("FIELDS") as Dictionary).has(field):
		return "Unknown field %s." % field
	var ids: Array[String] = []
	for v: String in str(opts.get("variant", "")).split(",", false):
		ids.append(v.strip_edges())
	var clash: String = rules.call("variant_conflict", ids)
	if not clash.is_empty():
		return clash
	bs.set("sim_field", field)
	bs.set("sim_variants", ids)
	return ""

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
