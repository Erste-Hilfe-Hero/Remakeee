class_name Transit
extends RefCounted
## Boat and coach routes (area 3 items 1187-1191, 1289): the Lake Line, the Valley Coach and the
## ferry to Corvane. The routes live in data/world_layout.json under "lines":
##   {"<line>": {"name", "kind": "boat" | "coach" | "ferry" | "rail" | "rope", "story": bool,
##               "open_flag": "<flag>"?, "stops": {"<map>": [x, y, facing]}}}
## A stop opens once the player has reached its map on foot (item 1190): arriving there sets the
## flag "stop_<map>". A rest spot already used there counts as well, for saves from before the
## routes. Trips are short scenes (TripScene); the player sits in the boat or the coach and is
## never carried by a Spirling. Lines marked "story" (the Corvane ferry) are run by their own
## dialogue and are not offered at the landing. A line with an "open_flag" (the mountain railway
## from the Greyreach to Ashmere, opened by act2_end) runs to all its stops once the flag is set,
## and to none before.

const LAYOUT_PATH: String = "res://data/world_layout.json"
const KINDS: Array[String] = ["boat", "coach", "ferry", "rail", "rope"]

static var _cache: Dictionary = {}

## All lines by id.
static func lines() -> Dictionary:
	if _cache.is_empty() and FileAccess.file_exists(LAYOUT_PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
		if raw is Dictionary:
			_cache = (raw as Dictionary).get("lines", {})
	return _cache

static func line(id: String) -> Dictionary:
	return lines().get(id, {})

static func stops(id: String) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in (line(id).get("stops", {}) as Dictionary):
		out.append(str(k))
	return out

static func stop_flag(map_id: String) -> String:
	return "stop_" + map_id

## True if [param map_id] is a stop of any line.
static func is_stop(map_id: String) -> bool:
	for id: String in lines():
		if map_id in stops(id):
			return true
	return false

## Where the trip ends on [param map_id]: {"cell": Vector2i, "facing": String}, or {}.
static func arrival(id: String, map_id: String) -> Dictionary:
	var a: Variant = (line(id).get("stops", {}) as Dictionary).get(map_id, [])
	if not a is Array or (a as Array).size() < 2:
		return {}
	return {"cell": Vector2i(int(a[0]), int(a[1])), "facing": str(a[2]) if a.size() > 2 else "down"}

## True if the stop on [param map_id] is open (reached on foot once).
static func stop_open(map_id: String, flags: Dictionary, rests: Dictionary = {}) -> bool:
	return bool(flags.get(stop_flag(map_id), false)) or rests.has(map_id)

## Stops of [param id] the player can travel to from [param here], in route order.
static func open_stops(id: String, here: String, flags: Dictionary, rests: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var gate: String = str(line(id).get("open_flag", ""))
	if not gate.is_empty() and not bool(flags.get(gate, false)):
		return out
	for s: String in stops(id):
		if s != here and (not gate.is_empty() or stop_open(s, flags, rests)):
			out.append(s)
	return out

## Line for a trip scene: "The Lake Line boat rows across the water to Reedhaven."
static func trip_line(kind: String, place: String) -> String:
	place = Loc.t(place)
	match kind:
		"coach":
			return Loc.t("The coach rattles along the valley road to %s.") % place
		"ferry":
			return Loc.t("The ferry crosses the grey lake to %s.") % place
		"rail":
			return Loc.t("The mountain railway climbs through the clouds to %s.") % place
		"rope":
			return Loc.t("The basket creaks down the rope to %s.") % place
	return Loc.t("The boat rows across the lake to %s.") % place

## What the boatman or the driver says when no other stop is open yet.
static func no_stops_line(kind: String) -> String:
	if kind == "coach":
		return "Driver: I only stop where you've been on foot first. Walk the valley, then we'll drive it."
	if kind == "rail":
		return "Conductor: No trains until the line is cleared. The guild will send word."
	return "Boatman: I only row to landings you've walked to yourself. Find them first, then I know the way."
