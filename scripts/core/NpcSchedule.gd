class_name NpcSchedule
extends RefCounted
## Day plans and short walks for townsfolk (area 3 items 1212-1216).
##
## An NPC in a map file may carry
##   "schedule": [{"phase": "dusk" | ["dawn", "day"], "map": "<id>", "x", "y", "facing",
##                 "walk": [[x, y], ...], "away": true}]
##   "walk": [[x, y], ...]
## The first entry whose phase matches the time of day says where the person is: on another map
## ("map", default the home map), on another cell, or not out at all ("away": indoors, asleep).
## No matching entry: the person stands at the home cell (x, y). "walk" is a short route of
## neighbouring cells starting at that cell; the person walks it to the end and back, slowly,
## and waits while the player (or anyone) is in the way. Wayfarers never get a plan.

## What [param def] (an NPC of [param home]) does at [param phase]:
## {"map", "x", "y", "facing", "walk": Array[Vector2i]} or {} when away.
static func place_for(def: Dictionary, home: String, phase: int) -> Dictionary:
	var out: Dictionary = {"map": home, "x": int(def.get("x", 0)), "y": int(def.get("y", 0)),
		"facing": str(def.get("facing", "down")), "walk": cells(def.get("walk", []))}
	for e: Variant in def.get("schedule", []):
		if not e is Dictionary or not phase_matches(e, phase):
			continue
		var entry: Dictionary = e
		if bool(entry.get("away", false)):
			return {}
		out = {"map": str(entry.get("map", home)), "x": int(entry.get("x", out.x)), "y": int(entry.get("y", out.y)),
			"facing": str(entry.get("facing", out.facing)), "walk": cells(entry.get("walk", []))}
		break
	return out

static func phase_matches(entry: Dictionary, phase: int) -> bool:
	var p: Variant = entry.get("phase", [])
	var names: Array = p if p is Array else [p]
	return DayCycle.phase_name(phase) in names

static func cells(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if raw is Array:
		for c: Variant in raw:
			if c is Array and (c as Array).size() >= 2:
				out.append(Vector2i(int(c[0]), int(c[1])))
	return out

static func has_plan(def: Dictionary) -> bool:
	return def.has("schedule") or def.has("walk")

## NPC definitions present on [param m] at [param phase]: its own people that are home (moved to
## their cell for the phase) plus visitors from other maps. Each copy carries "home" (the map it
## belongs to) and "walk_cells". Flags and phase_only are left to the caller.
static func defs_for(m: MapData, phase: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def: Dictionary in m.npcs:
		var d: Dictionary = _placed(def, m.id, phase)
		if not d.is_empty() and str(d.home_place) == m.id:
			out.append(d)
	for v: Array in visitors(m.id):
		var d: Dictionary = _placed(v[1], str(v[0]), phase)
		if not d.is_empty() and str(d.home_place) == m.id:
			out.append(d)
	return out

static func _placed(def: Dictionary, home: String, phase: int) -> Dictionary:
	if not has_plan(def):
		var plain: Dictionary = def.duplicate()
		plain["home"] = home
		plain["home_place"] = home
		plain["walk_cells"] = [] as Array[Vector2i]
		return plain
	var p: Dictionary = place_for(def, home, phase)
	if p.is_empty():
		return {}
	var d: Dictionary = def.duplicate()
	d["x"] = p.x
	d["y"] = p.y
	d["facing"] = p.facing
	d["home"] = home
	d["home_place"] = p.map
	d["walk_cells"] = p.walk
	return d

static var _visitor_index: Dictionary = {}
static var _indexed: bool = false

## [home map, def] of people from other maps whose plan ever brings them to [param map_id].
static func visitors(map_id: String) -> Array:
	if not _indexed:
		_indexed = true
		for id: String in MapData.all_ids():
			if id.contains(MapData.FLOOR_SEP):
				continue
			var m: MapData = MapData.load_map(id)
			if m == null:
				continue
			for def: Dictionary in m.npcs:
				for e: Variant in def.get("schedule", []):
					if e is Dictionary and (e as Dictionary).has("map") and str(e.map) != id:
						var arr: Array = _visitor_index.get(str(e.map), [])
						if not arr.any(func(v: Array) -> bool: return v[1] == def):
							arr.append([id, def])
						_visitor_index[str(e.map)] = arr
	return _visitor_index.get(map_id, [])

## Drops the visitor index (tests that build maps on the fly).
static func reset() -> void:
	_visitor_index.clear()
	_indexed = false
