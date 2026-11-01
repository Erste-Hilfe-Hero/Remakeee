class_name BalanceSim
extends RefCounted
## Headless balancing: every species fights every other species 1-on-1 at the same level,
## both sides on the greedy AI (tier 1). Reports win rate per species, use and KO counts per
## move, and how long battles last. Fully seeded, so a report is reproducible.

## Battles that run longer than this count as a draw (stalls show up in the report).
const MAX_TURNS: int = 60

## Evolution stage: 1 for base forms, 2 for their evolutions, and so on.
static func stage(sd: SpirlingData) -> int:
	var st: int = 1
	var cur: SpirlingData = sd
	var guard: int = 0
	while guard < 8:
		guard += 1
		var prev: SpirlingData = null
		for other: SpirlingData in Database.spirlings.values():
			if other.evolves_to != null and other.evolves_to.species_name == cur.species_name:
				prev = other
		if prev == null:
			break
		st += 1
		cur = prev
	return st

## Lowest level this form can have: the evolve level of the form before it (1 for base forms).
static func min_level(sd: SpirlingData) -> int:
	for other: SpirlingData in Database.spirlings.values():
		if other.evolves_to != null and other.evolves_to.species_name == sd.species_name:
			return other.evolve_level
	return 1

## Runs [param rounds] battles per ordered species pair of the same evolution stage at
## [param level] (a base form losing to an evolved one tells us nothing). Returns
## {"species": {name: {"wins","losses","draws","turns"}}, "moves": {name: {"used","kos"}},
##  "battles": int, "draws": int, "avg_turns": float, "level": int}.
static func run(level: int, rounds: int, seed_value: int, only: Array[String] = []) -> Dictionary:
	Database.load_all()
	var names: Array[String] = []
	for sd: SpirlingData in Database.spirlings.values():
		if only.is_empty() or sd.species_name in only:
			names.append(sd.species_name)
	names.sort()
	var species: Dictionary = {}
	var moves: Dictionary = {}
	for n: String in names:
		species[n] = {"wins": 0, "losses": 0, "draws": 0, "turns": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var battles: int = 0
	var draws: int = 0
	var total_turns: int = 0
	# Skip forms that can't exist yet at this level (e.g. a stage-3 form at Lv8).
	# Skip forms that can't exist yet, and forms a player would already have evolved.
	names = names.filter(func(n: String) -> bool:
		var sd: SpirlingData = Database.species(n)
		var evolved: bool = sd.evolves_to != null and sd.evolve_level > 0 and level >= sd.evolve_level
		return level >= min_level(sd) and not evolved)
	for n: String in species.keys():
		if not n in names:
			species.erase(n)
	var stages: Dictionary = {}
	for n: String in names:
		stages[n] = stage(Database.species(n))
		species[n]["stage"] = stages[n]
	for a: String in names:
		for b: String in names:
			if a == b or stages[a] != stages[b]:
				continue
			for r: int in rounds:
				var res: Dictionary = fight(a, b, level, rng.randi(), moves)
				battles += 1
				total_turns += int(res.turns)
				species[a].turns += int(res.turns)
				species[b].turns += int(res.turns)
				match int(res.winner):
					0:
						species[a].wins += 1
						species[b].losses += 1
					1:
						species[b].wins += 1
						species[a].losses += 1
					_:
						draws += 1
						species[a].draws += 1
						species[b].draws += 1
	return {"species": species, "moves": moves, "battles": battles, "draws": draws,
		"avg_turns": float(total_turns) / maxf(battles, 1), "level": level}

## One battle. Returns {"winner": 0 (a) / 1 (b) / -1 (draw), "turns": int}. Tallies moves.
static func fight(a: String, b: String, level: int, seed_value: int, moves: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mine: Array[Spirling] = [Spirling.new(Database.species(a), level, rng)]
	var theirs: Array[Spirling] = [Spirling.new(Database.species(b), level, rng)]
	var m := BattleModel.new(mine, theirs, false, seed_value, 1)
	m.items_allowed = false
	var ai := BattleAI.new(1)
	var last_move: Array[String] = ["", ""]
	m.event_emitted.connect(func(e: BattleEvent) -> void:
		var side: int = int(e.data.get("side", 0))
		if e.type == BattleEvent.Type.MOVE_USED:
			var mv: String = str(e.data.get("move", ""))
			last_move[side] = mv
			var t: Dictionary = moves.get(mv, {"used": 0, "kos": 0})
			t.used += 1
			moves[mv] = t
		elif e.type == BattleEvent.Type.FAINTED:
			var killer: String = last_move[BattleModel.other(side)]
			if moves.has(killer):
				moves[killer].kos += 1)
	m.start()
	var turns: int = 0
	while not m.is_finished() and turns < MAX_TURNS:
		m.submit_turn(ai.choose(m, BattleModel.Side.PLAYER))
		turns += 1
	var winner: int = -1
	if m.outcome == BattleModel.Outcome.WIN:
		winner = 0
	elif m.outcome == BattleModel.Outcome.LOSS:
		winner = 1
	return {"winner": winner, "turns": turns}

static func win_rate(row: Dictionary) -> float:
	var games: int = int(row.wins) + int(row.losses) + int(row.draws)
	return float(row.wins) / maxf(games, 1)

## Markdown report. Species above [param high] or below [param low] win rate are flagged.
static func report(result: Dictionary, high: float = 0.65, low: float = 0.35) -> String:
	var lines: PackedStringArray = [
		"# Balance report",
		"",
		"Level %d, %d battles (1-on-1 within the same evolution stage, both sides greedy AI, no items), %d draws, %.1f turns on average." % [result.level, result.battles, result.draws, result.avg_turns],
		"Generated by `tools/balance_sim.gd`; numbers are reproducible for the same seed.",
		"",
		"## Species",
		"",
		"| Species | Stage | Win rate | W | L | D | Flag |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	]
	var sp: Dictionary = result.species
	var names: Array = sp.keys()
	names.sort_custom(func(x: String, y: String) -> bool:
		if int(sp[x].stage) != int(sp[y].stage):
			return int(sp[x].stage) < int(sp[y].stage)
		return win_rate(sp[x]) > win_rate(sp[y]))
	for n: String in names:
		var row: Dictionary = sp[n]
		var wr: float = win_rate(row)
		var flag: String = "too strong" if wr > high else ("too weak" if wr < low else "")
		lines.append("| %s | %d | %d%% | %d | %d | %d | %s |" % [n, row.stage, int(round(wr * 100.0)), row.wins, row.losses, row.draws, flag])
	lines.append_array(["", "## Moves", "", "| Move | Used | KOs | KO per use |", "| --- | --- | --- | --- |"])
	var mv: Dictionary = result.moves
	var mnames: Array = mv.keys()
	mnames.sort_custom(func(x: String, y: String) -> bool: return int(mv[x].used) > int(mv[y].used))
	for n: String in mnames:
		var used: int = int(mv[n].used)
		lines.append("| %s | %d | %d | %.2f |" % [n, used, mv[n].kos, float(mv[n].kos) / maxf(used, 1)])
	var all_moves: Array[String] = []
	for k: Variant in Database.moves.keys():
		if not mv.has(str(k)):
			all_moves.append(str(k))
	if not all_moves.is_empty():
		all_moves.sort()
		lines.append_array(["", "Never picked at this level: " + ", ".join(all_moves) + "."])
	return "\n".join(lines) + "\n"
