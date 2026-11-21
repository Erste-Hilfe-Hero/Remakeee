class_name EraDepthLayer
extends Node2D
## Era IV/V overworld depth (data/era45_overworld.json): buildings stand as boxes seen a little
## from above and to the right. Each building edge gets a side wall on its right and a top face
## above its roof ridge, a parallelogram a few px deep, coloured from the map's own tile art
## (darker for the wall, lighter for the top; Era V adds a warm edge). The roof of a house is
## lifted and a raised wall row fills the gap, trees stand taller on a longer trunk and cliff
## lips rise over a taller rock face (the canopy of EraTerrainLook lifts the same tops over the
## people). Sits right above the ground tiles. Older regions keep their flat look
## (EraTerrainLook.tier_for). Nothing moves.
## It also owns the screen side of Era IV/V: the whole-number camera zoom and the fill around a
## map smaller than the view (per era on screen, so it holds for old regions too).

const PATH: String = "res://data/era45_overworld.json"
const TILE: int = TilesetFactory.TILE

## Tools: false draws nothing (before/after shots).
static var enabled: bool = true
static var _cfg: Dictionary = {}

var map: MapData
var ground: TileMapLayer
var era_cfg: Dictionary = {}
var screen_cfg: Dictionary = {}
var _img: Image
var _tile: Vector2i = Vector2i(TILE, TILE)
var _kinds: Array[int] = []
var _raised: Texture2D
var _fill: TileMapLayer

func _init() -> void:
	name = "era_depth"

func _ready() -> void:
	_fill = TileMapLayer.new()
	_fill.name = "era_fill"
	_fill.show_behind_parent = true
	add_child(_fill)
	EraManager.era_changed.connect(func(_e: int) -> void:
		if map != null:
			show_map(map, ground))

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = raw if raw is Dictionary else {"eras": {}}
	return _cfg

## Depth settings of a map in [param region] while era [param active] is on screen; {} below Era IV.
static func for_map(region: String, active: int) -> Dictionary:
	return (cfg().get("eras", {}) as Dictionary).get(str(EraTerrainLook.tier_for(region, active)), {})

## Screen settings while era [param active] is on screen (zoom, fill); {} below Era IV.
static func for_screen(active: int) -> Dictionary:
	return (cfg().get("screen", {}) as Dictionary).get(str(clampi(active, EraManager.Era.INK, EraManager.NEWEST)), {})

## Whole-number camera zoom of the overworld while era [param active] is on screen.
static func camera_zoom(active: int) -> int:
	return maxi(1, int(for_screen(active).get("zoom", 1))) if enabled else 1

## Px the top of a [param kind] tile stands above its cell on a map of [param region] (the
## canopy and this layer agree on it); [param fallback] where the data sets none.
static func lift_of(region: String, kind: int, fallback: int) -> int:
	if not enabled:
		return fallback
	var lifts: Dictionary = for_map(region, EraManager.active_era()).get("lift", {})
	return int(lifts.get(TilesetFactory.Kind.find_key(kind), fallback))

static func kinds() -> Array[int]:
	var out: Array[int] = []
	for n: Variant in cfg().get("kinds", []):
		out.append(int(TilesetFactory.Kind.get(str(n), -1)))
	return out

static func band(key: String) -> Vector2i:
	var b: Array = cfg().get(key, [0, 1])
	return Vector2i(int(b[0]), int(b[1]))

## The side wall of a building edge cell [param c] that is [param side] px deep, as 4 corners;
## [param top] / [param bottom] (px, from the cell's top) stretch it for a raised house.
static func side_face(c: Vector2i, side: int, top: float = 0.0, bottom: float = TILE) -> PackedVector2Array:
	var x: float = (c.x + 1) * TILE
	var y0: float = c.y * TILE
	var lift: float = floorf(side / 2.0)
	return PackedVector2Array([Vector2(x, y0 + top), Vector2(x + side, y0 + top - lift), Vector2(x + side, y0 + bottom - lift), Vector2(x, y0 + bottom)])

## The top face above a building edge cell [param c], [param side] px deep, as 4 corners;
## [param top] moves it up with a lifted roof.
static func top_face(c: Vector2i, side: int, top: float = 0.0) -> PackedVector2Array:
	var x0: float = c.x * TILE
	var y: float = c.y * TILE + top
	var lift: float = floorf(side / 2.0)
	return PackedVector2Array([Vector2(x0, y), Vector2(x0 + side, y - lift), Vector2(x0 + TILE + side, y - lift), Vector2(x0 + TILE, y)])

## Strips of a tile stretched by [param lift] px: its rows [0, b.x) moved up by lift, then the
## rows [b.x, b.y) repeated down to where row b.x stood. Each entry is [dest y, src row, rows]
## in tile px (dest relative to the cell's top). The rows below b.x stay where they are.
static func stretch_rows(b: Vector2i, lift: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if lift <= 0:
		return out
	out.append(Vector3i(-lift, 0, b.x))
	var span: int = maxi(b.y - b.x, 1)
	var y: int = b.x - lift
	var i: int = 0
	while y < b.x:
		var n: int = mini(span - i % span, b.x - y)
		out.append(Vector3i(y, b.x + i % span, n))
		y += n
		i += n
	return out

## Cells of fill around a [param size] map, [param margin] deep, each with the in-map cell it copies.
static func fill_cells(size: Vector2i, margin: int) -> Dictionary[Vector2i, Vector2i]:
	var out: Dictionary[Vector2i, Vector2i] = {}
	for y: int in range(-margin, size.y + margin):
		for x: int in range(-margin, size.x + margin):
			if x >= 0 and y >= 0 and x < size.x and y < size.y:
				continue
			out[Vector2i(x, y)] = Vector2i(clampi(x, 0, size.x - 1), clampi(y, 0, size.y - 1))
	return out

func show_map(m: MapData, ground_layer: TileMapLayer) -> void:
	map = m
	ground = ground_layer
	era_cfg = for_map(m.region, EraManager.active_era()) if enabled else {}
	screen_cfg = for_screen(EraManager.active_era()) if enabled else {}
	_kinds = kinds()
	_img = null
	_raised = null
	if ground != null and ground.tile_set != null and ground.tile_set.get_source_count() > 0:
		var src: TileSetAtlasSource = ground.tile_set.get_source(0) as TileSetAtlasSource
		if not era_cfg.is_empty() and src != null and src.texture != null:
			_img = src.texture.get_image()
			_tile = src.texture_region_size
	if not era_cfg.is_empty():
		var raised_path: String = str(EraTerrainLook.shared("raised_atlas", "")) % [EraManager.region_era(m.region), m.region]
		if ResourceLoader.exists(raised_path):
			_raised = load(raised_path)
	_paint_fill()
	queue_redraw()

## Era IV/V screens: the map's border carried on around an outdoor map smaller than the view.
func _paint_fill() -> void:
	if _fill == null:
		return
	_fill.clear()
	if map == null or ground == null or str(screen_cfg.get("fill", "")) != "edge" or not map.outdoor:
		return
	_fill.tile_set = ground.tile_set
	var cells: Dictionary[Vector2i, Vector2i] = fill_cells(Vector2i(map.width, map.height), int(cfg().get("fill_margin", 16)))
	for c: Vector2i in cells:
		var from: Vector2i = cells[c]
		_fill.set_cell(c, ground.get_cell_source_id(from), ground.get_cell_atlas_coords(from))

func _kind(c: Vector2i) -> int:
	return map.kind_at(c) if c.x >= 0 and c.y >= 0 and c.x < map.width and c.y < map.height else -1

func _is_building(c: Vector2i) -> bool:
	return _kind(c) in _kinds

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

## Lift of the roof of the house cell [param c]: raise for a roof, 0 for anything else.
func _roof_lift(c: Vector2i) -> int:
	return int(era_cfg.get("raise", 0)) if _kind(c) == TilesetFactory.Kind.ROOF else 0

## A wall or door right under a roof: its top rises with the roof.
func _raised_wall(c: Vector2i) -> bool:
	var k: int = _kind(c)
	return (k == TilesetFactory.Kind.WALL or k == TilesetFactory.Kind.DOOR) and _kind(c + Vector2i.UP) == TilesetFactory.Kind.ROOF

func _has_top(c: Vector2i, kind: int) -> bool:
	if kind == TilesetFactory.Kind.TREE:
		return true
	var up: int = _kind(c + Vector2i.UP)
	return kind == TilesetFactory.Kind.CLIFF and up >= 0 and not TilesetFactory.is_solid(up) and up != TilesetFactory.Kind.STAIRS

func _blit_rows(tex: Texture2D, coords: Vector2i, at: Vector2, strips: Array[Vector3i]) -> void:
	for s: Vector3i in strips:
		draw_texture_rect_region(tex, Rect2(at + Vector2(0, s.x), Vector2(TILE, s.z)), Rect2(Vector2(coords * TILE) + Vector2(0, s.y), Vector2(TILE, s.z)))

func _draw() -> void:
	if map == null:
		return
	var indoor: String = str(screen_cfg.get("indoor", ""))
	if not map.outdoor and not indoor.is_empty():
		var col := Color(indoor)
		var w: float = map.width * TILE
		var h: float = map.height * TILE
		var m: float = float(int(cfg().get("fill_margin", 16)) * TILE)
		for r: Rect2 in [Rect2(-m, -m, w + m * 2, m), Rect2(-m, h, w + m * 2, m), Rect2(-m, 0, m, h), Rect2(w, 0, m, h)]:
			draw_rect(r, col)
	if era_cfg.is_empty() or ground == null:
		return
	var tex: Texture2D = (ground.tile_set.get_source(0) as TileSetAtlasSource).texture if ground.tile_set != null and ground.tile_set.get_source_count() > 0 else null
	var lifts: Dictionary = era_cfg.get("lift", {})
	var raise: int = int(era_cfg.get("raise", 0))
	if tex == null:
		return
	for y: int in map.height:
		for x: int in map.width:
			var c := Vector2i(x, y)
			var k: int = _kind(c)
			var at := Vector2(c * TILE)
			if k == TilesetFactory.Kind.TREE and _raised != null and int(lifts.get("TREE", 0)) > 0:
				# A taller tree: grass where the old crown was, then the cut-out tree on a longer trunk.
				var grass := Vector2i(TilesetFactory.Kind.GRASS, posmod(x * 7 + y * 13, 4))
				draw_texture_rect_region(tex, Rect2(at, Vector2(TILE, TILE)), Rect2(Vector2(grass * TILE), Vector2(TILE, TILE)))
				var tb: Vector2i = band("tree_band")
				_blit_rows(_raised, ground.get_cell_atlas_coords(c), at, [Vector3i(tb.x, tb.x, TILE - tb.x)] as Array[Vector3i])
				_blit_rows(_raised, ground.get_cell_atlas_coords(c), at, stretch_rows(tb, int(lifts.get("TREE", 0))))
			elif k == TilesetFactory.Kind.CLIFF and _has_top(c, k):
				_blit_rows(tex, ground.get_cell_atlas_coords(c), at, stretch_rows(band("cliff_band"), int(lifts.get("CLIFF", 0))))
			elif _raised_wall(c) and map.outdoor:
				_blit_rows(tex, ground.get_cell_atlas_coords(_band_source(c)), at, stretch_rows(band("wall_band"), raise))
			elif k == TilesetFactory.Kind.ROOF and raise > 0 and map.outdoor:
				draw_texture_rect_region(tex, Rect2(at - Vector2(0, raise), Vector2(TILE, TILE)), Rect2(Vector2(ground.get_cell_atlas_coords(c) * TILE), Vector2(TILE, TILE)))
		_draw_faces(y)

## The cell whose wall rows a raised wall [param c] repeats: a door takes the plain wall beside
## it, so its frame does not run up the raised row.
func _band_source(c: Vector2i) -> Vector2i:
	if _kind(c) != TilesetFactory.Kind.DOOR:
		return c
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
		if _kind(c + d) == TilesetFactory.Kind.WALL and _raised_wall(c + d):
			return c + d
	return c

## Side walls and top faces of the buildings in row [param y], after the row's own tiles (outdoor
## maps only: a room's exit door is no house).
func _draw_faces(y: int) -> void:
	if not map.outdoor:
		return
	var side: int = int(era_cfg.get("side", 4))
	var shade: float = float(era_cfg.get("shade", 0.35))
	var light: float = float(era_cfg.get("light", 0.2))
	var warm: String = str(era_cfg.get("warm_edge", ""))
	var raise: int = int(era_cfg.get("raise", 0))
	for x: int in map.width:
		var c := Vector2i(x, y)
		if not _is_building(c):
			continue
		var top: float = -float(_roof_lift(c)) if _kind(c) == TilesetFactory.Kind.ROOF else (-float(raise) if _raised_wall(c) else 0.0)
		var bottom: float = TILE - float(_roof_lift(c))
		var base: Color = TilesetFactory.COLORS.get(map.kind_at(c), Color.GRAY)
		if not _is_building(c + Vector2i.RIGHT):
			var col: Color = _sample(c, Vector2(0.85, 0.5), base).darkened(shade)
			var f: PackedVector2Array = side_face(c, side, top, bottom)
			draw_colored_polygon(f, col)
			draw_line(f[1] + Vector2(-0.5, 0), f[2] + Vector2(-0.5, 0), col.darkened(0.3))
		if not _is_building(c + Vector2i.UP):
			var tc: Color = _sample(c, Vector2(0.5, 0.1), base).lightened(light)
			var t: PackedVector2Array = top_face(c, side, top)
			draw_colored_polygon(t, tc)
			if not warm.is_empty():
				draw_line(t[1] + Vector2(0, 0.5), t[2] + Vector2(0, 0.5), Color(warm))
