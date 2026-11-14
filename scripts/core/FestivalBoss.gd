class_name FestivalBoss
extends RefCounted
## Festival bosses (docs/KAMPF_PLAN_1000.md item 437). While a festival runs (Festival.active),
## the crier offers a grown echo of a Rift heart the player has already beaten, fought under that
## heart's boss rules. The first win per festival and year pays festival ribbons; it is kept in
## records["festival_boss"][<festival key>] = true. Values in data/festival_bosses.json.

const PATH: String = "res://data/festival_bosses.json"
const KEY: String = "festival_boss"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(PATH)))
	return _data

## {"boss", "species"} of festival [param fest_id], or {}.
static func entry(fest_id: String) -> Dictionary:
	return GameState.as_dict((data().get("festivals", {}) as Dictionary).get(fest_id, {}))

## True once the player has beaten the heart behind [param fest_id]'s echo.
static func unlocked(fest_id: String, records: Dictionary) -> bool:
	var e: Dictionary = entry(fest_id)
	return not e.is_empty() and int(BossRules.stats(records, str(e.boss)).get("wins", 0)) > 0

## True once the echo of festival [param key] ("<id>_<year>") was beaten.
static func won(key: String, records: Dictionary) -> bool:
	return bool((records.get(KEY, {}) as Dictionary).get(key, false))

## The echo's ring for a party whose best ring is [param best].
static func ring_for(best: int) -> int:
	return clampi(best + int(data().get("ring_over", 2)), int(data().get("ring_min", 20)), Spirling.STORY_RING)

## The echo of [param fest_id] as a one-Spirling team (empty when the data is broken).
static func team(fest_id: String, best_ring: int, rng: RandomNumberGenerator) -> Array[Spirling]:
	return IdeasC.team([entry(fest_id).get("species", "")], ring_for(best_ring), rng)

## Books a win against the echo of festival [param key]; true only for the first one.
static func note_win(key: String, records: Dictionary) -> bool:
	if won(key, records):
		return false
	var all: Dictionary = (records.get(KEY, {}) as Dictionary).duplicate()
	all[key] = true
	records[KEY] = all
	return true
