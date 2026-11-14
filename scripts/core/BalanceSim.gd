class_name BalanceSim
extends RefCounted
## Headless balancing: every species fights every other species 1-on-1 at the same level,
## both sides on the greedy AI (tier 1). Reports win rate per species, use and KO counts per
## move, and how long battles last. Fully seeded, so a report is reproducible.

## Battles that run longer than this count as a draw (stalls show up in the report).
const MAX_TURNS: int = 60

## Field and rule variants every duel, team, ladder and mono battle is played under (item 821,
## switches --field and --variant); empty for the normal rules.
static var sim_field: String = ""
static var sim_variants: Array[String] = []

## Difficulty the foe side (side 1) is tuned to, as in the game (item 822, switch --difficulty);
## -1 leaves both sides even.
static var sim_difficulty: int = -1

## [param tune_ai] false keeps the AI tiers a mode set itself (ladder).
static func _apply_switches(m: BattleModel, tune_ai: bool = true) -> void:
	if not sim_field.is_empty():
		m.field = sim_field
	m.variants = sim_variants.duplicate()
	if sim_difficulty >= 0:
		tune_foes(m, sim_difficulty, tune_ai)

## Tunes [param m]'s foe side to [param difficulty] the way a Wayfarer battle is (item 822):
## GameState.FOE_SPARK in every stat, the ring shift of a shared team, the AI tier with its
## difficulty flags, the foe damage factor and the start and turn-one Energy. Random sim teams
## carry no listed keepsakes, so there are none to drop below Veteran.
static func tune_foes(m: BattleModel, difficulty: int, tune_ai: bool = true) -> void:
	var d: int = clampi(difficulty, 0, GameState.AI_LEVELS.size() - 1)
	for s: Spirling in m.parties[BattleModel.Side.FOE]:
		s.level = clampi(s.level + GameState.FOE_LEVEL_SHIFT[d], 1, Spirling.STORY_RING)
		for key: String in Spirling.STAT_KEYS:
			s.spark[key] = GameState.FOE_SPARK[d]
		if not TrainerData.keeps_keepsakes(d):
			s.held = ""
		s.hp = s.max_hp()
	if tune_ai:
		m.ai.level = TrainerData.ai_tier({}, GameState.AI_LEVELS[d], d)
	m.ai.set_difficulty(d)
	m.foe_damage_mult = GameState.FOE_DAMAGE[d]
	m.start_energy_cut = [0, BattleRules.foe_start_cut(d)]
	m.foe_turn1_energy = BattleRules.foe_turn1_energy(d)

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
	var double_kos: int = 0
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
						if bool(res.double_ko):
							double_kos += 1
						else:
							draws += 1
						species[a].draws += 1
						species[b].draws += 1
	return {"species": species, "moves": moves, "battles": battles, "draws": draws, "double_kos": double_kos,
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
	_apply_switches(m)
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
	var winner: int = sim_winner(m)
	return {"winner": winner, "turns": turns, "faster": faster, "double_ko": winner < 0 and m.is_finished()}

## Winner of a finished sim battle: 0 player side, 1 foe side, -1 draw. A double KO (both sides
## out at once, e.g. two delayed hits landing together) is a draw here, although the game hands
## it to the player: in the even sim modes that tiebreak alone would favour side 0 (item 831).
static func sim_winner(m: BattleModel) -> int:
	if m.outcome == BattleModel.Outcome.WIN:
		return -1 if m.own_alive_count() == 0 else 0
	if m.outcome == BattleModel.Outcome.LOSS:
		return 1
	return -1

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
	var double_kos: int = 0
	var total_turns: int = 0
	# Lambdas capture ints by value, so the counters live in a Dictionary.
	var tally: Dictionary = {"rests": 0, "actions": 0, "arts": 0, "spent": 0}
	var fx: Dictionary = new_effects()
	# Arts used per side in the current battle, booked as wins once the winner is known (item 816).
	var uses: Array[Dictionary] = [{}, {}]
	for b: int in battles:
		uses[0].clear()
		uses[1].clear()
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
		_apply_switches(m)
		m.event_emitted.connect(func(e: BattleEvent) -> void:
			if e.type == BattleEvent.Type.MOVE_USED:
				var mv: String = str(e.data.get("move", ""))
				var t: Dictionary = moves.get(mv, {"used": 0, "kos": 0, "win_uses": 0})
				t.used += 1
				moves[mv] = t
				var us: Dictionary = uses[clampi(int(e.data.get("side", 0)), 0, 1)]
				us[mv] = int(us.get(mv, 0)) + 1
				var el: String = Elements.element_name(int(e.data.get("element", 0)))
				elements[el] = int(elements.get(el, 0)) + 1
				tally.actions += 1
				# Energy the art costs on its own (KAMPF_PLAN items 61, 80).
				var paid: MoveData = Database.move(mv)
				if paid != null:
					tally.arts += 1
					tally.spent += paid.energy_cost
			elif e.type == BattleEvent.Type.REST:
				tally.rests += 1
				tally.actions += 1)
		watch_effects(m, fx)
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
		close_effects(m, fx)
		var winner: int = sim_winner(m)
		if winner < 0:
			if m.is_finished():
				double_kos += 1
			else:
				draws += 1
		else:
			for mv: String in uses[winner]:
				moves[mv].win_uses += int(uses[winner][mv])
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
	return {"species": species, "moves": moves, "elements": elements, "battles": battles, "draws": draws, "double_kos": double_kos,
		"avg_turns": float(total_turns) / maxf(battles, 1), "level": level, "mode": "team", "ai": ai_level,
		"rest_share": float(tally.rests) / maxf(int(tally.actions), 1),
		"energy_per_art": float(tally.spent) / maxf(int(tally.arts), 1),
		"status_hits": fx.hits, "status_turns": fx.lasts, "reactions": fx.reactions}

# --- Status and reaction tallies (plan area 2, items 825, 826) ------------------------------

## Target band of the rest share in team mode (item 823).
const REST_BAND: Vector2 = Vector2(0.10, 0.25)
## Target band of the mean Energy cost of the arts picked in team mode (KAMPF_PLAN item 61): below
## it only cheap arts are worth it, above it Rest crowds out play.
const ENERGY_PER_ART_BAND: Vector2 = Vector2(1.5, 4.0)

## Empty tallies: hits {art: {tries, landed}}, lasts {status: {count, turns}},
## reactions {"Volt on soak": count}, open {"side:index": [status, turn]} (statuses still on).
static func new_effects() -> Dictionary:
	return {"hits": {}, "lasts": {}, "reactions": {}, "open": {}, "last": ["", ""]}

## Counts, for one battle of [param m], the tries and hits of every status art (the status lands
## on the foe after the art), how many turns each status holds and every reaction.
static func watch_effects(m: BattleModel, fx: Dictionary) -> void:
	fx.open = {}
	fx.last = ["", ""]
	m.event_emitted.connect(func(e: BattleEvent) -> void: _on_effect(e, m, fx))

static func _on_effect(e: BattleEvent, m: BattleModel, fx: Dictionary) -> void:
		var side: int = clampi(int(e.data.get("side", 0)), 0, 1)
		var key: String = "%d:%d" % [side, int(e.data.get("index", -1))]
		match e.type:
			BattleEvent.Type.MOVE_USED:
				var name: String = str(e.data.get("move", ""))
				var mv: MoveData = Database.move(name)
				fx.last[side] = ""
				if mv != null and not mv.status_effect.is_empty() and mv.status_chance > 0.0:
					fx.last[side] = name
					var row: Dictionary = fx.hits.get(name, {"tries": 0, "landed": 0})
					row.tries += 1
					fx.hits[name] = row
			BattleEvent.Type.STATUS_APPLIED:
				var by: String = str(fx.last[BattleModel.other(side)])
				if not by.is_empty():
					fx.hits[by].landed += 1
					fx.last[BattleModel.other(side)] = ""
				fx.open[key] = [str(e.data.get("status", "")), m.turn]
			BattleEvent.Type.STATUS_CURED, BattleEvent.Type.FAINTED:
				_close_status(fx, key, m.turn)
			BattleEvent.Type.REACTION:
				var r: String = "%s on %s" % [Elements.element_name(int(e.data.get("element", 0))), str(e.data.get("status", ""))]
				fx.reactions[r] = int(fx.reactions.get(r, 0)) + 1

## Books every status still on when the battle of [param m] ends.
static func close_effects(m: BattleModel, fx: Dictionary) -> void:
	for key: String in (fx.open as Dictionary).keys():
		_close_status(fx, key, m.turn)

static func _close_status(fx: Dictionary, key: String, turn: int) -> void:
	if not (fx.open as Dictionary).has(key):
		return
	var on: Array = fx.open[key]
	fx.open.erase(key)
	var row: Dictionary = fx.lasts.get(str(on[0]), {"count": 0, "turns": 0})
	row.count += 1
	row.turns += maxi(1, turn - int(on[1]))
	fx.lasts[str(on[0])] = row

## The Energy line of a team report (KAMPF_PLAN items 61, 80), flagged outside ENERGY_PER_ART_BAND.
static func energy_line(per_art: float) -> String:
	var inside: bool = per_art >= ENERGY_PER_ART_BAND.x and per_art <= ENERGY_PER_ART_BAND.y
	return "Energy per art picked: %.1f%s." % [per_art, "" if inside else " (outside the target band %.1f to %.1f)" % [ENERGY_PER_ART_BAND.x, ENERGY_PER_ART_BAND.y]]

## The status, reaction and rest sections of a team report (items 823, 825, 826).
static func effects_report(result: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var rs: float = float(result.get("rest_share", 0.0))
	var hits: Dictionary = result.get("status_hits", {})
	if not hits.is_empty():
		lines.append_array(["## Status arts", "", "| Art | Tries | Landed | Hit share |", "| --- | --- | --- | --- |"])
		var names: Array = hits.keys()
		names.sort()
		for n: String in names:
			var row: Dictionary = hits[n]
			lines.append("| %s | %d | %d | %d%% |" % [n, row.tries, row.landed, roundi(100.0 * float(row.landed) / maxf(float(row.tries), 1.0))])
		lines.append("")
	var lasts: Dictionary = result.get("status_turns", {})
	if not lasts.is_empty():
		lines.append_array(["## Status length", "", "| Status | Times | Turns on average |", "| --- | --- | --- |"])
		var sn: Array = lasts.keys()
		sn.sort()
		for n: String in sn:
			lines.append("| %s | %d | %.1f |" % [n, lasts[n].count, float(lasts[n].turns) / maxf(float(lasts[n].count), 1.0)])
		lines.append("")
	var reac: Dictionary = result.get("reactions", {})
	if result.has("reactions"):
		lines.append_array(["## Reactions", "", "| Reaction | Count | Per 100 battles |", "| --- | --- | --- |"])
		var rn: Array = reac.keys()
		rn.sort()
		for n: String in rn:
			lines.append("| %s | %d | %.1f |" % [n, reac[n], 100.0 * float(reac[n]) / maxf(float(result.battles), 1.0)])
		if rn.is_empty():
			lines.append("| none | 0 | 0.0 |")
		lines.append("")
	return lines

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
	if int(result.get("double_kos", 0)) > 0:
		lines.insert(lines.size() - 1, "Double KOs (both sides out at once, counted as draws for the species): %d." % int(result.double_kos))
	if result.has("first_advantage"):
		var ko: float = float(result.ko_turns)
		var fa: float = float(result.first_advantage)
		lines.append("Turns to KO: %.1f%s." % [ko, "" if ko >= KO_TURNS_BAND.x and ko <= KO_TURNS_BAND.y else " (outside the target band %.1f to %.1f)" % [KO_TURNS_BAND.x, KO_TURNS_BAND.y]])
		lines.append("First-mover advantage (the faster Spirling wins): %d%%%s." % [roundi(fa * 100.0), "" if fa <= FIRST_ADVANTAGE_MAX else " (above the target %d%%)" % roundi(FIRST_ADVANTAGE_MAX * 100.0)])
		lines.append("")
	if result.has("rest_share"):
		var rs: float = float(result.rest_share)
		lines.append("Rest share of all actions: %d%%%s." % [roundi(rs * 100.0), "" if rs >= REST_BAND.x and rs <= REST_BAND.y
			else " (outside the target band %d%% to %d%%)" % [roundi(REST_BAND.x * 100.0), roundi(REST_BAND.y * 100.0)]])
		lines.append("")
	if result.has("energy_per_art"):
		lines.append(energy_line(float(result.energy_per_art)))
		lines.append("")
	lines.append_array(effects_report(result))
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
	if team:
		lines.append_array(rare_arts_report(result))
	return "\n".join(lines) + "\n"

const REF_TEAMS_PATH: String = "res://tools/balance/ref_teams.json"
const GOAL_TEAMS_PATH: String = "res://tools/balance/goal_teams.json"
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
						var res: Dictionary = warden_fight(entries, def, map.field, d, int(sd.get("cap", Spirling.STORY_RING)), bool(sd.get("rematch", false)), rng.randi(), player_ai)
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
	var ring_cap: int = cap if difficulty >= GameState.Difficulty.VETERAN else Spirling.STORY_RING
	var foes: Array[Spirling] = TrainerData.rematch_team(def, "", rng, top, ring_cap, difficulty) if rematch \
		else TrainerData.build_team(def, "", rng, difficulty, ring_cap)
	var info: Dictionary = TrainerData.battle_info(def, foes, GameState.AI_LEVELS[difficulty], difficulty)
	var m := BattleModel.new(mine, foes, false, seed_value, int(info.ai))
	m.items_allowed = false
	m.ai.set_profile(str(info.profile), info.profile_tune)
	m.ai.set_difficulty(difficulty)
	m.start_energy_cut = [0, BattleRules.foe_start_cut(difficulty)]
	m.foe_turn1_energy = BattleRules.foe_turn1_energy(difficulty)
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

## Bonus goal check (plan area 2, item 768): one battle of a reference team against the Wayfarer
## [param def] on [param map_id], set up as in the game (front, ally, boss, rule, difficulty), with
## the goal tracker watching. Returns {"winner", "met", "turns"}.
static func goal_fight(map_id: String, def: Dictionary, entries: Array, difficulty: int, seed_value: int, player_ai: int = 2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mine: Array[Spirling] = []
	for e: Dictionary in entries:
		var s := Spirling.new(Database.species(str(e.species)), int(e.level), rng)
		var fixed: Array[MoveData] = []
		for n: Variant in e.get("moves", []):
			var mv: MoveData = Database.move(str(n))
			if mv != null:
				fixed.append(mv)
		# Named arts come first; the rest of the four are filled from the default kit (as for foes),
		# unless "kit_only" keeps the Spirling to its named arts.
		if not fixed.is_empty() and bool(e.get("kit_only", false)):
			s.moves = fixed
		elif not fixed.is_empty():
			for mv: MoveData in s.moves:
				if fixed.size() < 4 and not fixed.has(mv):
					fixed.append(mv)
			s.moves = fixed
		mine.append(s)
	var map: MapData = MapData.load_map(map_id)
	var foes: Array[Spirling] = TrainerData.build_team(def, "", rng, difficulty)
	var info: Dictionary = TrainerData.battle_info(def, foes, GameState.AI_LEVELS[difficulty], difficulty)
	var m := BattleModel.new(mine, foes, false, seed_value, int(info.ai))
	m.items_allowed = false
	m.ai.set_profile(str(info.profile), info.profile_tune)
	m.ai.set_difficulty(difficulty)
	m.start_energy_cut = [0, BattleRules.foe_start_cut(difficulty)]
	m.foe_turn1_energy = BattleRules.foe_turn1_energy(difficulty)
	m.foe_damage_mult = GameState.FOE_DAMAGE[difficulty]
	m.boss_hp_scale = GameState.BOSS_HP_SCALE[difficulty]
	m.boss_difficulty = difficulty
	m.field = str(def.get("field", map.field))
	m.foe_rule = str(info.rule)
	m.rule_turn_full = difficulty >= GameState.Difficulty.VETERAN
	var items: Variant = info.get("items", {})
	m.foe_items = (items as Dictionary).duplicate() if items is Dictionary else {}
	var front: Array = info.get("front", [1, 1])
	m.front_size = [int(front[0]), int(front[1])]
	m.foe_boss = str(info.boss)
	var partner: Variant = info.get("partner", {})
	if partner is Dictionary and not (partner as Dictionary).is_empty():
		var ally: Array[Spirling] = TrainerData.build_team(partner, "", rng)
		m.set_partner(str(partner.get("name", "")), ally, int(partner.get("front", 1)),
			int(partner.get("ai", TrainerData.PARTNER_AI)), str(partner.get("profile", "")))
	var tracker := BattleGoals.Tracker.new(m, BattleGoals.goal_for(map_id, str(def.get("id", ""))))
	var brain := BattleAI.new(player_ai)
	m.start()
	var turns: int = 0
	while not m.is_finished() and turns < MAX_TURNS * 2:
		if m.needs_player_switch():
			m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot()))
			continue
		var acts: Array[BattleAction] = []
		for slot: int in m.player_slots():
			acts.append(brain.choose(m, BattleModel.Side.PLAYER, slot))
		m.submit_actions(acts)
		turns += 1
	var winner: int = -1
	if m.outcome == BattleModel.Outcome.WIN:
		winner = 0
	elif m.outcome == BattleModel.Outcome.LOSS:
		winner = 1
	return {"winner": winner, "met": tracker.met(), "turns": turns}

## Share of [param rounds] battles in which the reference team of tools/balance/goal_teams.json
## meets the bonus goal [param key] ("map/npc") on [param difficulty].
static func goal_rate(key: String, rounds: int, seed_value: int, difficulty: int = GameState.Difficulty.TAMER) -> float:
	var teams: Dictionary = _read_json(GOAL_TEAMS_PATH).get("teams", {})
	var map_id: String = key.get_slice("/", 0)
	var def: Dictionary = {}
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == key.get_slice("/", 1):
			def = n
	if def.is_empty() or not teams.has(key):
		return 0.0
	var met: int = 0
	for r: int in rounds:
		if bool(goal_fight(map_id, def, teams[key], difficulty, seed_value + r * 7919).met):
			met += 1
	return float(met) / float(maxi(rounds, 1))

# --- Ladder, mono and goals modes (plan area 2, items 817, 818, 820) --------------------------

## Target share of wins for AI tier n against tier n-1 (item 817), by n.
const LADDER_TARGETS: Dictionary = {1: 0.75, 2: 0.6, 3: 0.55}
## Target band of every element in mono mode (item 818).
const MONO_BAND: Vector2 = Vector2(0.42, 0.58)

## One battle of two built teams, each side on its own AI tier; one Spirling on the field.
## Returns the winning side (0 player, 1 foe, -1 draw) and the turns.
static func team_battle(mine: Array[Spirling], theirs: Array[Spirling], seed_value: int, player_ai: int, foe_ai: int, tune_ai: bool = true) -> Dictionary:
	var m := BattleModel.new(mine, theirs, false, seed_value, foe_ai)
	m.items_allowed = false
	_apply_switches(m, tune_ai)
	var brain := BattleAI.new(player_ai)
	m.start()
	var turns: int = 0
	while not m.is_finished() and turns < MAX_TURNS * 2:
		if m.needs_player_switch():
			m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot()))
			continue
		m.submit_turn(brain.choose(m, BattleModel.Side.PLAYER))
		turns += 1
	var winner: int = sim_winner(m)
	return {"winner": winner, "turns": turns}

static func _build(names: Array[String], level: int, rng: RandomNumberGenerator) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for n: String in names:
		out.append(Spirling.new(Database.species(n), level, rng))
	return out

## Ladder mode (item 817): the same two random teams of 3, AI tier n against n-1 for n = 1..3.
## The sides swap every battle, so neither tier keeps the player side. Draws count as half.
static func run_ladder(level: int, battles: int, seed_value: int) -> Dictionary:
	Database.load_all()
	var pool: Array[String] = valid_species(level)
	var rows: Dictionary = {}
	for n: int in LADDER_TARGETS:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, n])
		var wins: float = 0.0
		for b: int in battles:
			var names: Array[Array] = [_pick(pool, 3, rng), _pick(pool, 3, rng)]
			var bseed: int = rng.randi()
			var high_side: int = b % 2
			var teams: Array[Array] = [_build(names[0], level, rng), _build(names[1], level, rng)]
			var mine: Array[Spirling] = []
			mine.assign(teams[0])
			var theirs: Array[Spirling] = []
			theirs.assign(teams[1])
			var r: Dictionary = team_battle(mine, theirs, bseed, n if high_side == 0 else n - 1, n - 1 if high_side == 0 else n, false)
			if int(r.winner) == high_side:
				wins += 1.0
			elif int(r.winner) < 0:
				wins += 0.5
		var rate: float = wins / float(maxi(battles, 1))
		rows[str(n)] = {"tier": n, "rate": snappedf(rate, 0.001), "target": LADDER_TARGETS[n], "ok": rate >= float(LADDER_TARGETS[n])}
	return {"mode": "ladder", "level": level, "battles": battles, "tiers": rows}

static func ladder_report(result: Dictionary) -> String:
	var lines: PackedStringArray = ["# Ladder report", "",
		"Level %d, %d battles per tier, same random teams of 3, sides swap every battle." % [result.level, result.battles], "",
		"| Tier | Against | Win rate | Target | Flag |", "| --- | --- | --- | --- | --- |"]
	for k: String in result.tiers:
		var row: Dictionary = result.tiers[k]
		lines.append("| %d | %d | %d%% | %d%% | %s |" % [row.tier, int(row.tier) - 1, roundi(float(row.rate) * 100.0),
			roundi(float(row.target) * 100.0), "" if bool(row.ok) else "below target"])
	return "\n".join(lines) + "\n"

## Valid species of [param level] per element (an element counts if the species has it).
static func mono_pools(level: int) -> Dictionary:
	var out: Dictionary = {}
	for n: String in valid_species(level):
		for e: int in Database.species(n).elements:
			var key: String = Elements.element_name(e)
			if not out.has(key):
				out[key] = [] as Array[String]
			(out[key] as Array[String]).append(n)
	return out

## Mono mode (item 818): teams of one element (3 different species where the element has them,
## else repeats) against a team of another element; win rate per element, both sides AI tier
## [param ai_level].
static func run_mono(level: int, battles: int, seed_value: int, ai_level: int = 2) -> Dictionary:
	Database.load_all()
	var pools: Dictionary = mono_pools(level)
	var els: Array = pools.keys()
	els.sort()
	var rows: Dictionary = {}
	for e: String in els:
		rows[e] = {"wins": 0, "losses": 0, "draws": 0, "species": (pools[e] as Array).size()}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for b: int in battles:
		if els.size() < 2:
			break
		var a: String = els[rng.randi_range(0, els.size() - 1)]
		var c: String = a
		while c == a:
			c = els[rng.randi_range(0, els.size() - 1)]
		var teams: Array[Array] = []
		for e: String in [a, c]:
			var pool: Array[String] = pools[e]
			var names: Array[String] = _pick(pool, 3, rng)
			while names.size() < 3:
				names.append(pool[rng.randi_range(0, pool.size() - 1)])
			teams.append(_build(names, level, rng))
		var mine: Array[Spirling] = []
		mine.assign(teams[0])
		var theirs: Array[Spirling] = []
		theirs.assign(teams[1])
		var r: Dictionary = team_battle(mine, theirs, rng.randi(), ai_level, ai_level)
		var w: int = int(r.winner)
		if w < 0:
			rows[a].draws += 1
			rows[c].draws += 1
		else:
			rows[a if w == 0 else c].wins += 1
			rows[c if w == 0 else a].losses += 1
	for e: String in rows:
		var wr: float = win_rate(rows[e])
		rows[e]["win_rate"] = snappedf(wr, 0.001)
		rows[e]["ok"] = wr >= MONO_BAND.x and wr <= MONO_BAND.y
	return {"mode": "mono", "level": level, "battles": battles, "ai": ai_level, "elements": rows}

static func mono_report(result: Dictionary) -> String:
	var lines: PackedStringArray = ["# Mono report", "",
		"Level %d, %d battles, teams of one element against another, AI tier %d. Target band %d to %d %%." % [
			result.level, result.battles, result.ai, roundi(MONO_BAND.x * 100.0), roundi(MONO_BAND.y * 100.0)], "",
		"| Element | Species | Win rate | W | L | D | Flag |", "| --- | --- | --- | --- | --- | --- | --- |"]
	for e: String in result.elements:
		var row: Dictionary = result.elements[e]
		var wr: float = float(row.win_rate)
		var flag: String = "" if bool(row.ok) else ("too strong" if wr > MONO_BAND.y else "too weak")
		lines.append("| %s | %d | %d%% | %d | %d | %d | %s |" % [e, row.species, roundi(wr * 100.0), row.wins, row.losses, row.draws, flag])
	return "\n".join(lines) + "\n"

## Goals mode (item 820): every bonus goal with its reference team on [param difficulty].
static func run_goals(rounds: int, seed_value: int, difficulty: int = GameState.Difficulty.TAMER) -> Dictionary:
	Database.load_all()
	var rows: Dictionary = {}
	for key: String in BattleGoals.all():
		var rate: float = goal_rate(key, rounds, seed_value, difficulty)
		rows[key] = {"rate": snappedf(rate, 0.001), "ok": rate >= GOAL_MIN_RATE}
	return {"mode": "goals", "rounds": rounds, "difficulty": difficulty, "goals": rows}

## Least share of battles in which a reference team must meet its goal (item 768).
const GOAL_MIN_RATE: float = 0.2

static func goals_report(result: Dictionary) -> String:
	var lines: PackedStringArray = ["# Bonus goal report", "",
		"%d battles per goal, difficulty %d, reference teams from tools/balance/goal_teams.json. Each must reach %d %%." % [
			result.rounds, result.difficulty, roundi(GOAL_MIN_RATE * 100.0)], "",
		"| Goal | Met | Flag |", "| --- | --- | --- |"]
	for k: String in result.goals:
		var row: Dictionary = result.goals[k]
		lines.append("| %s | %d%% | %s |" % [k, roundi(float(row.rate) * 100.0), "" if bool(row.ok) else "too hard"])
	return "\n".join(lines) + "\n"

# --- Puzzle mode (plan area 2, item 819) ----------------------------------------------------

## Every puzzle of data/puzzles.json searched to the end: winning lines, all lines, the winning
## share, the fewest turns of a win and the lantern target (best_turns) it is held to.
static func run_puzzles(only: String = "") -> Dictionary:
	Database.load_all()
	var rows: Dictionary = {}
	for p: Dictionary in BattlePuzzle.all():
		if not only.is_empty() and str(p.id) != only:
			continue
		var r: Dictionary = BattlePuzzle.search(p)
		var target: int = int(p.get("best_turns", 0))
		rows[str(p.id)] = {"wins": int(r.wins), "lines": int(r.lines), "share": snappedf(float(r.share), 0.0001),
			"best_turns": int(r.best_turns), "target_turns": target, "solvable": int(r.wins) > 0,
			"target_reachable": target <= 0 or (int(r.wins) > 0 and int(r.best_turns) <= target)}
	return {"mode": "puzzle", "puzzles": rows}

static func puzzle_report(result: Dictionary) -> String:
	var lines: PackedStringArray = ["# Puzzle report", "", "Every line of player choices played to the end (BattlePuzzle.search).", "",
		"| Puzzle | Solutions | Lines | Share | Fewest turns | Lantern target | Flag |", "| --- | --- | --- | --- | --- | --- | --- |"]
	for id: String in result.puzzles:
		var row: Dictionary = result.puzzles[id]
		var flag: String = "unsolvable" if not bool(row.solvable) else ("target out of reach" if not bool(row.target_reachable) else "")
		lines.append("| %s | %d | %d | %.2f%% | %d | %s | %s |" % [id, row.wins, row.lines, float(row.share) * 100.0, row.best_turns,
			str(row.target_turns) if int(row.target_turns) > 0 else "-", flag])
	return "\n".join(lines) + "\n"

# --- Baseline comparison (plan area 2, item 816) --------------------------------------------

const BASELINE_PATH: String = "res://tools/balance/baseline_lv36.json"
## Shift in win rate (as a share) beyond which the comparison flags a species or art.
const COMPARE_SHIFT: float = 0.08
const COMPARE_MIN_USES: int = 30

## Share of an art's uses made by the side that went on to win (team mode), 0 without uses.
static func move_win_rate(row: Dictionary) -> float:
	return float(row.get("win_uses", 0)) / maxf(float(row.get("used", 0)), 1.0)

## Every species and art of [param result] whose win rate moved more than COMPARE_SHIFT from
## [param baseline] (both team results as to_json writes them). Kinds or arts missing on one side
## are left out; a mode or level that differs is reported as "mismatch".
static func compare(result: Dictionary, baseline: Dictionary) -> Dictionary:
	var out: Dictionary = {"mismatch": "", "species": [], "moves": []}
	if str(baseline.get("mode", "")) != str(result.get("mode", "")) or int(baseline.get("level", 0)) != int(result.get("level", 0)):
		out.mismatch = "The baseline is %s at level %d, this run %s at level %d." % [baseline.get("mode", "?"), int(baseline.get("level", 0)),
			result.get("mode", "?"), int(result.get("level", 0))]
		return out
	var bsp: Dictionary = baseline.get("species", {})
	for n: String in result.get("species", {}):
		if bsp.has(n):
			var now: float = win_rate(result.species[n])
			var was: float = win_rate(bsp[n])
			if absf(now - was) > COMPARE_SHIFT:
				out.species.append({"name": n, "was": snappedf(was, 0.001), "now": snappedf(now, 0.001)})
	var bmv: Dictionary = baseline.get("moves", {})
	for n: String in result.get("moves", {}):
		# Rarely picked arts swing by chance; only arts used COMPARE_MIN_USES times on both sides count.
		if bmv.has(n) and int(bmv[n].get("used", 0)) >= COMPARE_MIN_USES and int(result.moves[n].get("used", 0)) >= COMPARE_MIN_USES:
			var now: float = move_win_rate(result.moves[n])
			var was: float = move_win_rate(bmv[n])
			if absf(now - was) > COMPARE_SHIFT:
				out.moves.append({"name": n, "was": snappedf(was, 0.001), "now": snappedf(now, 0.001)})
	return out

static func compare_report(cmp: Dictionary) -> String:
	var lines: PackedStringArray = ["", "## Shifts against the baseline", ""]
	if not str(cmp.mismatch).is_empty():
		lines.append(str(cmp.mismatch) + " Nothing compared.")
		return "\n".join(lines) + "\n"
	if (cmp.species as Array).is_empty() and (cmp.moves as Array).is_empty():
		lines.append("No species or art moved by more than %d points." % roundi(COMPARE_SHIFT * 100.0))
		return "\n".join(lines) + "\n"
	lines.append_array(["| Kind | Name | Baseline | Now | Shift |", "| --- | --- | --- | --- | --- |"])
	for kind: String in ["species", "moves"]:
		for row: Dictionary in cmp[kind]:
			lines.append("| %s | %s | %d%% | %d%% | %+d |" % ["Species" if kind == "species" else "Art", row.name,
				roundi(float(row.was) * 100.0), roundi(float(row.now) * 100.0), roundi((float(row.now) - float(row.was)) * 100.0)])
	return "\n".join(lines) + "\n"

# --- Keepsake and field value (plan area 2, items 828, 829) ---------------------------------

## Most a keepsake may lift its team's win rate (item 828), as a share.
const KEEPSAKE_MAX_GAIN: float = 0.06
## Band a field must lift the win rate of its boosted element by (item 829), as shares.
const FIELD_GAIN_BAND: Vector2 = Vector2(0.08, 0.15)

## Every item a Spirling can hold, sorted.
static func keepsakes() -> Array[String]:
	var out: Array[String] = []
	for id: String in Database.items:
		if BattleRules.is_holdable(id):
			out.append(id)
	out.sort()
	return out

## Win share of side A over [param battles] battle pairs: the same two teams (A of [param a_names]
## or random, B random) once with [param with] applied to A's model and once without. Sides swap
## every pair so neither keeps the player side. Returns {"with", "without"} (draws count half).
static func _paired(level: int, battles: int, seed_value: int, a_pool: Array[String], setup: Callable) -> Dictionary:
	var pool: Array[String] = valid_species(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var score: Array[float] = [0.0, 0.0]
	for b: int in battles:
		var a_names: Array[String] = _pick(a_pool, 3, rng)
		while a_names.size() < 3 and not a_pool.is_empty():
			a_names.append(a_pool[rng.randi_range(0, a_pool.size() - 1)])
		var b_names: Array[String] = _pick(pool, 3, rng)
		var bseed: int = rng.randi()
		var a_side: int = b % 2
		for k: int in 2:
			var trng := RandomNumberGenerator.new()
			trng.seed = bseed
			var teams: Array[Array] = [_build(a_names, level, trng), _build(b_names, level, trng)]
			if a_side == 1:
				teams.reverse()
			var mine: Array[Spirling] = []
			mine.assign(teams[0])
			var theirs: Array[Spirling] = []
			theirs.assign(teams[1])
			var m := BattleModel.new(mine, theirs, false, bseed, 2)
			m.items_allowed = false
			_apply_switches(m)
			if k == 0:
				setup.call(m, a_side)
			var r: Dictionary = _play(m, 2)
			var w: int = int(r.winner)
			score[k] += 1.0 if w == a_side else (0.5 if w < 0 else 0.0)
	return {"with": score[0] / maxf(battles, 1), "without": score[1] / maxf(battles, 1)}

## Plays a built model to the end with the player side on AI [param ai_level].
static func _play(m: BattleModel, ai_level: int) -> Dictionary:
	var brain := BattleAI.new(ai_level)
	m.start()
	var turns: int = 0
	while not m.is_finished() and turns < MAX_TURNS * 2:
		if m.needs_player_switch():
			m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot()))
			continue
		m.submit_turn(brain.choose(m, BattleModel.Side.PLAYER))
		turns += 1
	var winner: int = sim_winner(m)
	return {"winner": winner, "turns": turns}

## Keepsake mode (item 828): for every holdable item, random teams of 3 where A's lead holds it
## against the same battle without; the gain is the difference of A's win rates.
static func run_keepsakes(level: int, battles: int, seed_value: int, only: Array[String] = []) -> Dictionary:
	Database.load_all()
	var rows: Dictionary = {}
	var pool: Array[String] = valid_species(level)
	for id: String in keepsakes():
		if not only.is_empty() and not id in only:
			continue
		var r: Dictionary = _paired(level, battles, hash([seed_value, id]), pool, func(m: BattleModel, side: int) -> void:
			m.parties[side][0].held = id)
		var gain: float = float(r.with) - float(r.without)
		rows[id] = {"with": snappedf(r.with, 0.001), "without": snappedf(r.without, 0.001), "gain": snappedf(gain, 0.001),
			"ok": gain <= KEEPSAKE_MAX_GAIN}
	return {"mode": "keepsakes", "level": level, "battles": battles, "keepsakes": rows}

## Field mode (item 829): for every field that boosts an element, teams of 3 of that element
## against random teams, once on the field and once without; the gain is the difference.
static func run_fields(level: int, battles: int, seed_value: int, only: Array[String] = []) -> Dictionary:
	Database.load_all()
	var pools: Dictionary = mono_pools(level)
	var rows: Dictionary = {}
	for fid: String in BattleRules.FIELDS:
		var boost: String = str(BattleRules.FIELDS[fid].get("boost", ""))
		var el: String = Elements.element_name(int(Elements.E.get(boost, -1))) if not boost.is_empty() else ""
		if el.is_empty() or not pools.has(el) or (not only.is_empty() and not fid in only):
			continue
		var r: Dictionary = _paired(level, battles, hash([seed_value, fid]), pools[el], func(m: BattleModel, _side: int) -> void:
			m.field = fid)
		var gain: float = float(r.with) - float(r.without)
		rows[fid] = {"element": el, "with": snappedf(r.with, 0.001), "without": snappedf(r.without, 0.001), "gain": snappedf(gain, 0.001),
			"ok": gain >= FIELD_GAIN_BAND.x and gain <= FIELD_GAIN_BAND.y}
	return {"mode": "fields", "level": level, "battles": battles, "fields": rows}

static func keepsakes_report(result: Dictionary) -> String:
	var lines: PackedStringArray = ["# Keepsake report", "",
		"Level %d, %d battle pairs per keepsake (random teams of 3, the lead of one side holds it, same battle without). Target: at most +%d points." % [
			result.level, result.battles, roundi(KEEPSAKE_MAX_GAIN * 100.0)], "",
		"| Keepsake | With | Without | Gain | Flag |", "| --- | --- | --- | --- | --- |"]
	for id: String in result.keepsakes:
		var row: Dictionary = result.keepsakes[id]
		lines.append("| %s | %d%% | %d%% | %+.1f | %s |" % [id, roundi(float(row.with) * 100.0), roundi(float(row.without) * 100.0),
			float(row.gain) * 100.0, "" if bool(row.ok) else "too strong"])
	return "\n".join(lines) + "\n"

static func fields_report(result: Dictionary) -> String:
	var lines: PackedStringArray = ["# Field report", "",
		"Level %d, %d battle pairs per field (teams of the boosted element against random teams, on the field and without). Target band +%d to +%d points." % [
			result.level, result.battles, roundi(FIELD_GAIN_BAND.x * 100.0), roundi(FIELD_GAIN_BAND.y * 100.0)], "",
		"| Field | Element | With | Without | Gain | Flag |", "| --- | --- | --- | --- | --- | --- |"]
	for fid: String in result.fields:
		var row: Dictionary = result.fields[fid]
		var g: float = float(row.gain)
		lines.append("| %s | %s | %d%% | %d%% | %+.1f | %s |" % [fid, row.element, roundi(float(row.with) * 100.0), roundi(float(row.without) * 100.0),
			g * 100.0, "" if bool(row.ok) else ("too strong" if g > FIELD_GAIN_BAND.y else "too weak")])
	return "\n".join(lines) + "\n"

# --- Seed spread, mirror check and rare new arts (plan area 2, items 830, 831, 833) ----------

## Spread of a species' win rate across seeds above which the report calls it uncertain (item 830).
const SEED_SPREAD_MAX: float = 0.10
## Band the player side of a battle between two copies of one species must land in (item 831).
const MIRROR_BAND: Vector2 = Vector2(0.45, 0.55)
## Share of its element's picks below which a new art is listed as rarely chosen (item 833).
const RARE_ART_SHARE: float = 0.01

## The new arts of plan area 2 (the ones without a learnset in the original roster).
const NEW_ARTS: Array[String] = [
	"Glow Knuckle", "Char Mark", "Spout Jab", "Deepwell Draught", "Pollen Prick", "Static Tag", "Grid Lock",
	"Grit Jab", "Crosswind", "Kite Cut", "Scatter Gale", "Beacon Ping", "Dawn Needle", "Shade Pounce",
	"Gloom Handoff", "Quarry Wall", "Landslip", "Shard Bed", "Monolith Drop", "Pumice Pelt", "Fault Line",
	"Downburst", "Draft Needle", "Squall Line", "Cloudbreak", "Capacitor Crash", "Pylon Snap", "Short Circuit",
	"Bellows Blast", "Coal Seed", "Furnace Heart", "Cinder Dash", "Brazier Pulse", "Salt Spray", "Rip Current",
	"Fathom Crush", "Bore Wave", "Shoal Trap", "Bramble Bed", "Wildgrowth Crash", "Husk Shed", "Thornwake",
	"Bark Burst", "Seed Spit", "Graft", "Overdraw", "Wire Trap", "Lull Breaker", "Chaff Feint", "Gale Mantle",
	"Sunwell Sip", "Daybreak Strike", "Prism Burst", "Starlit Lash", "Glow Trap", "Night Toll", "Eclipse Crush",
	"Murmur Bite", "Veil Step", "Gloam Pact", "Dusk Snare", "Gravel Hum", "Slow Quake", "Omen Bell",
]

## Seed i of a multi-seed run: far enough apart that the runs share no battles.
static func nth_seed(seed_value: int, i: int) -> int:
	return seed_value + i * 7919

## Item 830: the duel or team run [param count] times on different seeds. Per species the mean
## and the spread (highest minus lowest win rate); a spread above SEED_SPREAD_MAX is uncertain.
## Returns {"mode", "level", "count", "seeds", "first": the run on the first seed, "species":
## {name: {"mean", "spread", "rates", "uncertain"}}}.
static func run_seeds(mode: String, level: int, rounds: int, seed_value: int, count: int, ai_level: int) -> Dictionary:
	var runs: Array[Dictionary] = []
	var seeds: Array[int] = []
	for i: int in maxi(count, 1):
		var s: int = nth_seed(seed_value, i)
		seeds.append(s)
		if mode == "team":
			runs.append(run_team(level, rounds, s, ai_level))
		else:
			runs.append(run(level, rounds, s, [] as Array[String], ai_level))
	var species: Dictionary = {}
	for n: String in runs[0].species:
		var rates: Array[float] = []
		for r: Dictionary in runs:
			if (r.species as Dictionary).has(n):
				rates.append(snappedf(win_rate(r.species[n]), 0.001))
		var total: float = 0.0
		for x: float in rates:
			total += x
		var spread: float = rates.max() - rates.min()
		species[n] = {"mean": snappedf(total / maxf(rates.size(), 1), 0.001), "spread": snappedf(spread, 0.001),
			"rates": rates, "uncertain": spread > SEED_SPREAD_MAX + 0.0005}
	return {"mode": mode, "level": level, "count": runs.size(), "seeds": seeds, "first": runs[0], "species": species}

static func seeds_report(result: Dictionary) -> String:
	var sp: Dictionary = result.species
	var names: Array = sp.keys()
	names.sort_custom(func(x: String, y: String) -> bool:
		if float(sp[x].spread) != float(sp[y].spread):
			return float(sp[x].spread) > float(sp[y].spread)
		return x < y)
	var unsure: int = 0
	for n: String in names:
		unsure += 1 if bool(sp[n].uncertain) else 0
	var lines: PackedStringArray = ["", "## Spread over %d seeds" % int(result.count), "",
		"Mode %s, level %d, seeds %s. A spread above %d points marks the win rate as uncertain: %d of %d species." % [
			result.mode, result.level, ", ".join(PackedStringArray(result.seeds.map(func(s: int) -> String: return str(s)))),
			roundi(SEED_SPREAD_MAX * 100.0), unsure, names.size()], "",
		"| Species | Mean | Spread | Flag |", "| --- | --- | --- | --- |"]
	for n: String in names:
		var row: Dictionary = sp[n]
		lines.append("| %s | %d%% | %.1f | %s |" % [n, roundi(float(row.mean) * 100.0), float(row.spread) * 100.0,
			"uncertain" if bool(row.uncertain) else ""])
	return "\n".join(lines) + "\n"

## Item 831: every species against a copy of itself, [param rounds] duels each. The player
## side's share (draws count half) must land in MIRROR_BAND, both per species and over all;
## outside it the side a Spirling stands on decides battles.
static func run_mirror(level: int, rounds: int, seed_value: int, ai_level: int = 1) -> Dictionary:
	Database.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rows: Dictionary = {}
	var moves: Dictionary = {}
	var score: float = 0.0
	var games: int = 0
	for n: String in valid_species(level):
		var s: float = 0.0
		for r: int in rounds:
			var res: Dictionary = fight(n, n, level, rng.randi(), moves, ai_level)
			s += 1.0 if int(res.winner) == 0 else (0.5 if int(res.winner) < 0 else 0.0)
		var share: float = s / maxf(rounds, 1)
		score += s
		games += rounds
		rows[n] = {"share": snappedf(share, 0.001), "ok": share >= MIRROR_BAND.x and share <= MIRROR_BAND.y}
	var overall: float = score / maxf(games, 1)
	return {"mode": "mirror", "level": level, "rounds": rounds, "species": rows, "share": snappedf(overall, 0.001),
		"ok": overall >= MIRROR_BAND.x and overall <= MIRROR_BAND.y}

static func mirror_report(result: Dictionary) -> String:
	var sp: Dictionary = result.species
	var off: Array[String] = []
	for n: String in sp:
		if not bool(sp[n].ok):
			off.append(n)
	var lines: PackedStringArray = ["# Mirror report", "",
		"Level %d, %d duels of every species against itself. Target band for the player side: %d%% to %d%%." % [
			result.level, result.rounds, roundi(MIRROR_BAND.x * 100.0), roundi(MIRROR_BAND.y * 100.0)], "",
		"Player side over all: %d%%%s." % [roundi(float(result.share) * 100.0), "" if bool(result.ok) else " (outside the band)"],
		"%d of %d species outside the band." % [off.size(), sp.size()], ""]
	if not off.is_empty():
		lines.append_array(["| Species | Player side |", "| --- | --- |"])
		for n: String in off:
			lines.append("| %s | %d%% |" % [n, roundi(float(sp[n].share) * 100.0)])
	return "\n".join(lines) + "\n"

## New arts some Spirling of a team at [param level] knows (its default moves there); the rest
## can't show up in a team run at that ring at all.
static func carried_new_arts(level: int) -> Array[String]:
	var seen: Dictionary = {}
	for n: String in valid_species(level):
		for md: MoveData in Database.species(n).default_moves(level, Spirling.MAX_MOVES):
			seen[md.move_name] = true
	var out: Array[String] = []
	for art: String in NEW_ARTS:
		if seen.has(art):
			out.append(art)
	return out

## Item 833: the new arts a team at the run's ring carries that got less than RARE_ART_SHARE
## of their element's picks in a team run (never picked counts as 0). Returns
## [{"art", "element", "share"}], rarest first.
static func rare_new_arts(result: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var el: Dictionary = result.get("elements", {})
	var mv: Dictionary = result.get("moves", {})
	for art: String in carried_new_arts(int(result.get("level", 1))):
		var md: MoveData = Database.move(art)
		if md == null:
			continue
		var element: String = Elements.element_name(md.element)
		var used: int = int((mv.get(art, {}) as Dictionary).get("used", 0))
		var share: float = float(used) / maxf(int(el.get(element, 0)), 1)
		if share < RARE_ART_SHARE:
			out.append({"art": art, "element": element, "share": snappedf(share, 0.0001)})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if float(x.share) != float(y.share):
			return float(x.share) < float(y.share)
		return str(x.art) < str(y.art))
	return out

static func rare_arts_report(result: Dictionary) -> PackedStringArray:
	var rare: Array[Dictionary] = rare_new_arts(result)
	var carried: int = carried_new_arts(int(result.get("level", 1))).size()
	var lines: PackedStringArray = ["", "## Rarely chosen new arts", "",
		"%d of %d new arts are known by some Spirling at this level; %d of them got less than %d%% of their element's picks." % [
			carried, NEW_ARTS.size(), rare.size(), roundi(RARE_ART_SHARE * 100.0)]]
	if not rare.is_empty():
		lines.append_array(["", "| Art | Element | Share |", "| --- | --- | --- |"])
		for r: Dictionary in rare:
			lines.append("| %s | %s | %.1f%% |" % [r.art, r.element, float(r.share) * 100.0])
	return lines
