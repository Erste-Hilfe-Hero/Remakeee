class_name MapData
extends RefCounted
## One overworld map loaded from data/maps/<id>.json.
## Maps are ASCII rows (legend in TilesetFactory) plus warps, NPCs, signs and an encounter table.
##
## Legend (TilesetFactory.LEGEND): "." grass, "," fern, "_" path, "~" water, "T" tree, "H" wall,
## "R" roof, "D" door, "f" floor, "#" fence, "S" sign, "*" flowers, "C" counter, "W" inner wall,
## "o" spring, "X" Rift, "^" cliff, "=" stairs, "%" reeds, ":" scree, "+" pier, "|" tower,
## "L" lamp, "@" rock. Area 3 adds:
##   "w" shallow water: walk through it with the Wading Boots (on foot, never swimming)
##   "B" boulder: push it one cell by walking against it (Bellstone and other puzzle rooms)
##   "P" pressure plate: held down while a boulder or the player stands on it
##   "k" cracked floor: gives way after one step and drops to the floor below
##   "v" vine wall: climb it with the Climbing Pick, hand over hand
##   "Y" plank gap: lay a plank from the Plank Bundle once and it stays
##
## Optional fields: "secrets" (hidden finds: [{"x", "y", "item", "count", "flag"}]) and "floors"
## (more levels in the same file: [{"name", "rows", "warps", ...}]). Floor n of map "cave" is
## loaded as "cave@n"; floor 0 is the top level of the file. A floor inherits name, region,
## backdrop, encounters and field from the top level unless it sets its own.
## Assumption: this stands in for Tiled 1.12 + YATI until real maps are drawn; the runtime
## already renders through TileMapLayer nodes, so swapping the source keeps the game code.

const DIR: String = "res://data/maps/"
## Separates a map file from a floor index in map ids ("copper_deep@2").
const FLOOR_SEP: String = "@"
## Fields a floor takes from the top level of its file unless it sets them itself.
const INHERITED: Array[String] = ["name", "region", "backdrop", "outdoor", "field", "encounters", "biome"]

var id: String
var display_name: String
## Follows the real clock (DayCycle); false for rooms, caves and Rifts.
var outdoor: bool = false
var region: String = "veydal"
var rows: PackedStringArray = []
var width: int = 0
var height: int = 0
var warps: Array[Dictionary] = []
var npcs: Array[Dictionary] = []
var signs: Array[Dictionary] = []
var gear_spots: Array[Dictionary] = []
var encounter_table: String = ""
## Battle backdrop for fights that start here (BattleBackdrop.KINDS).
var backdrop: String = "field"
## Rift field for battles here (BattleRules.FIELDS), or "".
var field: String = ""
## Tall grass may only roll encounters if a table exists.
var heal_point: Vector2i = Vector2i(-1, -1)
## Puzzle blocks: {"x", "y", "open_flag"}. A closed block is drawn and treated as rock.
var blocks: Array[Dictionary] = []
## Hidden finds: {"x", "y", "item", "count", "flag"}. Facing the cell and pressing A takes it.
var secrets: Array[Dictionary] = []
## Floor index inside the map file (0 = the top level) and how many floors the file has.
var floor_index: int = 0
var floor_count: int = 1
## Map file this map comes from (id without the floor part).
var file_id: String = ""
## Puzzles: {"id", "flag", "plates": [[x, y], ...]} (see PuzzleRoom).
var puzzles: Array[Dictionary] = []
## Tile under a boulder drawn on the map ("f" floor by default, "_" outside).
var boulder_ground: String = "f"
## Map a broken cracked floor drops the player to (same cell), e.g. "shatterfloor_mine@1".
var drop_to: String = ""
## Ladder anchors: {"x", "y", "to", "tx", "ty"}. Hang the Rope Ladder once, then climb down.
var ladders: Array[Dictionary] = []
var _base_rows: PackedStringArray = []

static func exists(map_id: String) -> bool:
	var parts: Array = split_id(map_id)
	if not FileAccess.file_exists(DIR + str(parts[0]) + ".json"):
		return false
	if int(parts[1]) == 0:
		return true
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + str(parts[0]) + ".json"))
	return raw is Dictionary and int(parts[1]) <= (raw.get("floors", []) as Array).size()

## ["file", floor] for a map id; "cave" is ["cave", 0], "cave@2" is ["cave", 2].
static func split_id(map_id: String) -> Array:
	var at: int = map_id.find(FLOOR_SEP)
	if at < 0:
		return [map_id, 0]
	return [map_id.substr(0, at), int(map_id.substr(at + 1))]

## Map id for floor [param level] of file [param file].
static func floor_id(file: String, level: int) -> String:
	return file if level == 0 else "%s%s%d" % [file, FLOOR_SEP, level]

## Every map id in data/maps, floors included ("cave", "cave@1", ...), sorted.
static func all_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	var files: PackedStringArray = DirAccess.get_files_at(DIR)
	files.sort()
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var id: String = f.get_basename()
		out.append(id)
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + f))
		if raw is Dictionary:
			for i: int in (raw.get("floors", []) as Array).size():
				out.append(floor_id(id, i + 1))
	return out

static func load_map(map_id: String) -> MapData:
	var path: String = DIR + str(split_id(map_id)[0]) + ".json"
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not raw is Dictionary:
		push_error("MapData: cannot read map '%s'" % map_id)
		return null
	var m: MapData = from_dict(map_id, raw)
	if m != null:
		StoryPlacements.apply(m, raw)
	return m

## Builds floor [param map_id] ("file" or "file@n") from a parsed map file.
static func from_dict(map_id: String, raw: Dictionary) -> MapData:
	var parts: Array = split_id(map_id)
	var file: String = str(parts[0])
	var level_no: int = int(parts[1])
	var floors: Array = raw.get("floors", [])
	if level_no > 0:
		if level_no > floors.size() or not floors[level_no - 1] is Dictionary:
			push_error("MapData: map '%s' has no floor %d" % [file, level_no])
			return null
		var level: Dictionary = (floors[level_no - 1] as Dictionary).duplicate()
		for k: String in INHERITED:
			if raw.has(k) and not level.has(k):
				level[k] = raw[k]
		raw = level
	var m := MapData.new()
	m.id = map_id
	m.file_id = file
	m.floor_index = level_no
	m.floor_count = floors.size() + 1
	m.display_name = str(raw.get("name", map_id))
	m.outdoor = bool(raw.get("outdoor", false))
	m.region = str(raw.get("region", "veydal"))
	for r: Variant in raw.get("rows", []):
		m.rows.append(str(r))
	m.height = m.rows.size()
	for r: String in m.rows:
		m.width = maxi(m.width, r.length())
	for w: Variant in raw.get("warps", []):
		m.warps.append(w)
	for n: Variant in raw.get("npcs", []):
		m.npcs.append(n)
	if level_no == 0:
		# Master Wayfarers (plan area 8) stand on their maps once both Rifts are mended.
		m.npcs.append_array(Masters.npcs_for(file))
	for s: Variant in raw.get("signs", []):
		m.signs.append(s)
	for g: Variant in raw.get("gear_spots", []):
		m.gear_spots.append(g)
	for b: Variant in raw.get("blocks", []):
		m.blocks.append(b)
	for sc: Variant in raw.get("secrets", []):
		m.secrets.append(sc)
	for pz: Variant in raw.get("puzzles", []):
		m.puzzles.append(pz)
	for ld: Variant in raw.get("ladders", []):
		m.ladders.append(ld)
	m.boulder_ground = str(raw.get("boulder_ground", "f"))
	m.drop_to = str(raw.get("drop_to", ""))
	m._base_rows = m.rows.duplicate()
	m.encounter_table = str(raw.get("encounters", ""))
	m.backdrop = str(raw.get("backdrop", "field"))
	m.field = str(raw.get("field", ""))
	var hp: Array = raw.get("heal_point", [-1, -1])
	m.heal_point = Vector2i(int(hp[0]), int(hp[1]))
	return m

## The hidden find on [param cell] that is still there (its flag not set), or {}.
func secret_at(cell: Vector2i, flags: Dictionary = {}) -> Dictionary:
	for sc: Dictionary in secrets:
		if int(sc.x) == cell.x and int(sc.y) == cell.y and not bool(flags.get(str(sc.get("flag", "")), false)):
			return sc
	return {}

## Hidden finds taken on this map and the total ("Finds 2/4" in the map book).
func secrets_found(flags: Dictionary) -> Vector2i:
	var got: int = 0
	for sc: Dictionary in secrets:
		if bool(flags.get(str(sc.get("flag", "")), false)):
			got += 1
	return Vector2i(got, secrets.size())

## The map character at [param cell] right now ("" off the map).
func char_at(cell: Vector2i) -> String:
	return rows[cell.y][cell.x] if in_bounds(cell) else ""

## The character the map file has at [param cell] (before blocks, boulders and planks).
func base_char(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _base_rows.size() or cell.x < 0 or cell.x >= _base_rows[cell.y].length():
		return ""
	return _base_rows[cell.y][cell.x]

func base_row(y: int) -> String:
	return _base_rows[y]

## Changes one cell of the live rows (boulders, broken floor, planks).
func set_char(cell: Vector2i, ch: String) -> void:
	if in_bounds(cell):
		var r: String = rows[cell.y]
		rows[cell.y] = r.substr(0, cell.x) + ch + r.substr(cell.x + 1)

## The ladder anchor at [param cell], or {}.
func ladder_at(cell: Vector2i) -> Dictionary:
	for l: Dictionary in ladders:
		if int(l.x) == cell.x and int(l.y) == cell.y:
			return l
	return {}

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.y < height and cell.x < rows[cell.y].length()

func kind_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return TilesetFactory.Kind.TREE
	return TilesetFactory.kind_for(rows[cell.y][cell.x])

func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and not TilesetFactory.is_solid(kind_at(cell))

func warp_at(cell: Vector2i) -> Dictionary:
	for w: Dictionary in warps:
		if int(w.x) == cell.x and int(w.y) == cell.y:
			return w
	return {}

## Wayfarer Gear spot used by standing on [param from] and facing [param target], or {}.
## {"from": [x, y], "x", "y", "gear": item id, "to": [x, y]}; a spot without "to" is a dark cell
## that needs the gear to walk into.
func gear_spot(from: Vector2i, target: Vector2i) -> Dictionary:
	for g: Dictionary in gear_spots:
		if int(g.x) != target.x or int(g.y) != target.y or not g.has("to"):
			continue
		var f: Array = g.get("from", [])
		if f.size() == 2 and Vector2i(int(f[0]), int(f[1])) == from:
			return g
	return {}

## Gear needed to walk into [param cell] (a dark spot), or "".
func gear_needed_at(cell: Vector2i) -> String:
	for g: Dictionary in gear_spots:
		if not g.has("to") and int(g.x) == cell.x and int(g.y) == cell.y:
			return str(g.gear)
	return ""

## The sign on [param cell]. Signs may carry "show_flag" / "hide_flag" like NPCs, so one
## spot can read differently as the story moves on (the first matching sign wins).
func sign_at(cell: Vector2i, flags: Dictionary = {}) -> Dictionary:
	for s: Dictionary in signs:
		if int(s.x) != cell.x or int(s.y) != cell.y:
			continue
		if s.has("hide_flag") and bool(flags.get(str(s.hide_flag), false)):
			continue
		if s.has("show_flag") and not bool(flags.get(str(s.show_flag), false)):
			continue
		return s
	return {}

## Closes (rock) or opens each puzzle block from [param flags]. Returns true if anything changed.
func apply_blocks(flags: Dictionary) -> bool:
	var changed: bool = false
	for b: Dictionary in blocks:
		var x: int = int(b.x)
		var y: int = int(b.y)
		var open: bool = bool(flags.get(str(b.get("open_flag", "")), false))
		var ch: String = _base_rows[y][x] if open else "@"
		if rows[y][x] != ch:
			var r: String = rows[y]
			rows[y] = r.substr(0, x) + ch + r.substr(x + 1)
			changed = true
	return changed

## Fills [param layer] with this map's tiles.
func paint(layer: TileMapLayer) -> void:
	layer.tile_set = TilesetFactory.get_tileset()
	layer.clear()
	for y: int in height:
		for x: int in rows[y].length():
			var c := Vector2i(x, y)
			var k: int = kind_at(c)
			var neighbour: Callable = func(n: Vector2i) -> int: return kind_at(n) if in_bounds(n) else k
			layer.set_cell(c, 0, TilesetFactory.atlas_coords(k, c, neighbour))
