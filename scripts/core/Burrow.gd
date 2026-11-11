class_name Burrow
extends RefCounted
## The Burrow: a hollow in the rock of Murk Hollow. The Wayfarer claims it (flag "burrow_claimed")
## and hangs earned trophies on a wall of "wall_slots" places (records["burrow_wall"]). A trophy
## is earned by a flag or a record from data/burrow.json. After "squatter_days" days away a
## squatter has been and gone: it leaves a rude note and "rent_coins" as a welcome-back gift.
## Trophies are never touched.

const DATA_PATH: String = "res://data/burrow.json"
const FLAG: String = "burrow_claimed"
const WALL: String = "burrow_wall"
const VISIT: String = "burrow_visit"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)))
	return _data

static func claimed() -> bool:
	return GameState.has_flag(FLAG)

static func claim() -> void:
	GameState.set_flag(FLAG)

static func trophy(id: String) -> Dictionary:
	for t: Dictionary in data().get("trophies", []):
		if str(t.id) == id:
			return t
	return {}

## A record counts by its number, or by its size for a list or a table.
static func _record_value(key: String) -> int:
	var v: Variant = GameState.records.get(key, 0)
	if v is Dictionary or v is Array:
		return v.size()
	return int(v)

static func earned(t: Dictionary) -> bool:
	if t.has("flag"):
		return GameState.has_flag(str(t.flag))
	if t.has("record"):
		return _record_value(str(t.record)) >= int(t.get("min", 1))
	return false

static func earned_ids() -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in data().get("trophies", []):
		if earned(t):
			out.append(str(t.id))
	return out

static func wall() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in GameState.records.get(WALL, []):
		out.append(str(id))
	return out

## Hangs [param id] on the wall; false when it is not earned, already up, or the wall is full.
static func hang(id: String) -> bool:
	var w: Array[String] = wall()
	if id in w or w.size() >= int(data().get("wall_slots", 3)) or not earned(trophy(id)):
		return false
	w.append(id)
	GameState.records[WALL] = w
	return true

static func take_down(id: String) -> void:
	var w: Array[String] = wall()
	w.erase(id)
	GameState.records[WALL] = w

static func _day(day: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(day) / 86400)

## Called on each visit on [param day] ("YYYY-MM-DD"). Returns {} when the Wayfarer was not
## away long enough, else {"note": String, "coins": int}: the squatter's note (translated) and the
## rent it left, already added to GameState.money.
static func visit(day: String, rng: RandomNumberGenerator) -> Dictionary:
	var last: String = str(GameState.records.get(VISIT, ""))
	GameState.records[VISIT] = day
	var d: Dictionary = data()
	if last.is_empty() or _day(day) - _day(last) < int(d.get("squatter_days", 7)):
		return {}
	var notes: Array = d.get("squatter_notes", [])
	var coins: int = int(d.get("rent_coins", 0))
	GameState.money += coins
	var note: String = Loc.t(str(notes[rng.randi() % notes.size()])) if not notes.is_empty() else ""
	return {"note": note, "coins": coins}
