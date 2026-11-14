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

# --- Ranks, placement, shield, quit penalty (Online 100, points 12-13, 16-20) ------------------
# The server does the same in SQL (20261111000030_league_ranks.sql) from server_config.league_ranks.

const RANKS_PATH: String = "res://data/league_ranks.json"
const RANK_NAMES: Dictionary = {"apprentice": "Apprentice", "runner": "Runner", "fixer": "Fixer",
	"broker": "Broker", "captain": "Captain", "boss": "Boss", "mapmaster": "Map Master"}

## data/league_ranks.json.
static func ranks_config() -> Dictionary:
	var f := FileAccess.open(RANKS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}

## Rank 0-6 for [param rating], or -1 while placement battles are left (like public._league_rank).
static func rank(cfg: Dictionary, rating: float, games: int) -> int:
	if games < int(cfg.get("placement_games", 5)):
		return -1
	var out: int = 0
	var ranks: Array = cfg.get("ranks", [])
	for i: int in ranks.size():
		if rating >= float(ranks[i].floor):
			out = i
	return out

static func rank_id(cfg: Dictionary, r: int) -> String:
	var ranks: Array = cfg.get("ranks", [])
	return str(ranks[r].id) if r >= 0 and r < ranks.size() else ""

## "Captain" for a rank number, "Placement" while unranked.
static func rank_name(cfg: Dictionary, r: int) -> String:
	return str(RANK_NAMES.get(rank_id(cfg, r), "Placement"))

## AI tier of the rival's echo for a player of rank [param r] (KAMPF_PLAN_1000 item 876, like
## public._league_echo_ai): ranks[r].echo_ai of data/league_ranks.json, placement counts as the
## first rank; [param fallback] (server_config league_ai) when the rank sets none.
static func echo_ai(cfg: Dictionary, r: int, fallback: int) -> int:
	var ranks: Array = cfg.get("ranks", [])
	if ranks.is_empty():
		return fallback
	var row: Variant = ranks[clampi(r, 0, ranks.size() - 1)]
	return clampi(int((row as Dictionary).get("echo_ai", fallback)), 1, 3) if row is Dictionary else fallback

## Rating and shield after one rated battle (like public._league_shield): after a promotion the
## next shield_games battles cannot drop the player below the new rank's floor.
static func after_battle(cfg: Dictionary, old_rating: float, new_rating: float, games_after: int, shield: int) -> Dictionary:
	var old_rank: int = rank(cfg, old_rating, games_after - 1)
	var rating: float = new_rating
	var sh: int = shield
	if sh > 0 and old_rank >= 0:
		var fl: float = float(cfg.ranks[old_rank].floor)
		if rating < fl:
			rating = fl
		sh -= 1
	var new_rank: int = rank(cfg, rating, games_after)
	if old_rank >= 0 and new_rank > old_rank:
		sh = int(cfg.get("shield_games", 3))
	return {"rating": rating, "shield": sh}

## Seconds a player still waits before searching, after [param quits] left matches in a day,
## the newest [param since] seconds ago (like public._league_quit_wait).
static func quit_wait(cfg: Dictionary, quits: int, since: int) -> int:
	var free: int = int(cfg.get("quit_free", 2))
	if quits < free:
		return 0
	var w: int = mini(int(cfg.get("quit_wait", 60)) * int(pow(2, mini(quits - free, 10))), int(cfg.get("quit_wait_max", 900)))
	return maxi(0, w - since)

## The season reward for a final rank: {item, count}, or {} while unranked.
static func reward(cfg: Dictionary, r: int) -> Dictionary:
	var ranks: Array = cfg.get("ranks", [])
	return (ranks[r].reward as Dictionary).duplicate() if r >= 0 and r < ranks.size() else {}
