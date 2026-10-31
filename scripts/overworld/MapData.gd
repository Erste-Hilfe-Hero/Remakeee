class_name MapData
extends RefCounted
## One overworld map loaded from data/maps/<id>.json.
## Maps are ASCII rows (legend in TilesetFactory) plus warps, NPCs, signs and an encounter table.
## Assumption: this stands in for Tiled 1.12 + YATI until real maps are drawn; the runtime
## already renders through TileMapLayer nodes, so swapping the source keeps the game code.

const DIR: String = "res://data/maps/"

var id: String
var display_name: String
var region: String = "veydal"
var rows: PackedStringArray = []
var width: int = 0
var height: int = 0
var warps: Array[Dictionary] = []
var npcs: Array[Dictionary] = []
var signs: Array[Dictionary] = []
var encounter_table: String = ""
## Tall grass may only roll encounters if a table exists.
var heal_point: Vector2i = Vector2i(-1, -1)

static func exists(map_id: String) -> bool:
	return FileAccess.file_exists(DIR + map_id + ".json")

static func load_map(map_id: String) -> MapData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + map_id + ".json"))
	if not raw is Dictionary:
		push_error("MapData: cannot read map '%s'" % map_id)
		return null
	var m := MapData.new()
	m.id = map_id
	m.display_name = str(raw.get("name", map_id))
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
	for s: Variant in raw.get("signs", []):
		m.signs.append(s)
	m.encounter_table = str(raw.get("encounters", ""))
	var hp: Array = raw.get("heal_point", [-1, -1])
	m.heal_point = Vector2i(int(hp[0]), int(hp[1]))
	return m

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

func sign_at(cell: Vector2i) -> Dictionary:
	for s: Dictionary in signs:
		if int(s.x) == cell.x and int(s.y) == cell.y:
			return s
	return {}

## Fills [param layer] with this map's tiles.
func paint(layer: TileMapLayer) -> void:
	layer.tile_set = TilesetFactory.get_tileset()
	layer.clear()
	for y: int in height:
		for x: int in rows[y].length():
			layer.set_cell(Vector2i(x, y), 0, Vector2i(TilesetFactory.kind_for(rows[y][x]), 0))
