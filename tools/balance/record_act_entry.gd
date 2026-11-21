extends SceneTree
## Records tools/balance/act_entry.json: the team, rings and dice the route brings to Act II, per
## starter, for the route runs of test_act_difficulty.gd and
## `tools/balance_sim.gd --mode acts --rounds 16` (seed 1234). ActSim starts Act II from these,
## so the tutorial act does not re-roll the later acts (docs/BALANCE.md, "Ziele pro Gebiet").
##   godot --headless --path . -s res://tools/balance/record_act_entry.gd -- [trials] [seed]
## Only re-record on purpose: the file pins the reference player of the later acts.

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var trials: int = int(args[0]) if args.size() > 0 else 16
	var seed_value: int = int(args[1]) if args.size() > 1 else 1234
	var sim: GDScript = load("res://scripts/core/ActSim.gd")
	sim.set("recording", true)
	var cfg: Dictionary = sim.call("route")
	for st: Variant in cfg.starters:
		sim.call("run", str(st), trials, seed_value)
	var path: String = str(sim.get("ENTRY_PATH"))
	var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var all: Dictionary = (old as Dictionary).get("entries", {}) if old is Dictionary else {}
	var rec: Dictionary = sim.get("record_entry")
	for k: String in rec:
		all[k] = {"act2": rec[k].get("act2", {})}
	var out: Dictionary = {"_doc": "Team, rings and dice the route brings to Act II, per 'starter|trials|seed' (scripts/core/ActSim.gd, ENTRY_PATH). Recorded by tools/balance/record_act_entry.gd from the route of 2026-11-21 before Act I became the tutorial act (Ali 2026-11-21), so the tutorial act does not re-roll the acts after it. Runs with other trials or seeds carry the team on from Act I.", "entries": all}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " ", false) + "\n")
	f.close()
	print("Wrote ", path)
	quit()
