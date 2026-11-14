class_name Region3
extends RefCounted
## Quillmarch, the post-game Era III region (data/region3.json). Read-only helpers over the sheet:
## unlock, the Warden order, the current story chapter and the encounter slots. Flags are passed
## in (GameState.flags in play) so everything here is testable without the autoloads.

const PATH: String = "res://data/region3.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = raw if raw is Dictionary else {}
	return _data

static func is_open(flags: Dictionary) -> bool:
	return bool(flags.get(str(data().get("unlock_flag", "")), false))

## Wardens in the order the player meets them.
static func wardens() -> Array:
	var out: Array = (data().get("wardens", []) as Array).duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.order) < int(b.order))
	return out

static func rift(id: String) -> Dictionary:
	for r: Dictionary in data().get("rifts", []):
		if r.id == id:
			return r
	return {}

## The first Warden whose Rift is still open, or {} when all four are sealed (or the region is shut).
static func next_warden(flags: Dictionary) -> Dictionary:
	if not is_open(flags):
		return {}
	for w: Dictionary in wardens():
		if not bool(flags.get(str(rift(str(w.rift)).get("flag", "")), false)):
			return w
	return {}

## The story chapter in play: the first whose needs flag is set and whose own flag is not.
static func current_chapter(flags: Dictionary) -> Dictionary:
	for c: Dictionary in data().get("story", []):
		if bool(flags.get(str(c.needs), false)) and not bool(flags.get(str(c.sets), false)):
			return c
	return {}

static func route(id: String) -> Dictionary:
	for r: Dictionary in data().get("routes", []):
		if r.id == id:
			return r
	return {}

## The species shown for a slot: its own once it is filled, else the stand-in.
static func slot_species(slot: Dictionary) -> String:
	var own: Variant = slot.get("species")
	return str(own) if own != null and str(own) != "" else str(slot.get("stand_in", ""))

## Slots still waiting for Quillmarch's own Spirlings (none since the Acid and Frost kinds came).
static func open_slots() -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in data().get("routes", []):
		for s: Dictionary in r.slots:
			if s.get("species") == null:
				out.append(str(s.slot))
	for w: Dictionary in data().get("wardens", []):
		for t: Dictionary in w.team:
			if t.has("slot") and t.get("species") == null:
				out.append(str(t.slot))
	return out
