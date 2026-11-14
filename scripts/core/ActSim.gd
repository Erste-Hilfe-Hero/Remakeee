class_name ActSim
extends RefCounted
## Act difficulty simulator (owner rule, Nov 2026: every act and era region is hard).
## Plays a seeded player route through each act and era region of tools/balance/act_route.json on
## the real BattleModel: wild battles at the route's rings give XP the way the game does, the
## player bonds one new kind per wild table, re-picks the five strongest, unfolds by ring and
## learns the newest arts. Every Warden, rival and boss on the route is measured on Tamer:
## the win rate on arrival (no grinding, the five strongest as they are), then with the team picked
## by element after every grind step of wild battles until it wins 70 % of the time (grind_max at
## most); the act's moderate_grind step is the "win with some training and good type choices" mark. The route goes on with the team that trained
## until that win or the act's moderate grind, whichever came first.
## No level cap is used: a Spirling grows without a top ring (Spirling.LEVEL_SANITY guards only).

const ROUTE_PATH: String = "res://tools/balance/act_route.json"
const MAX_TURNS: int = 120
const DIFFICULTY: int = 1 # GameState.Difficulty.TAMER, the default
## Route kind of a Rift heart: reported, but left out of the act means (one swollen Spirling the
## whole team faces at once, right after its Warden).
const HEART: String = "heart"

static func route() -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH)) if FileAccess.file_exists(ROUTE_PATH) else null
	return raw if raw is Dictionary else {}

static func _read(path: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return raw if raw is Dictionary else {}

# --- Foe definitions ------------------------------------------------------------------------

## The Wayfarer definition behind a route reference: "map:npc" (map file, its floors and
## data/story_npcs.json) or "story:id" (data/story_battles.json).
## Returns {"def": Dictionary, "field": String}; {} if the reference is unknown.
static func resolve(ref: String) -> Dictionary:
	var parts: PackedStringArray = ref.split(":")
	if parts.size() != 2:
		return {}
	if parts[0] == "story":
		var d: Dictionary = StoryBattles.get_def(parts[1])
		return {"def": d, "field": ""} if not d.is_empty() else {}
	var raw: Dictionary = _read("res://data/maps/%s.json" % parts[0])
	var levels: Array = [raw]
	levels.append_array(raw.get("floors", []))
	var placed: Variant = _read(StoryPlacements.PATH).get(parts[0], {})
	if placed is Dictionary:
		levels.append(placed)
	for lv: Variant in levels:
		if not lv is Dictionary:
			continue
		for n: Variant in (lv as Dictionary).get("npcs", []):
			if n is Dictionary and str(n.get("id", "")) == parts[1] and TrainerData.is_trainer(n):
				return {"def": n, "field": str((lv as Dictionary).get("field", raw.get("field", "")))}
	return {}

## Wild table of a route reference: an encounter table id of data/encounters.json, or
## "regionN:route" (era sheet route: its ring range and slot kinds). [{species, min, max, weight}].
static func wild_table(ref: String) -> Array:
	if ref.contains(":"):
		var parts: PackedStringArray = ref.split(":")
		var d: Dictionary = _read("res://data/%s.json" % parts[0])
		for r: Variant in d.get("routes", []):
			if r is Dictionary and str(r.get("id", "")) == parts[1]:
				var out: Array = []
				for s: Variant in r.get("slots", []):
					var sp: Variant = s.get("species")
					out.append({"species": str(sp) if sp != null else str(s.get("stand_in", "")),
						"min": int(r.ring[0]), "max": int(r.ring[1]), "weight": int(s.get("weight", 1))})
				return out
		return []
	var enc: Dictionary = _read("res://data/encounters.json")
	return (enc.get(ref, {}) as Dictionary).get("spawns", [])

# --- Player team ----------------------------------------------------------------------------

static func power(s: Spirling) -> float:
	return float(s.max_hp() + s.atk() + s.def() + s.foc() + s.spd())

## Unfolds by ring (item unfolds at BalanceSim.ITEM_EVOLVE_LEVEL) and refreshes the arts to the
## newest four of the learnset, as a player who keeps the team current would.
static func grow(s: Spirling) -> void:
	var guard: int = 0
	while s.data.evolves_to != null and s.level >= BalanceSim.evolve_at(s.data) and guard < 4:
		s.evolve(s.data.evolves_to)
		guard += 1
	s.moves = s.data.default_moves(s.level, Spirling.MAX_MOVES)
	s.restore()

## The [param count] strongest of everything bonded (the team: five).
static func pick_party(owned: Array[Spirling], count: int = GameState.MAX_PARTY) -> Array[Spirling]:
	var sorted: Array[Spirling] = owned.duplicate()
	sorted.sort_custom(func(a: Spirling, b: Spirling) -> bool: return power(a) > power(b))
	return sorted.slice(0, count)

## Element edge of [param s] against a foe team: own elements hitting them minus theirs hitting it.
static func matchup(s: Spirling, foes: Array[Spirling]) -> float:
	var score: float = 0.0
	for f: Spirling in foes:
		var best: float = 0.0
		for e: int in s.elements():
			best = maxf(best, Elements.multiplier(e, f.elements()))
		var worst: float = 0.0
		for e: int in f.elements():
			worst = maxf(worst, Elements.multiplier(e, s.elements()))
		score += best - worst
	return score / maxf(1.0, foes.size())

## Power weighed with the element edge against [param foes].
static func edge_score(s: Spirling, foes: Array[Spirling]) -> float:
	return power(s) * (1.0 + 0.15 * matchup(s, foes))

## Team for a measured fight ("good type choices"): of the eight strongest bonded, the six best by
## power weighed with the element edge against the foe team.
static func pick_for(owned: Array[Spirling], foes: Array[Spirling]) -> Array[Spirling]:
	var scored: Array = []
	for s: Spirling in pick_party(owned, GameState.MAX_PARTY + 3):
		scored.append([edge_score(s, foes), s])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array[Spirling] = []
	for row: Array in scored.slice(0, GameState.MAX_PARTY + 1):
		out.append(row[1])
	return out

## One trial's line-up from six candidates: one of them stays home and the order is shuffled, as
## different players line up differently; with [param foes] the best of power and element edge leads.
static func lineup(cands: Array[Spirling], rng: RandomNumberGenerator, foes: Array[Spirling] = []) -> Array[Spirling]:
	var team: Array[Spirling] = cands.duplicate()
	if team.size() > GameState.MAX_PARTY:
		team.remove_at(rng.randi_range(0, team.size() - 1))
	for i: int in range(team.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Spirling = team[i]
		team[i] = team[j]
		team[j] = t
	if not foes.is_empty():
		var best: int = 0
		for i: int in team.size():
			if edge_score(team[i], foes) > edge_score(team[best], foes):
				best = i
		var lead: Spirling = team[best]
		team.remove_at(best)
		team.insert(0, lead)
	return team

static func copy_team(team: Array[Spirling]) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for s: Spirling in team:
		var c: Spirling = Spirling.from_dict(s.to_dict())
		c.restore()
		out.append(c)
	return out

# --- Battles --------------------------------------------------------------------------------

static func _play(m: BattleModel) -> int:
	var brain := BattleAI.new(2)
	m.start()
	var turns: int = 0
	while not m.is_finished() and turns < MAX_TURNS:
		if m.needs_player_switch():
			m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot()))
			continue
		var acts: Array[BattleAction] = []
		for slot: int in m.player_slots():
			acts.append(brain.choose(m, BattleModel.Side.PLAYER, slot))
		m.submit_actions(acts)
		turns += 1
	if m.outcome == BattleModel.Outcome.WIN:
		return 0
	return 1 if m.outcome == BattleModel.Outcome.LOSS else -1

## One battle against a Wayfarer on Tamer, set up as Overworld._new_model does (no player items,
## like the Warden simulator). XP lands on [param mine] as in the game. Returns 0 win, 1 loss, -1 draw.
static func trainer_battle(mine: Array[Spirling], foe: Dictionary, seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var def: Dictionary = foe.def
	var foes: Array[Spirling] = TrainerData.build_team(def, "", rng, DIFFICULTY, Spirling.LEVEL_SANITY)
	var info: Dictionary = TrainerData.battle_info(def, foes, GameState.AI_LEVELS[DIFFICULTY], DIFFICULTY)
	var m := BattleModel.new(mine, foes, false, seed_value, int(info.ai))
	m.items_allowed = false
	m.level_cap = Spirling.LEVEL_SANITY
	m.ai.set_profile(str(info.profile), info.profile_tune)
	m.ai.set_difficulty(DIFFICULTY)
	m.foe_damage_mult = GameState.FOE_DAMAGE[DIFFICULTY]
	m.boss_hp_scale = GameState.BOSS_HP_SCALE[DIFFICULTY]
	m.boss_difficulty = DIFFICULTY
	m.field = str(foe.get("field", ""))
	m.foe_rule = str(info.rule)
	m.start_energy_cut = [0, int(def.get("foe_energy_cut", 0)) + BattleRules.foe_start_cut(DIFFICULTY)]
	m.foe_turn1_energy = BattleRules.foe_turn1_energy(DIFFICULTY)
	var items: Variant = info.get("items", {})
	m.foe_items = (items as Dictionary).duplicate() if items is Dictionary else {}
	var front: Array[int] = TrainerData.front(def)
	m.front_size = [front[0], front[1]]
	m.foe_boss = str(info.boss)
	var partner: Variant = def.get("partner", {})
	if partner is Dictionary and not (partner as Dictionary).is_empty():
		var ally: Array[Spirling] = TrainerData.build_team(partner, "", rng)
		m.set_partner(str(partner.get("name", "")), ally, int(partner.get("front", 1)),
			int(partner.get("ai", TrainerData.PARTNER_AI)), str(partner.get("profile", "")))
	return _play(m)

static func wild_battle(mine: Array[Spirling], table: Array, rng: RandomNumberGenerator) -> void:
	var sp: Dictionary = _roll(table, rng)
	var sd: SpirlingData = Database.species(str(sp.get("species", "")))
	if sd == null:
		return
	var foe := Spirling.new(sd, rng.randi_range(int(sp.min), int(sp.max)), rng)
	var m := BattleModel.new(mine, [foe] as Array[Spirling], true, rng.randi(), 0)
	m.items_allowed = false
	m.level_cap = Spirling.LEVEL_SANITY
	_play(m)

static func _roll(table: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for s: Variant in table:
		total += int(s.get("weight", 1))
	var r: int = rng.randi_range(1, maxi(1, total))
	for s: Variant in table:
		r -= int(s.get("weight", 1))
		if r <= 0:
			return s
	return table[0] if not table.is_empty() else {}

# --- Route ----------------------------------------------------------------------------------

## Win rate of the bonded Spirlings against [param foe] over [param trials] seeded battles: the
## six strongest, one of them left home and the order shuffled per battle. With [param smart] the
## player also tries the six picked by element ("good type choices") and keeps the better of both.
static func measure(owned: Array[Spirling], foe: Dictionary, trials: int, seed_value: int, smart: bool = true) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var probe: Array[Spirling] = TrainerData.build_team(foe.def, "", rng, DIFFICULTY, Spirling.LEVEL_SANITY)
	var none: Array[Spirling] = []
	var base_seed: int = rng.randi()
	var plain: float = _rate(pick_party(owned, GameState.MAX_PARTY + 1), none, foe, trials, base_seed)
	if not smart:
		return plain
	return maxf(plain, _rate(pick_for(owned, probe), probe, foe, trials, base_seed))

static func _rate(cands: Array[Spirling], probe: Array[Spirling], foe: Dictionary, trials: int, seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wins: float = 0.0
	for t: int in trials:
		var team: Array[Spirling] = lineup(cands, rng, probe)
		var res: int = trainer_battle(copy_team(team), foe, rng.randi())
		wins += 1.0 if res == 0 else (0.5 if res == -1 else 0.0)
	return wins / maxf(1.0, trials)

static func _snapshot(owned: Array[Spirling]) -> Array:
	var out: Array = []
	for s: Spirling in owned:
		out.append(s.to_dict())
	return out

static func _restore(snap: Array) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for d: Dictionary in snap:
		out.append(Spirling.from_dict(d))
	return out

## Plays wild battles on [param table], the weakest of the five in the lead each time, so the
## XP spreads as a player rotating the lead spreads it.
static func grind(owned: Array[Spirling], table: Array, battles: int, rng: RandomNumberGenerator, foes: Array[Spirling] = []) -> void:
	for i: int in battles:
		var party: Array[Spirling] = pick_party(owned) if foes.is_empty() else train_party(owned, foes)
		party.sort_custom(func(a: Spirling, b: Spirling) -> bool: return a.level < b.level)
		wild_battle(party, table, rng)
		for s: Spirling in party:
			grow(s)

## Training party for a fight ahead: the three strongest and the two bonded Spirlings with the
## best element edge against [param foes], so a player who trains raises the right kinds.
static func train_party(owned: Array[Spirling], foes: Array[Spirling]) -> Array[Spirling]:
	var sorted: Array[Spirling] = pick_party(owned, owned.size())
	var out: Array[Spirling] = sorted.slice(0, GameState.MAX_PARTY - 2)
	var rest: Array[Spirling] = sorted.slice(GameState.MAX_PARTY - 2)
	rest.sort_custom(func(a: Spirling, b: Spirling) -> bool:
		var ma: float = matchup(a, foes)
		var mb: float = matchup(b, foes)
		return ma > mb if not is_equal_approx(ma, mb) else power(a) > power(b))
	out.append_array(rest.slice(0, 2))
	return out

static func _bond(owned: Array[Spirling], table: Array, count: int, rng: RandomNumberGenerator) -> void:
	var have: Dictionary = {}
	for s: Spirling in owned:
		have[s.data.species_name] = true
		var e: SpirlingData = Database.earlier_form(s.data)
		while e != null:
			have[e.species_name] = true
			e = Database.earlier_form(e)
	var sorted: Array = table.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("weight", 1)) > int(b.get("weight", 1)))
	var got: int = 0
	for sp: Dictionary in sorted:
		if got >= count:
			return
		var sd: SpirlingData = Database.species(str(sp.get("species", "")))
		if sd == null or have.has(sd.species_name):
			continue
		var s := Spirling.new(sd, int(sp.max), rng)
		grow(s)
		owned.append(s)
		have[sd.species_name] = true
		got += 1

## Runs every act of the route (or [param only]) for one starter. Returns {"acts": [{"id", "name",
## "fights": [{"ref", "kind", "name", "foe_levels", "arrival_avg", "arrival_top", "win_arrival",
## "win_moderate", "grind_needed", "wall"}]}], "starter", "trials"}.
static func run(starter: String, trials: int, seed_value: int, only: Array[String] = []) -> Dictionary:
	Database.load_all()
	var cfg: Dictionary = route()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var owned: Array[Spirling] = [Spirling.new(Database.species(starter), int(cfg.get("start_ring", 5)), rng)]
	var step_n: int = int(cfg.get("grind_step", 10))
	var moderate: int = int(cfg.get("moderate_grind", 30))
	var grind_max: int = int(cfg.get("grind_max", 150))
	var target: float = float(cfg.get("grind_target", 0.7))
	var out_acts: Array = []
	var last_table: Array = []
	for act: Dictionary in cfg.get("acts", []):
		var fights: Array = []
		for step: Dictionary in act.get("steps", []):
			if step.has("wild"):
				last_table = wild_table(str(step.wild))
				_bond(owned, last_table, int(step.get("bond", cfg.get("bond_per_table", 1))), rng)
				grind(owned, last_table, int(step.get("battles", cfg.get("incidental", 6))), rng)
			elif step.has("fight"):
				var foe: Dictionary = resolve(str(step.fight))
				if foe.is_empty():
					push_error("ActSim: unknown fight %s" % step.fight)
					continue
				for attempt: int in 3:
					var party: Array[Spirling] = pick_party(owned)
					var res: int = trainer_battle(party, foe, rng.randi())
					for s: Spirling in party:
						grow(s)
					if res == 0:
						break
			elif step.has("boss"):
				var foe: Dictionary = resolve(str(step.boss))
				if foe.is_empty():
					push_error("ActSim: unknown boss %s" % step.boss)
					continue
				# One draw per fight: a retuned team changes its own fight, not the dice of every later one.
				var fight_rng := RandomNumberGenerator.new()
				fight_rng.seed = rng.randi()
				var row: Dictionary = _boss(owned, foe, step, trials, fight_rng, last_table, step_n, int(act.get("moderate_grind", moderate)), grind_max, target)
				owned = row.owned
				row.erase("owned")
				if only.is_empty() or str(act.id) in only:
					fights.append(row)
		if only.is_empty() or str(act.id) in only:
			out_acts.append({"id": str(act.id), "name": str(act.get("name", act.id)), "fights": fights})
		if not only.is_empty() and out_acts.size() == only.size():
			break
	return {"acts": out_acts, "starter": starter, "trials": trials, "seed": seed_value}

static func _boss(owned: Array[Spirling], foe: Dictionary, step: Dictionary, trials: int, rng: RandomNumberGenerator,
		table: Array, step_n: int, moderate: int, grind_max: int, target: float) -> Dictionary:
	var probe_rng := RandomNumberGenerator.new()
	probe_rng.seed = 1
	var probe: Array[Spirling] = TrainerData.build_team(foe.def, "", probe_rng, DIFFICULTY, Spirling.LEVEL_SANITY)
	var levels: Array[int] = []
	for f: Spirling in probe:
		levels.append(f.level)
	var party: Array[Spirling] = pick_party(owned)
	var lv_sum: int = 0
	var top: int = 0
	for s: Spirling in party:
		lv_sum += s.level
		top = maxi(top, s.level)
	var row: Dictionary = {"ref": str(step.boss), "kind": str(step.get("kind", "warden")), "name": str(foe.def.get("trainer", step.boss)),
		"foe_levels": levels, "foe_top": levels.max() if not levels.is_empty() else 0,
		"arrival_avg": float(lv_sum) / maxf(1.0, party.size()), "arrival_top": top}
	var wr: float = measure(owned, foe, trials, rng.randi(), false)
	row["win_arrival"] = wr
	var done: int = 0
	var smart0: float = measure(owned, foe, trials, rng.randi())
	var needed: int = 0 if smart0 >= target else -1
	# The route goes on with the player who trained until the win or the moderate grind, whichever
	# came first, so a hard fight early does not inflate every arrival after it.
	var snap: Array = _snapshot(owned) if needed == 0 else []
	var at_moderate: float = smart0
	while done < grind_max and (needed < 0 or done < moderate):
		grind(owned, table, step_n, rng, probe)
		done += step_n
		var w: float = measure(owned, foe, trials, rng.randi())
		if done <= moderate:
			at_moderate = w
		if needed < 0 and w >= target:
			needed = done
		if snap.is_empty() and (needed >= 0 or done >= moderate):
			snap = _snapshot(owned)
	row["win_moderate"] = at_moderate
	row["grind_needed"] = needed
	row["wall"] = needed < 0
	var next: Array[Spirling] = _restore(snap) if not snap.is_empty() else owned
	# The player wins the fight once and keeps its XP.
	for attempt: int in 5:
		var team: Array[Spirling] = lineup(pick_for(next, probe), rng, probe)
		var res: int = trainer_battle(team, foe, rng.randi())
		for s: Spirling in team:
			grow(s)
		if res == 0:
			break
	row["owned"] = next
	return row

## Mean over starters per fight and per act: the numbers the bands in act_route.json check.
static func summary(results: Array) -> Dictionary:
	var acts: Dictionary = {}
	var order: Array[String] = []
	for r: Dictionary in results:
		for a: Dictionary in r.acts:
			if not acts.has(a.id):
				acts[a.id] = {"id": a.id, "name": a.name, "fights": {}, "order": []}
				order.append(a.id)
			for f: Dictionary in a.fights:
				var fs: Dictionary = acts[a.id].fights
				if not fs.has(f.ref):
					fs[f.ref] = {"ref": f.ref, "kind": f.kind, "name": f.name, "foe_top": f.foe_top, "n": 0,
						"arrival_avg": 0.0, "arrival_top": 0.0, "win_arrival": 0.0, "win_moderate": 0.0, "grind_needed": 0.0, "walls": 0}
					acts[a.id].order.append(f.ref)
				var s: Dictionary = fs[f.ref]
				s.n += 1
				s.arrival_avg += f.arrival_avg
				s.arrival_top += f.arrival_top
				s.win_arrival += f.win_arrival
				s.win_moderate += f.win_moderate
				s.grind_needed += f.grind_needed if f.grind_needed >= 0 else 999
				s.walls += 1 if f.wall else 0
	var out: Array = []
	for id: String in order:
		var a: Dictionary = acts[id]
		var rows: Array = []
		var wa: float = 0.0
		var wm: float = 0.0
		var gn: float = 0.0
		var gap: float = 0.0
		var walls: int = 0
		var counted: int = 0
		for ref: String in a.order:
			var s: Dictionary = a.fights[ref]
			for k: String in ["arrival_avg", "arrival_top", "win_arrival", "win_moderate", "grind_needed"]:
				s[k] = float(s[k]) / s.n
			rows.append(s)
			if s.kind == HEART:
				continue
			counted += 1
			wa += s.win_arrival
			wm += s.win_moderate
			gn += minf(s.grind_needed, 999.0)
			gap += float(s.foe_top) - s.arrival_avg
			walls += int(s.walls)
		var n: float = maxf(1.0, counted)
		out.append({"id": id, "name": a.name, "fights": rows, "win_arrival": wa / n, "win_moderate": wm / n,
			"grind_needed": gn / n, "level_gap": gap / n, "walls": walls})
	return {"acts": out}

static func report(sum: Dictionary, starters: Array, trials: int) -> String:
	var lines: PackedStringArray = ["# Act difficulty report", "",
		"Tamer, player on AI tier 2 without items, %d battles per measure, mean over the starters %s." % [trials, ", ".join(PackedStringArray(starters))],
		"Generated by `tools/balance_sim.gd --mode acts`; route and bands in tools/balance/act_route.json.", "",
		"| Act | Arrival gap (foe top - team avg) | Win on arrival | Win after moderate grind | Grind battles to 70 % | Walls |",
		"| --- | --- | --- | --- | --- | --- |"]
	for a: Dictionary in sum.acts:
		lines.append("| %s | %+.1f | %d%% | %d%% | %.0f | %d |" % [a.name, a.level_gap, roundi(a.win_arrival * 100.0),
			roundi(a.win_moderate * 100.0), a.grind_needed, a.walls])
	lines.append("")
	lines.append("| Act | Fight | Kind | Foe top | Team avg / top on arrival | Win on arrival | After moderate grind | Grind to 70 % |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
	for a: Dictionary in sum.acts:
		for f: Dictionary in a.fights:
			lines.append("| %s | %s | %s | %d | %.1f / %.1f | %d%% | %d%% | %s |" % [a.id, f.name, f.kind, f.foe_top, f.arrival_avg, f.arrival_top,
				roundi(f.win_arrival * 100.0), roundi(f.win_moderate * 100.0), ("%.0f" % f.grind_needed) if f.grind_needed < 999.0 else "wall"])
	return "\n".join(lines) + "\n"
