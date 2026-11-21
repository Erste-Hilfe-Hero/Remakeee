class_name Breeding
extends RefCounted
## The family business: a young Spirling woken from an Echo Core inherits Spark and heirloom arts
## from the two Spirlings that sang it (data/breeding.json). snapshot() stores what the parents
## can pass on when the core forms, so releasing or changing a parent later changes nothing.
## A match contract from the matchmaker passes on more, unless she sold the same match twice:
## then only the contract bonus is lost, never the young Spirling or the plain inheritance.

const DATA_PATH: String = "res://data/breeding.json"
const CONTRACTS: String = "match_contracts"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)))
	return _data

## What [param a] and [param b] can pass on: both Spark tables and their art names.
static func snapshot(a: Spirling, b: Spirling) -> Dictionary:
	var arts: Array[String] = []
	for s: Spirling in [a, b]:
		for m: MoveData in s.moves:
			if not m.move_name in arts:
				arts.append(m.move_name)
	return {"spark": [a.spark.duplicate(), b.spark.duplicate()], "arts": arts}

## A carried core that has no contract yet, newest first, or {}.
static func open_core() -> Dictionary:
	for i: int in range(GameState.echo_cores.size() - 1, -1, -1):
		if not bool(GameState.echo_cores[i].get("contract", false)):
			return GameState.echo_cores[i]
	return {}

static func seal_contract(core: Dictionary) -> bool:
	var fee: int = int(data().get("contract_fee", 0))
	if core.is_empty() or bool(core.get("contract", false)) or GameState.money < fee:
		return false
	GameState.money -= fee
	core["contract"] = true
	GameState.records[CONTRACTS] = int(GameState.records.get(CONTRACTS, 0)) + 1
	return true

## Arts of the heir snapshot that [param kid] could carry: they share one of its elements
## and it does not know them yet.
static func heirloom_candidates(kid: Spirling, heir: Dictionary) -> Array[MoveData]:
	var out: Array[MoveData] = []
	for n: Variant in heir.get("arts", []):
		var m: MoveData = Database.move(str(n))
		if m == null or not m.element in kid.data.elements:
			continue
		var known: bool = false
		for k: MoveData in kid.moves:
			known = known or k.move_name == m.move_name
		if not known:
			out.append(m)
	return out

## Passes the inheritance of [param core] on to [param kid].
## Returns {"betrayed": bool, "stats": Array[String], "arts": Array[String], "line": String}.
static func inherit(kid: Spirling, core: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = data()
	var contract: bool = bool(core.get("contract", false))
	var betrayed: bool = contract and rng.randf() < float(d.get("betray_chance", 0.0))
	var bonus: bool = contract and not betrayed
	var heir: Dictionary = core.get("heir", {})
	var sparks: Array = heir.get("spark", [])
	var stats: Array[String] = []
	if sparks.size() == 2:
		var keys: Array[String] = Spirling.STAT_KEYS.duplicate()
		for i: int in range(keys.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var t: String = keys[i]
			keys[i] = keys[j]
			keys[j] = t
		var n: int = int(d.get("contract_spark_stats" if bonus else "spark_stats", 2))
		for key: String in keys.slice(0, n):
			var best: int = maxi(int((sparks[0] as Dictionary).get(key, 0)), int((sparks[1] as Dictionary).get(key, 0)))
			kid.spark[key] = clampi(maxi(int(kid.spark.get(key, 0)), best), 0, Spirling.SPARK_MAX)
			stats.append(key)
		kid.hp = kid.max_hp()
	var arts: Array[String] = []
	var pool: Array[MoveData] = heirloom_candidates(kid, heir)
	var count: int = mini(pool.size(), int(d.get("contract_heirloom_arts" if bonus else "heirloom_arts", 1)))
	for i: int in count:
		var m: MoveData = pool[i]
		if kid.moves.size() < Spirling.MAX_MOVES:
			kid.moves.append(m)
		else:
			kid.moves[Spirling.MAX_MOVES - 1 - i] = m
		arts.append(m.move_name)
	var line: String = ""
	if betrayed:
		var fams: Array = d.get("rival_families", ["someone"])
		line = Loc.t(str(d.get("betrayed_line", ""))) % Loc.t(str(fams[rng.randi_range(0, fams.size() - 1)]))
	elif bonus:
		line = Loc.t(str(d.get("honoured_line", "")))
	return {"betrayed": betrayed, "stats": stats, "arts": arts, "line": line}
