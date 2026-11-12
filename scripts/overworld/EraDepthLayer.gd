class_name EraDepthLayer
extends Node2D
## Era IV/V overworld depth (data/era45_overworld.json): buildings stand as boxes seen a little
## from above and to the right. Each building edge gets a side wall on its right and a top face
## above its roof ridge, a parallelogram a few px deep, coloured from the map's own tile art
## (darker for the wall, lighter for the top; Era V adds a warm edge). Sits right above the
## ground tiles. Older regions keep their flat look (EraTerrainLook.tier_for). Nothing moves.

const PATH: String = "res://data/era45_overworld.json"
const TILE: int = TilesetFactory.TILE

## Tools: false draws nothing (before/after shots).
static var enabled: bool = true
static var _cfg: Dictionary = {}

var map: MapData
var ground: TileMapLayer
var era_cfg: Dictionary = {}
var _img: Image
var _tile: Vector2i = Vector2i(TILE, TILE)
var _kinds: Array[int] = []

func _init() -> void:
	name = "era_depth"

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = raw if raw is Dictionary else {"eras": {}}
	return _cfg

## Depth settings of a map in [param region] while era [param active] is on screen; {} below Era IV.
static func for_map(region: String, active: int) -> Dictionary:
	return (cfg().get("eras", {}) as Dictionary).get(str(EraTerrainLook.tier_for(region, active)), {})

static func kinds() -> Array[int]:
	var out: Array[int] = []
	for n: Variant in cfg().get("kinds", []):
		out.append(int(TilesetFactory.Kind.get(str(n), -1)))
	return out

## The side wall of a building edge cell [param c] that is [param side] px deep, as 4 corners.
static func side_face(c: Vector2i, side: int) -> PackedVector2Array:
	var x: float = (c.x + 1) * TILE
	var y0: float = c.y * TILE
	var lift: float = floorf(side / 2.0)
	return PackedVector2Array([Vector2(x, y0), Vector2(x + side, y0 - lift), Vector2(x + side, y0 + TILE - lift), Vector2(x, y0 + TILE)])

## The top face above a building edge cell [param c], [param side] px deep, as 4 corners.
static func top_face(c: Vector2i, side: int) -> PackedVector2Array:
	var x0: float = c.x * TILE
	var y: float = c.y * TILE
	var lift: float = floorf(side / 2.0)
	return PackedVector2Array([Vector2(x0, y), Vector2(x0 + side, y - lift), Vector2(x0 + TILE + side, y - lift), Vector2(x0 + TILE, y)])

func show_map(m: MapData, ground_layer: TileMapLayer) -> void:
	map = m
	ground = ground_layer
	era_cfg = for_map(m.region, EraManager.active_era()) if enabled else {}
	_kinds = kinds()
	_img = null
	if not era_cfg.is_empty() and ground != null and ground.tile_set != null and ground.tile_set.get_source_count() > 0:
		var src: TileSetAtlasSource = ground.tile_set.get_source(0) as TileSetAtlasSource
		if src != null and src.texture != null:
			_img = src.texture.get_image()
			_tile = src.texture_region_size
	queue_redraw()

func _is_building(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < map.width and c.y < map.height and map.kind_at(c) in _kinds

## Colour of cell [param c]'s own art at the point [param at] (0..1 of the tile).
func _sample(c: Vector2i, at: Vector2, fallback: Color) -> Color:
	if _img == null:
		return fallback
	var a: Vector2i = ground.get_cell_atlas_coords(c)
	if a.x < 0:
		return fallback
	var p := Vector2i(a.x * _tile.x + int(at.x * (_tile.x - 1)), a.y * _tile.y + int(at.y * (_tile.y - 1)))
	if p.x >= _img.get_width() or p.y >= _img.get_height():
		return fallback
	var col: Color = _img.get_pixelv(p)
	return col if col.a > 0.5 else fallback

func _draw() -> void:
	if map == null or era_cfg.is_empty():
		return
	var side: int = int(era_cfg.get("side", 4))
	var shade: float = float(era_cfg.get("shade", 0.35))
	var light: float = float(era_cfg.get("light", 0.2))
	var warm: String = str(era_cfg.get("warm_edge", ""))
	for y: int in map.height:
		for x: int in map.width:
			var c := Vector2i(x, y)
			if not _is_building(c):
				continue
			var base: Color = TilesetFactory.COLORS.get(map.kind_at(c), Color.GRAY)
			if not _is_building(c + Vector2i.RIGHT):
				var col: Color = _sample(c, Vector2(0.85, 0.5), base).darkened(shade)
				var f: PackedVector2Array = side_face(c, side)
				draw_colored_polygon(f, col)
				draw_line(f[1] + Vector2(-0.5, 0), f[2] + Vector2(-0.5, 0), col.darkened(0.3))
			if not _is_building(c + Vector2i.UP):
				var top: Color = _sample(c, Vector2(0.5, 0.1), base).lightened(light)
				var t: PackedVector2Array = top_face(c, side)
				draw_colored_polygon(t, top)
				if not warm.is_empty():
					draw_line(t[1] + Vector2(0, 0.5), t[2] + Vector2(0, 0.5), Color(warm))
