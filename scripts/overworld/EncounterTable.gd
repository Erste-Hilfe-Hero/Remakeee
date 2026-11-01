class_name EncounterTable
extends RefCounted
## Per-map spawn tables from data/encounters.json:
##   {"fernstair": {"rate": 0.12, "spawns": [{"species": "Zippit", "min": 2, "max": 4, "weight": 30}]}}

const PATH: String = "res://data/encounters.json"

static var _tables: Dictionary = {}

static func table(id: String) -> Dictionary:
	if _tables.is_empty() and FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_tables = raw
	return _tables.get(id, {})

## All table ids in data/encounters.json.
static func table_ids() -> Array[String]:
	table("")
	var out: Array[String] = []
	for k: Variant in _tables.keys():
		out.append(str(k))
	return out

## Chance per step in tall grass.
static func rate(id: String) -> float:
	return float(table(id).get("rate", 0.0))

## Rolls a wild Spirling, or returns null if the table is empty.
static func roll(id: String, rng: RandomNumberGenerator) -> Spirling:
	var spawns: Array = table(id).get("spawns", [])
	var total: int = 0
	for s: Dictionary in spawns:
		total += int(s.get("weight", 1))
	if total <= 0:
		return null
	var pick: int = rng.randi_range(1, total)
	for s: Dictionary in spawns:
		pick -= int(s.get("weight", 1))
		if pick <= 0:
			var sd: SpirlingData = Database.species(str(s.species))
			if sd == null:
				return null
			var wild := Spirling.new(sd, rng.randi_range(int(s.get("min", 2)), int(s.get("max", 4))), rng)
			wild.prism = rng.randf() < Spirling.PRISM_CHANCE
			return wild
	return null

## Species names that can appear on [param id] (Spirlog Tracker).
static func species_on(id: String) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in table(id).get("spawns", []):
		out.append(str(s.species))
	return out
