class_name Reserve
extends RefCounted
## Hollowgate Reserve: a fenced wildlife park run by a smuggling ring (data/reserve.json). The
## entry fee buys a run of sightings and a few Echo calls. No fighting: per sighting the player
## sets bait, rattles the fence, makes an Echo call or moves on, and after each action the
## Spirling may slip away. Odds are never shown (LEGAL.md). A snitch may spook one sighting;
## that only loses the sighting, never anything the player already has.

const DATA_PATH: String = "res://data/reserve.json"
const VISITS: String = "reserve_visits"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)))
	return _data

## Pays the fee and opens a run: {"sightings", "calls"}, or {} when the money is short.
static func enter() -> Dictionary:
	var d: Dictionary = data()
	var fee: int = int(d.get("entry_fee", 0))
	if GameState.money < fee:
		return {}
	GameState.money -= fee
	GameState.records[VISITS] = int(GameState.records.get(VISITS, 0)) + 1
	return {"sightings": int(d.get("sightings", 6)), "calls": int(d.get("calls", 5))}

## Rolls the next sighting of [param run] (uses one up): {"species", "level", "bait", "rattle",
## "snitched"}. A snitched sighting is spooked before the player can act.
static func sighting(run: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = data()
	run["sightings"] = maxi(0, int(run.get("sightings", 0)) - 1)
	var table: Array = d.get("table", [])
	var total: int = 0
	for row: Dictionary in table:
		total += int(row.get("weight", 1))
	var roll: int = rng.randi_range(1, maxi(1, total))
	var pick: Dictionary = table[0]
	for row: Dictionary in table:
		roll -= int(row.get("weight", 1))
		if roll <= 0:
			pick = row
			break
	var rings: Array = pick.get("ring", [10, 10])
	return {"species": str(pick.species), "level": rng.randi_range(int(rings[0]), int(rings[1])),
		"bait": 0, "rattle": 0, "snitched": rng.randf() < float(d.get("snitch_chance", 0.0))}

## Chance the Spirling slips away after an action (never shown).
static func flee_odds(s: Dictionary) -> float:
	var d: Dictionary = data()
	var f: float = float(d.get("flee_base", 0.15))
	f *= pow(1.0 - float(d.get("bait_calm", 0.4)), int(s.get("bait", 0)))
	f *= pow(1.0 + float(d.get("rattle_jumpy", 0.6)), int(s.get("rattle", 0)))
	return clampf(f, 0.02, 0.9)

## Chance an Echo call of [param score] (0..1) reaches the Spirling (never shown).
static func reach_odds(s: Dictionary, score: float) -> float:
	var d: Dictionary = data()
	var sd: SpirlingData = Database.species(str(s.species))
	var c: float = (sd.bond_rate if sd != null else 0.3) * clampf(score, 0.0, 1.0)
	c *= pow(1.0 - float(d.get("bait_dull", 0.25)), int(s.get("bait", 0)))
	c *= pow(1.0 + float(d.get("rattle_keen", 0.5)), int(s.get("rattle", 0)))
	return clampf(c, 0.0, float(d.get("max_bond", 0.9)))

## One action on sighting [param s]: "bait", "rattle" or "call" (with the Echo [param score]).
## Returns {"bonded": bool, "fled": bool}. A call uses one of the run's calls.
static func act(run: Dictionary, s: Dictionary, action: String, rng: RandomNumberGenerator, score: float = 0.0) -> Dictionary:
	var cap: int = int(data().get("max_stacks", 3))
	match action:
		"bait":
			s["bait"] = mini(cap, int(s.get("bait", 0)) + 1)
		"rattle":
			s["rattle"] = mini(cap, int(s.get("rattle", 0)) + 1)
		"call":
			if int(run.get("calls", 0)) <= 0:
				return {"bonded": false, "fled": false}
			run["calls"] = int(run.calls) - 1
			if rng.randf() < reach_odds(s, score):
				return {"bonded": true, "fled": false}
	return {"bonded": false, "fled": rng.randf() < flee_odds(s)}

## The Spirling of a reached sighting, ready to join.
static func spirling_of(s: Dictionary, rng: RandomNumberGenerator) -> Spirling:
	return Spirling.new(Database.species(str(s.species)), int(s.level), rng)

static func over(run: Dictionary) -> bool:
	return int(run.get("sightings", 0)) <= 0 or int(run.get("calls", 0)) <= 0
