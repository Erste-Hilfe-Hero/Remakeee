class_name EncounterTable
extends RefCounted
## Per-map spawn tables from data/encounters.json:
##   {"fernstair": {"rate": 0.12, "spawns": [{"species": "Zippit", "min": 2, "max": 4, "weight": 30}]}}
## A spawn may name its "ground" ("fern", "reeds", "scree", "water", "cave", or a list): it then
## only steps out of that ground, so ferns and reeds on one map hold different Spirlings
## (area 3 item 1109). Spawns without "ground" appear everywhere on the map.

const PATH: String = "res://data/encounters.json"

static var _tables: Dictionary = {}

## Ground names for the tiles wild Spirlings hide in.
const GROUNDS: Dictionary[int, String] = {
	TilesetFactory.Kind.TALL_GRASS: "fern", TilesetFactory.Kind.REEDS: "reeds",
	TilesetFactory.Kind.SCREE: "scree", TilesetFactory.Kind.WADE: "water",
}
const GROUND_NAMES: Array[String] = ["fern", "reeds", "scree", "water", "cave"]
## Steps after a battle in which nothing new steps out (area 3 item 1111).
const GUARD_STEPS: int = 6
static var _guard: int = 0

## Ground of [param cell] on [param m]: "cave" anywhere in a cave, else from the tile.
static func ground_at(m: MapData, cell: Vector2i) -> String:
	if m.biome == "cave":
		return "cave"
	return GROUNDS.get(m.kind_at(cell), "")

## Grounds a spawn entry appears on ([] = all).
static func grounds_of(spawn: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var g: Variant = spawn.get("ground", [])
	if g is String:
		out.append(g)
	else:
		for x: Variant in g:
			out.append(str(x))
	return out

## Grounds [param species] appears on in table [param id] ([] = everywhere on the map).
static func grounds_for(id: String, species: String) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in table(id).get("spawns", []):
		if str(s.species) == species:
			var g: Array[String] = grounds_of(s)
			if g.is_empty():
				return [] as Array[String]
			for x: String in g:
				if not x in out:
					out.append(x)
	return out

## Starts the quiet steps after a battle.
static func start_guard() -> void:
	_guard = GUARD_STEPS

## Counts one step; true once the quiet steps after the last battle are over.
static func tick_guard() -> bool:
	if _guard > 0:
		_guard -= 1
		return false
	return true

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

## Weight of a spawn entry; species with an element in [param boost] count half again as much
## (seasonal festivals, Season.gd), and species of a running sighting day count several times.
static func weight_of(spawn: Dictionary, boost: Array[int]) -> int:
	# Sighting days (online events, Online 100 point 65) multiply the weight of their species.
	var w: int = int(spawn.get("weight", 1)) * OnlineEvents.sighting_boost(str(spawn.get("species", "")))
	var sd: SpirlingData = Database.species(str(spawn.get("species", "")))
	# A running Lure Scent (pay-to-win step 5, plan point 25) multiplies every rarer kind.
	if sd != null and sd.rarity != "common":
		w = roundi(w * ShopEffects.rare_mult())
	if boost.is_empty():
		return w
	if sd != null and sd.elements.any(func(e: int) -> bool: return e in boost):
		return w * Season.BOOST_NUM
	return w * Season.BOOST_DEN

## Spawns of table [param id] that can step out of [param ground] ("" = any spawn).
static func spawns_on(id: String, ground: String) -> Array:
	var all: Array = table(id).get("spawns", [])
	if ground.is_empty():
		return all
	var out: Array = []
	for s: Dictionary in all:
		var g: Array[String] = grounds_of(s)
		if g.is_empty() or ground in g:
			out.append(s)
	return out if not out.is_empty() else all

## Rolls a wild Spirling, or returns null if the table is empty.
## [param chain] is the saved Gleam chain (GameState.gleam_chain); one Gleam draw follows the Prism one.
static func roll(id: String, rng: RandomNumberGenerator, boost: Array[int] = [], ground: String = "", chain: Dictionary = {}) -> Spirling:
	var spawns: Array = spawns_on(id, ground)
	var total: int = 0
	for s: Dictionary in spawns:
		total += weight_of(s, boost)
	if total <= 0:
		return null
	var pick: int = rng.randi_range(1, total)
	for s: Dictionary in spawns:
		pick -= weight_of(s, boost)
		if pick <= 0:
			var sd: SpirlingData = Database.species(str(s.species))
			if sd == null:
				return null
			var wild := Spirling.new(sd, rng.randi_range(int(s.get("min", 2)), int(s.get("max", 4))), rng)
			# Meeting the same kind again and again raises the Prism chance too (WildRules).
			wild.prism = rng.randf() < WildRules.prism_chance(GleamRules.chain_for(chain, sd.species_name))
			WildRules.roll_held(wild, rng)
			wild.gleam = GleamRules.roll(rng, GleamRules.chain_for(chain, sd.species_name), ShopEffects.gleam_mult())
			return wild
	return null

## Species names that can appear on [param id] (Spirlog Tracker).
static func species_on(id: String) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in table(id).get("spawns", []):
		out.append(str(s.species))
	return out
