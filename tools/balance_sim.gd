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
##   --difficulty D duel, team, ladder, mono: foe side tuned like a Wayfarer on story, tamer,
##                 veteran or rift_born (0-3): Spark, rings, AI, Energy (item 822)
##   --compare P   team: flag every species and art whose win rate moved more than 8 points
##                 from the baseline P (default tools/balance/baseline_lv36.json, item 816);
##                 write a new baseline with --mode team --level 36 --json <path>
##   --mode keepsakes  every holdable item: win rate of a team whose lead holds it against the same
##                 battle without (item 828, target at most +6 points)
##   --mode fields  every field with a boosted element: teams of that element on the field against
##                 the same battle without (item 829, band +8 to +15 points)
##   --mode puzzle  every puzzle of data/puzzles.json: solutions and fewest turns (item 819);
##                 --puzzle ID for one
##   --seeds N     duel, team: the run on N seeds (seed, seed+7919, ...); the report adds mean and
##                 spread per species and marks a spread over 10 points as uncertain (item 830)
##   --mode acts   the player route of tools/balance/act_route.json through every act and era region
##                 (scripts/core/ActSim.gd): arrival rings, win rate on arrival and after a moderate
##                 grind, grind battles to 70 % per Warden, rival and boss; --rounds N battles per
##                 measure (default 40), --starter S one starter, --act ID one act
##   --mode mirror every species against itself (default 400 duels each, item 831): the player
##                 side must win 45 to 55 %
##   The team report also lists every new art under 1 % of its element's picks (item 833).
##   Duel and team reports end with win rates pooled per trait and per element (BalanceGroups).
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
	var extra: Dictionary = {"ladder": ["run_ladder", "ladder_report"], "mono": ["run_mono", "mono_report"], "goals": ["run_goals", "goals_report"],
		"puzzle": ["run_puzzles", "puzzle_report"], "keepsakes": ["run_keepsakes", "keepsakes_report"], "fields": ["run_fields", "fields_report"]}
	if extra.has(mode):
		var fns: Array = extra[mode]
		if mode == "ladder":
			result = bs.call(fns[0], level, int(opts.get("rounds", 200)), seed_value)
		elif mode == "mono":
			result = bs.call(fns[0], level, int(opts.get("rounds", 400)), seed_value, int(opts.get("ai", 2)))
		elif mode == "keepsakes" or mode == "fields":
			result = bs.call(fns[0], level, int(opts.get("rounds", 200)), seed_value)
		elif mode == "puzzle":
			result = bs.call(fns[0], str(opts.get("puzzle", "")))
		else:
			var gd: int = int(bs.get("sim_difficulty"))
			result = bs.call(fns[0], int(opts.get("rounds", 20)), seed_value, gd if gd >= 0 else 1)
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
	if mode == "acts":
		var act_sim: GDScript = load("res://scripts/core/ActSim.gd")
		var cfg: Dictionary = act_sim.call("route")
		var starters: Array = cfg.get("starters", ["Kindlop"])
		if opts.has("starter"):
			starters = [str(opts.starter)]
		var only: Array[String] = []
		if opts.has("act"):
			only.append(str(opts.act))
		var trials: int = int(opts.get("rounds", 40))
		var runs: Array = []
		for st: Variant in starters:
			runs.append(act_sim.call("run", str(st), trials, seed_value, only))
		var sum: Dictionary = act_sim.call("summary", runs)
		var atext: String = act_sim.call("report", sum, starters, trials)
		if opts.has("out"):
			_write(str(opts.out), atext)
		if opts.has("json"):
			_write(str(opts.json), JSON.stringify(sum, " ", true))
		print(atext)
		quit()
		return
	if mode == "mirror":
		result = bs.call("run_mirror", level, int(opts.get("rounds", 400)), seed_value, int(opts.get("ai", 1)))
		var mtext: String = bs.call("mirror_report", result)
		if opts.has("out"):
			_write(str(opts.out), mtext)
		if opts.has("json"):
			_write(str(opts.json), JSON.stringify(result, " ", true))
		print(mtext)
		quit()
		return
	var seeds: Dictionary = {}
	if opts.has("seeds") and int(opts.seeds) > 1:
		var team_mode: bool = mode == "team"
		seeds = bs.call("run_seeds", mode, level, int(opts.get("rounds", 500 if team_mode else 10)), seed_value, int(opts.seeds),
			int(opts.get("ai", 2 if team_mode else 1)))
		result = seeds.first
	elif mode == "team":
		result = bs.call("run_team", level, int(opts.get("rounds", 500)), seed_value, int(opts.get("ai", 2)))
	else:
		result = bs.call("run", level, int(opts.get("rounds", 10)), seed_value, [] as Array[String], int(opts.get("ai", 1)))
	var text: String = bs.call("report", result)
	text += (load("res://scripts/core/BalanceGroups.gd") as GDScript).call("report", result)
	if not seeds.is_empty():
		text += bs.call("seeds_report", seeds)
	if opts.has("compare"):
		var path: String = str(opts.compare) if str(opts.compare) != "true" else str(bs.get("BASELINE_PATH"))
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if raw is Dictionary:
			text += bs.call("compare_report", bs.call("compare", result, raw))
		else:
			text += "\nNo baseline at %s.\n" % path
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
	var diff: int = -1
	if opts.has("difficulty"):
		diff = difficulty_index(str(opts.difficulty))
		if diff < 0:
			return "Unknown difficulty %s (story, tamer, veteran, rift_born or 0-3)." % opts.difficulty
	bs.set("sim_field", field)
	bs.set("sim_variants", ids)
	bs.set("sim_difficulty", diff)
	return ""

## "story", "tamer", "veteran", "rift_born" or 0-3 as a difficulty index, -1 if neither.
static func difficulty_index(v: String) -> int:
	var names: Array[String] = ["story", "tamer", "veteran", "rift_born"]
	var key: String = v.strip_edges().to_lower().replace("-", "_")
	if key in names:
		return names.find(key)
	if key.is_valid_int() and int(key) >= 0 and int(key) < names.size():
		return int(key)
	return -1

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
