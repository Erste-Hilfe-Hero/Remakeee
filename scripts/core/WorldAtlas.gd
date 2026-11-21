class_name WorldAtlas
extends RefCounted
## What the world map knows (area 3 items 1242-1247): the places of data/world_layout.json,
## which of them the player has visited (any cell seen there or in a house inside it) or only
## sighted (next to a visited place in the same region, or a stop of a line that runs from one),
## and the facts the
## detail page shows. Pure data; WorldMapView draws it and WorldMapMenu runs it.

enum Known { UNKNOWN, SIGHTED, VISITED }

static var _layout: Dictionary = {}

static func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = WorldValidator.load_layout()
	return _layout

## Places with a grid cell (not interiors), by id.
static func places() -> Dictionary:
	var out: Dictionary = {}
	var maps: Dictionary = layout().get("maps", {})
	for id: String in maps:
		if not (maps[id] as Dictionary).has("inside"):
			out[id] = maps[id]
	return out

static func place_of(map_id: String) -> String:
	return WorldValidator.layout_place(layout().get("maps", {}), map_id)

## Grid cell of a place on the whole world map (region origin + position).
static func grid_cell(place: String) -> Vector2i:
	var p: Dictionary = places().get(place, {})
	var r: Dictionary = (layout().get("regions", {}) as Dictionary).get(str(p.get("region", "")), {})
	var o: Array = r.get("origin", [0, 0])
	var pos: Array = p.get("pos", [0, 0])
	return Vector2i(int(o[0]) + int(pos[0]), int(o[1]) + int(pos[1]))

## Size of the whole grid in cells (all regions).
static func grid_size() -> Vector2i:
	var s := Vector2i.ZERO
	for r: Variant in (layout().get("regions", {}) as Dictionary).values():
		var o: Array = (r as Dictionary).get("origin", [0, 0])
		var sz: Array = (r as Dictionary).get("size", [0, 0])
		s.x = maxi(s.x, int(o[0]) + int(sz[0]))
		s.y = maxi(s.y, int(o[1]) + int(sz[1]))
	return s

## Place at grid cell [param c], or "".
static func place_at(c: Vector2i) -> String:
	for id: String in places():
		if grid_cell(id) == c:
			return id
	return ""

## Every map file that belongs to [param place] (itself and the houses inside it).
static func maps_of(place: String) -> Array[String]:
	var out: Array[String] = [place]
	var maps: Dictionary = layout().get("maps", {})
	for id: String in maps:
		if str((maps[id] as Dictionary).get("inside", "")) == place:
			out.append(id)
	return out

static func is_visited(place: String, current: String = "") -> bool:
	for id: String in maps_of(place):
		if id == current or Survey.visited(id):
			return true
		for k: Variant in GameState.map_cells:
			if str(k).begins_with(id + MapData.FLOOR_SEP) and Survey.visited(str(k)):
				return true
	return false

## Places next to [param place]: neighbours plus the other stops of its lines.
static func links_of(place: String) -> Array[String]:
	var out: Array[String] = []
	for n: Variant in (places().get(place, {}) as Dictionary).get("neighbours", []):
		out.append(str(n))
	for l: String in Transit.lines():
		var st: Array[String] = Transit.stops(l)
		if place in st:
			for s: String in st:
				if s != place and not s in out:
					out.append(s)
	return out

## Known state of every place for the player now.
static func known(current: String = "") -> Dictionary:
	var out: Dictionary = {}
	for id: String in places():
		out[id] = Known.VISITED if is_visited(id, place_of(current) if not current.is_empty() else "") else Known.UNKNOWN
	for id: String in places():
		if out[id] != Known.VISITED:
			continue
		var region: String = str((places()[id] as Dictionary).get("region", ""))
		for n: String in links_of(id):
			# Across the lake stays hidden until the player has been there (the ferry).
			if out.has(n) and out[n] == Known.UNKNOWN and str((places()[n] as Dictionary).get("region", "")) == region:
				out[n] = Known.SIGHTED
	return out

## Survey share of a place: its own map (the top level), 0-100.
static func percent(place: String) -> int:
	return Survey.percent(MapData.load_map(place)) if MapData.exists(place) else 0

## Hidden finds taken and total on a place and its floors and houses: [found, total].
static func finds(place: String) -> Array[int]:
	var found: int = 0
	var total: int = 0
	for id: String in maps_of(place):
		if not MapData.exists(id):
			continue
		var top: MapData = MapData.load_map(id)
		for f: int in top.floor_count:
			var m: MapData = MapData.load_map(MapData.floor_id(id, f)) if f > 0 else top
			if m == null:
				continue
			for sc: Dictionary in m.secrets:
				total += 1
				if GameState.has_flag(str(sc.get("flag", ""))):
					found += 1
	return [found, total]

## Species of the place's encounter tables: seen ones by name, others as "???", sorted.
static func species(place: String) -> Array[String]:
	var names: Dictionary = {}
	for id: String in maps_of(place):
		if not MapData.exists(id):
			continue
		var m: MapData = MapData.load_map(id)
		if m.encounter_table.is_empty():
			continue
		for sp: Variant in EncounterTable.table(m.encounter_table).get("spawns", []):
			names[str((sp as Dictionary).get("species", ""))] = true
	var out: Array[String] = []
	var hidden: int = 0
	for n: String in names:
		if bool((GameState.spirlog.get(n, {}) as Dictionary).get("seen", false)):
			out.append(n)
		else:
			hidden += 1
	out.sort()
	for i: int in hidden:
		out.append("???")
	return out

## Symbols of a place for the map: "heal", "stop", "rift".
static func symbols(place: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in maps_of(place):
		if MapData.exists(id) and MapData.load_map(id).heal_point.x >= 0 and not "heal" in out:
			out.append("heal")
	if Transit.is_stop(place):
		out.append("stop")
	if str((places().get(place, {}) as Dictionary).get("kind", "")) == "rift":
		out.append("rift")
	return out

## The detail page text (item 1247).
static func detail_text(place: String) -> String:
	var m: MapData = MapData.load_map(place)
	var lines: PackedStringArray = []
	lines.append(Loc.t(m.display_name) if m != null else place)
	lines.append(Loc.t("Mapped: %d%%") % percent(place))
	var f: Array[int] = finds(place)
	lines.append(Loc.t("Finds: %d/%d") % [f[0], f[1]])
	if m != null:
		lines.append(Loc.t("Weather: %s") % Loc.t(WeatherCycle.current(m).capitalize()))
	lines.append(Loc.t("Time of day: %s") % Loc.t(DayCycle.phase_name(DayCycle.current()).capitalize()))
	var sp: Array[String] = species(place)
	if not sp.is_empty():
		var shown: PackedStringArray = []
		for s: String in sp:
			shown.append(s if s == "???" else Loc.t(s))
		lines.append(Loc.t("Spirlings: %s") % ", ".join(shown))
	return "\n".join(lines)

## Rooms of a dungeon (item 1026): the flag each room sets when solved, over all levels of the
## map file: a light beam's flag, a puzzle's flag or the flag that opens the room's door
## (flags starting with "_" are water levels, not rooms).
static func room_flags(file_id: String) -> Array[String]:
	var out: Array[String] = []
	var top: MapData = MapData.load_map(file_id)
	if top == null:
		return out
	for i: int in top.floor_count:
		var m: MapData = MapData.load_map(MapData.floor_id(file_id, i))
		if m == null:
			continue
		var found: Array[String] = []
		if not m.beam.is_empty():
			found.append(str(m.beam.get("flag", "")))
		for pz: Dictionary in m.puzzles:
			found.append(str(pz.get("flag", "")))
		for b: Dictionary in m.blocks:
			found.append(str(b.get("open_flag", "")))
		for f: String in found:
			if not f.is_empty() and not f.begins_with("_") and not f in out:
				out.append(f)
	return out

## Banner on entering a map: "Lanternwell  3/5" in a dungeon with rooms (item 1026), otherwise
## the name and the survey share, "Gloamwood  40%" (item 1246). Floors carry their own names
## ("Lanternwell, chamber 2"), so the level shows too (item 993).
static func banner(m: MapData, flags: Dictionary) -> String:
	var name: String = Loc.t(m.display_name)
	if m.biome == "dungeon":
		var rooms: Array[String] = room_flags(m.file_id)
		if not rooms.is_empty():
			var solved: int = rooms.filter(func(f: String) -> bool: return bool(flags.get(f, false))).size()
			return "%s  %d/%d" % [name, solved, rooms.size()]
	return "%s  %d%%" % [name, Survey.percent(m)]
