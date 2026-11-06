class_name BalanceSim
extends RefCounted
## Headless balancing: every species fights every other species 1-on-1 at the same level,
## both sides on the greedy AI (tier 1). Reports win rate per species, use and KO counts per
## move, and how long battles last. Fully seeded, so a report is reproducible.

## Battles that run longer than this count as a draw (stalls show up in the report).
const MAX_TURNS: int = 60

## Evolution stage: 1 for base forms, 2 for their evolutions, and so on. Kinds that never
## unfold (Glasstarn, Lanternel) are built like second stages and fight those.
static func stage(sd: SpirlingData) -> int:
	if sd.unfold.is_empty() and Database.earlier_form(sd) == null:
		return 2
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

## Item evolutions have no level; the sim treats them as evolving around this level.
const ITEM_EVOLVE_LEVEL: int = 25

## Level at which [param sd] evolves for the sim (its evolve level, or ITEM_EVOLVE_LEVEL), 0 if never.
static func evolve_at(sd: SpirlingData) -> int:
	if sd.evolves_to == null:
		return 0
	return sd.evolve_level if sd.evolve_level > 0 else ITEM_EVOLVE_LEVEL

## Lowest level this form can have: the evolve level of the form before it (1 for base forms).
static func min_level(sd: SpirlingData) -> int:
	for other: SpirlingData in Database.spirlings.values():
		if other.evolves_to != null and other.evolves_to.species_name == sd.species_name:
			return evolve_at(other)
	return 1

## Runs [param rounds] battles per ordered species pair of the same evolution stage at
## [param level] (a base form losing to an evolved one tells us nothing). Returns
## {"species": {name: {"wins","losses","draws","turns"}}, "moves": {name: {"used","kos"}},
##  "battles": int, "draws": int, "avg_turns": float, "level": int}.
static func run(level: int, rounds: int, seed_value: int, only: Array[String] = [], ai_level: int = 1) -> Dictionary:
	Database.load_all()
	var names: Array[String] = []
	for sd: SpirlingData in Database.spirlings.values():
		# Ancient kinds (First Voices) are meant to stand above their stage; they are met once.
		if sd.rarity == "ancient" and only.is_empty():
			continue
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
	var decided: int = 0
	var fast_wins: int = 0
	var fast_known: int = 0
	# Skip forms that can't exist yet, and forms a player would already have evolved.
	names = names.filter(func(n: String) -> bool:
		var sd: SpirlingData = Database.species(n)
		var evolved: bool = evolve_at(sd) > 0 and level >= evolve_at(sd)
		return level >= min_level(sd) and not evolved)
	# A form alone in its stage has nobody to fight; leave it out of the report.
	var per_stage: Dictionary = {}
	for n: String in names:
		var st: int = stage(Database.species(n))
		per_stage[st] = int(per_stage.get(st, 0)) + 1
	names = names.filter(func(n: String) -> bool: return int(per_stage[stage(Database.species(n))]) > 1)
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
				var res: Dictionary = fight(a, b, level, rng.randi(), moves, ai_level)
				battles += 1
				total_turns += int(res.turns)
				if int(res.winner) >= 0:
					decided += 1
					if int(res.faster) >= 0:
						fast_known += 1
						fast_wins += 1 if int(res.faster) == int(res.winner) else 0
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
		"avg_turns": float(total_turns) / maxf(battles, 1), "level": level, "mode": "duel", "ai": ai_level,
		"ko_turns": float(total_turns) / maxf(battles, 1),
		"first_advantage": float(fast_wins) / maxf(fast_known, 1)}

## One battle. Returns {"winner": 0 (a) / 1 (b) / -1 (draw), "turns": int}. Tallies moves.
## "faster" is the side whose Spirling had the higher Pace at the start (-1 on a tie).
static func fight(a: String, b: String, level: int, seed_value: int, moves: Dictionary, ai_level: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mine: Array[Spirling] = [Spirling.new(Database.species(a), level, rng)]
	var theirs: Array[Spirling] = [Spirling.new(Database.species(b), level, rng)]
	var faster: int = -1
	if mine[0].effective_spd() != theirs[0].effective_spd():
		faster = 0 if mine[0].effective_spd() > theirs[0].effective_spd() else 1
	var m := BattleModel.new(mine, theirs, false, seed_value, ai_level)
	m.items_allowed = false
	var ai := BattleAI.new(ai_level)
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
	return {"winner": winner, "turns": turns, "faster": faster}

## Species that can stand in a team at [param level]: reached by then and not yet evolved past.
static func valid_species(level: int) -> Array[String]:
	var out: Array[String] = []
	for sd: SpirlingData in Database.spirlings.values():
		# Ancient kinds (First Voices) stand above every team on purpose; they are met once.
		if sd.rarity == "ancient":
			continue
		var evolved: bool = evolve_at(sd) > 0 and level >= evolve_at(sd)
		if level >= min_level(sd) and not evolved:
			out.append(sd.species_name)
	out.sort()
	return out

## Team mode (plan area 2, item 809): [param battles] battles between random valid teams of 3 or
## 5 (no species twice in a team) at [param level], both sides on AI [param ai_level], one
## Spirling on the field at a time. Tallies per species (wins and games of the teams it was in),
## per move (used, KOs) and per element (picks). Same result for the same seed.
static func run_team(level: int, battles: int, seed_value: int, ai_level: int = 2, sizes: Array[int] = [3, 5]) -> Dictionary:
	Database.load_all()
	var pool: Array[String] = valid_species(level)
	var species: Dictionary = {}
	for n: String in pool:
		species[n] = {"wins": 0, "losses": 0, "draws": 0, "turns": 0, "stage": stage(Database.species(n))}
	var moves: Dictionary = {}
	var elements: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var draws: int = 0
	var total_turns: int = 0
	# Lambdas capture ints by value, so the counters live in a Dictionary.
	var tally: Dictionary = {"rests": 0, "actions": 0}
	for b: int in battles:
		var size: int = sizes[b % sizes.size()]
		var names: Array[Array] = [_pick(pool, size, rng), _pick(pool, size, rng)]
		var teams: Array[Array] = [[], []]
		for side: int in 2:
			for n: String in names[side]:
				teams[side].append(Spirling.new(Database.species(n), level, rng))
		var mine: Array[Spirling] = []
		mine.assign(teams[0])
		var theirs: Array[Spirling] = []
		theirs.assign(teams[1])
		var m := BattleModel.new(mine, theirs, false, rng.randi(), ai_level)
		m.items_allowed = false
		m.event_emitted.connect(func(e: BattleEvent) -> void:
			if e.type == BattleEvent.Type.MOVE_USED:
				var mv: String = str(e.data.get("move", ""))
				var t: Dictionary = moves.get(mv, {"used": 0, "kos": 0})
				t.used += 1
				moves[mv] = t
				var el: String = Elements.element_name(int(e.data.get("element", 0)))
				elements[el] = int(elements.get(el, 0)) + 1
				tally.actions += 1
			elif e.type == BattleEvent.Type.REST:
				tally.rests += 1
				tally.actions += 1)
		var brain := BattleAI.new(ai_level)
		m.start()
		var turns: int = 0
		while not m.is_finished() and turns < MAX_TURNS * 2:
			if m.needs_player_switch():
				m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot()))
				continue
			m.submit_turn(brain.choose(m, BattleModel.Side.PLAYER))
			turns += 1
		total_turns += turns
		var winner: int = -1
		if m.outcome == BattleModel.Outcome.WIN:
			winner = 0
		elif m.outcome == BattleModel.Outcome.LOSS:
			winner = 1
		if winner < 0:
			draws += 1
		for side: int in 2:
			for n: String in names[side]:
				var row: Dictionary = species[n]
				row.turns += turns
				if winner < 0:
					row.draws += 1
				elif winner == side:
					row.wins += 1
				else:
					row.losses += 1
	return {"species": species, "moves": moves, "elements": elements, "battles": battles, "draws": draws,
		"avg_turns": float(total_turns) / maxf(battles, 1), "level": level, "mode": "team", "ai": ai_level,
		"rest_share": float(tally.rests) / maxf(int(tally.actions), 1)}

static func _pick(pool: Array[String], size: int, rng: RandomNumberGenerator) -> Array[String]:
	var left: Array[String] = pool.duplicate()
	var out: Array[String] = []
	while out.size() < mini(size, pool.size()):
		out.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return out

## Every number of a result as plain data (plan item 815): tests and comparisons read this
## instead of parsing the Markdown report. Win rates are added per species.
static func to_json(result: Dictionary) -> String:
	var out: Dictionary = result.duplicate(true)
	for n: String in out.species:
		out.species[n]["win_rate"] = snappedf(win_rate(out.species[n]), 0.001)
	return JSON.stringify(out, " ", true)

static func win_rate(row: Dictionary) -> float:
	var games: int = int(row.wins) + int(row.losses) + int(row.draws)
	return float(row.wins) / maxf(games, 1)

## Target bands the report checks (docs/BALANCE.md, "Zielbänder").
const KO_TURNS_BAND: Vector2 = Vector2(2.5, 4.0)
const FIRST_ADVANTAGE_MAX: float = 0.62

## Markdown report. Species above [param high] or below [param low] win rate are flagged.
static func report(result: Dictionary, high: float = 0.65, low: float = 0.35) -> String:
	var team: bool = str(result.get("mode", "duel")) == "team"
	var how: String = "random teams of 3 and 5, both sides AI tier %d" % int(result.get("ai", 2)) if team \
		else "1-on-1 within the same evolution stage, both sides AI tier %d, no items" % int(result.get("ai", 1))
	var lines: PackedStringArray = [
		"# Balance report",
		"",
		"Level %d, %d battles (%s), %d draws, %.1f turns on average." % [result.level, result.battles, how, result.draws, result.avg_turns],
		"Generated by `tools/balance_sim.gd`; numbers are reproducible for the same seed.",
		"",
	]
	if result.has("first_advantage"):
		var ko: float = float(result.ko_turns)
		var fa: float = float(result.first_advantage)
		lines.append("Turns to KO: %.1f%s." % [ko, "" if ko >= KO_TURNS_BAND.x and ko <= KO_TURNS_BAND.y else " (outside the target band %.1f to %.1f)" % [KO_TURNS_BAND.x, KO_TURNS_BAND.y]])
		lines.append("First-mover advantage (the faster Spirling wins): %d%%%s." % [roundi(fa * 100.0), "" if fa <= FIRST_ADVANTAGE_MAX else " (above the target %d%%)" % roundi(FIRST_ADVANTAGE_MAX * 100.0)])
		lines.append("")
	if result.has("rest_share"):
		lines.append("Rest share of all actions: %d%%." % roundi(float(result.rest_share) * 100.0))
		lines.append("")
	if result.has("elements"):
		lines.append_array(["## Elements", "", "| Element | Picks |", "| --- | --- |"])
		var el: Dictionary = result.elements
		var enames: Array = el.keys()
		enames.sort()
		for e: String in enames:
			lines.append("| %s | %d |" % [e, el[e]])
		lines.append("")
	lines.append_array([
		"## Species",
		"",
		"| Species | Stage | Win rate | W | L | D | Flag |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	])
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

const REF_TEAMS_PATH: String = "res://tools/balance/ref_teams.json"
const TARGETS_PATH: String = "res://tools/balance/targets.json"

static func _read_json(path: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return raw if raw is Dictionary else {}

## Win-rate bands per difficulty key (tools/balance/targets.json, item 733): {"story": Vector2(lo, hi), ...}.
static func warden_targets() -> Dictionary:
	var out: Dictionary = {}
	var w: Variant = _read_json(TARGETS_PATH).get("warden", {})
	if w is Dictionary:
		for k: String in w:
			out[k] = Vector2(float(w[k][0]), float(w[k][1]))
	return out

## Warden mode (plan area 2, items 810 to 812): every reference team of tools/balance/ref_teams.json
## fights every Warden of its story section [param rounds] times per difficulty, the Warden with the
## team, AI tier, personality, rule and damage share of that difficulty. The reference side plays on
## AI [param player_ai] without items. Returns {"rows": [{"section","team","warden","difficulty",
## "wins","losses","draws","win_rate"}], "mode": "warden", "rounds", "ai"}. Same result for the same seed.
static func run_warden(rounds: int, seed_value: int, player_ai: int = 2, difficulties: Array[int] = [], sections: Array[String] = []) -> Dictionary:
	Database.load_all()
	var cfg: Dictionary = _read_json(REF_TEAMS_PATH)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var diffs: Array[int] = difficulties.duplicate()
	if diffs.is_empty():
		for d: int in TrainerData.DIFFICULTY_KEYS.size():
			diffs.append(d)
	var rows: Array[Dictionary] = []
	var secs: Dictionary = cfg.get("sections", {})
	for sec: String in secs:
		if not sections.is_empty() and not sec in sections:
			continue
		var sd: Dictionary = secs[sec]
		for pair: Array in sd.get("wardens", []):
			var map: MapData = MapData.load_map(str(pair[0]))
			var def: Dictionary = {}
			for n: Dictionary in map.npcs:
				if str(n.get("id", "")) == str(pair[1]):
					def = n
			if def.is_empty():
				push_error("BalanceSim: no Warden %s on %s" % [pair[1], pair[0]])
				continue
			for team_id: String in sd.get("teams", {}):
				var entries: Array = sd.teams[team_id]
				for d: int in diffs:
					var row: Dictionary = {"section": sec, "team": team_id, "warden": str(pair[1]),
						"difficulty": TrainerData.DIFFICULTY_KEYS[d], "wins": 0, "losses": 0, "draws": 0, "turns": 0}
					for r: int in rounds:
						var res: Dictionary = warden_fight(entries, def, map.field, d, int(sd.get("cap", Spirling.MAX_LEVEL)), bool(sd.get("rematch", false)), rng.randi(), player_ai)
						row.turns += int(res.turns)
						match int(res.winner):
							0: row.wins += 1
							1: row.losses += 1
							_: row.draws += 1
					row["win_rate"] = float(row.wins) / maxf(rounds, 1)
					rows.append(row)
	return {"rows": rows, "mode": "warden", "rounds": rounds, "ai": player_ai}

## One reference team against one Warden on [param difficulty]. [param cap] is the story level cap
## of the section (binding from Veteran up); with [param rematch] the Warden brings the rematch team.
static func warden_fight(entries: Array, def: Dictionary, field: String, difficulty: int, cap: int, rematch: bool, seed_value: int, player_ai: int = 2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mine: Array[Spirling] = []
	var top: int = 0
	for e: Dictionary in entries:
		var s := Spirling.new(Database.species(str(e.species)), int(e.level), rng)
		mine.append(s)
		top = maxi(top, s.level)
	var ring_cap: int = cap if difficulty >= GameState.Difficulty.VETERAN else Spirling.MAX_LEVEL
	var foes: Array[Spirling] = TrainerData.rematch_team(def, "", rng, top, ring_cap, difficulty) if rematch \
		else TrainerData.build_team(def, "", rng, difficulty, ring_cap)
	var info: Dictionary = TrainerData.battle_info(def, foes, GameState.AI_LEVELS[difficulty], difficulty)
	var m := BattleModel.new(mine, foes, false, seed_value, int(info.ai))
	m.items_allowed = false
	m.ai.set_profile(str(info.profile), info.profile_tune)
	m.foe_damage_mult = GameState.FOE_DAMAGE[difficulty]
	m.field = field
	m.foe_rule = str(info.rule)
	m.rule_turn_full = difficulty >= GameState.Difficulty.VETERAN
	var items: Variant = info.get("items", {})
	m.foe_items = (items as Dictionary).duplicate() if items is Dictionary else {}
	m.foe_boss = str(info.boss)
	var brain := BattleAI.new(player_ai)
	m.start()
	var turns: int = 0
	while not m.is_finished() and turns < MAX_TURNS * 2:
		if m.needs_player_switch():
			m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot()))
			continue
		m.submit_turn(brain.choose(m, BattleModel.Side.PLAYER))
		turns += 1
	var winner: int = -1
	if m.outcome == BattleModel.Outcome.WIN:
		winner = 0
	elif m.outcome == BattleModel.Outcome.LOSS:
		winner = 1
	return {"winner": winner, "turns": turns}

## Markdown report of a warden run: one line per team, Warden and difficulty, flagged outside the band.
static func warden_report(result: Dictionary) -> String:
	var bands: Dictionary = warden_targets()
	var lines: PackedStringArray = ["# Warden report", "",
		"%d battles per team, Warden and difficulty; the reference side plays AI tier %d without items." % [int(result.rounds), int(result.ai)],
		"Generated by `tools/balance_sim.gd --mode warden`; bands from tools/balance/targets.json.", "",
		"| Section | Team | Warden | Difficulty | Win rate | Band | Flag |", "| --- | --- | --- | --- | --- | --- | --- |"]
	for row: Dictionary in result.rows:
		var band: Vector2 = bands.get(row.difficulty, Vector2(0, 1))
		var wr: float = float(row.win_rate)
		var flag: String = "too hard" if wr < band.x else ("too easy" if wr > band.y else "")
		lines.append("| %s | %s | %s | %s | %d%% | %d-%d%% | %s |" % [row.section, row.team, row.warden, row.difficulty,
			roundi(wr * 100.0), roundi(band.x * 100.0), roundi(band.y * 100.0), flag])
	return "\n".join(lines) + "\n"
