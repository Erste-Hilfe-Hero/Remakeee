class_name Released
extends RefCounted
## Released Spirlings (plan items 1136, 1137): letting one go leaves a farewell letter, and the
## Spirling is remembered (records["released"], at most max entries). Entering the map it came
## from can show it once a day at the edge of the path, as a notice.

const KEY: String = "released"

static func data() -> Dictionary:
	return IdeasC.section("released")

static func list() -> Array:
	return GameState.records.get(KEY, [])

static func remember(s: Spirling) -> void:
	var all: Array = list().duplicate()
	all.append({"name": s.display_name(), "species": s.data.species_name, "map": s.origin_map, "seen": ""})
	while all.size() > int(data().get("max", 30)):
		all.pop_front()
	GameState.records[KEY] = all

## The farewell letter for [param s].
static func letter(s: Spirling) -> Array[String]:
	var home: String = Spirling.place_name(s.origin_map) if not s.origin_map.is_empty() else ""
	var src: Array = data().get("letter" if not home.is_empty() else "letter_wild", [])
	var out: Array[String] = []
	for i: int in src.size():
		var t: String = Loc.t(str(src[i]))
		if i == 0:
			t = t % ([s.display_name(), home] if not home.is_empty() else [s.display_name()])
		out.append(t)
	return out

## Sighting notices for [param map_id] on [param day]; each Spirling at most once a day.
static func sightings(map_id: String, day: String, rng: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = []
	var all: Array = list()
	if all.is_empty():
		return out
	var changed: bool = false
	for e: Variant in all:
		var d: Dictionary = GameState.as_dict(e)
		if str(d.get("map", "")) != map_id or str(d.get("seen", "")) == day:
			continue
		if rng.randf() < float(data().get("sight_chance", 0.0)):
			d["seen"] = day
			changed = true
			out.append(Loc.t(str(data().get("sighting", "%s"))) % str(d.get("name", "")))
	if changed:
		GameState.records[KEY] = all
	return out
