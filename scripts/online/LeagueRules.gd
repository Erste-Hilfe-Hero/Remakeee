class_name LeagueRules
extends RefCounted
## League rules shared by the game and LocalBackend (plan area 7, items 2731-2734, 2748, 2771).
## The server does the same in SQL (_league_fair_row, _league_team, _league_tier); a test
## compares both for every species (tools/online/test_referee.sh).

const FAIR: String = "fair"
const OPEN: String = "open"
const FAIR_RING: int = 50
const TEAM_MAX: int = 5
## Tier names, lowest first; each has three steps (I, II, III).
const TIERS: Array[String] = ["Spark", "Ember", "Flame", "Glow", "Beacon"]
const STEPS: Array[String] = ["I", "II", "III"]

## Tier number 0-14 for a rating (like public._league_tier).
static func tier(rating: float) -> int:
	return clampi(int(floor((rating - 1200.0) / 70.0)), 0, 14)

## "Ember II" for a tier number.
static func tier_name(t: int) -> String:
	var i: int = clampi(t, 0, 14)
	return "%s %s" % [TIERS[i / 3], STEPS[i % 3]]

## Moves [param sd] can know at [param ring]: its own learnset and its earlier forms'.
static func learnable(sd: SpirlingData, ring: int) -> Array[String]:
	var out: Array[String] = []
	var cur: SpirlingData = sd
	var depth: int = 0
	while cur != null and depth <= 5:
		for i: int in cur.learnset_levels.size():
			if cur.learnset_levels[i] <= ring and not out.has(cur.learnset_moves[i].move_name):
				out.append(cur.learnset_moves[i].move_name)
		cur = Database.earlier_form(cur)
		depth += 1
	return out

## One fair league row: Ring 50, base stats, only learnable moves (like public._league_fair_row).
static func fair_row(species_name: String, moves: Variant, ring: int = FAIR_RING) -> Dictionary:
	var sd: SpirlingData = Database.species(species_name)
	if sd == null:
		return {}
	var ok: Array[String] = learnable(sd, ring)
	var picked: Array = []
	for mv: Variant in (moves as Array if moves is Array else []):
		var name: String = str(mv)
		if ok.has(name) and not picked.has(name) and picked.size() < 4:
			picked.append(name)
	if picked.is_empty():
		for md: MoveData in sd.default_moves(ring, 4):
			picked.append(md.move_name)
	return {"species": species_name, "level": ring, "moves": picked}

## Builds a league team from a saved echo team (like public._league_team).
## [param pick] lists species names or {species, moves}. Returns {"team"} or {"error"}.
static func build_team(saved: Array, league: String, pick: Variant, ring: int = FAIR_RING, level_max: int = 60) -> Dictionary:
	if not pick is Array or (pick as Array).is_empty():
		return {"error": "empty_team"}
	if (pick as Array).size() > TEAM_MAX:
		return {"error": "bad_team"}
	var used: Array[int] = []
	var seen: Array[String] = []
	var team: Array = []
	for p: Variant in pick:
		var sp: String = str((p as Dictionary).get("species", "")) if p is Dictionary else str(p)
		if Database.species(sp) == null:
			return {"error": "unknown_species"}
		if seen.has(sp):
			return {"error": "duplicate_species"}
		seen.append(sp)
		var idx: int = -1
		for i: int in saved.size():
			if saved[i] is Dictionary and str(saved[i].get("species", "")) == sp and not used.has(i):
				idx = i
				break
		if idx < 0:
			return {"error": "not_in_team"}
		used.append(idx)
		if league == FAIR:
			team.append(fair_row(sp, (p as Dictionary).get("moves", []) if p is Dictionary else [], ring))
		else:
			var row: Dictionary = saved[idx]
			team.append({"species": sp, "level": clampi(int(row.get("level", 1)), 1, level_max),
				"moves": row.get("moves", []) if row.get("moves") is Array else []})
	return {"team": team}
