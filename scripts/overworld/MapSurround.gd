class_name MapSurround
extends TileMapLayer
## The land around an outdoor map (update 1.3.2): on a screen larger than the map (a tablet,
## an unfolded foldable, a Chromebook window) the view shows more than the map holds. Instead
## of a bare colour there, the map's own edge carries on outwards: woods stay woods, water
## stays water and a path leaving the map runs on to the screen edge. It only draws; the
## Wayfarer never walks there (MapData.in_bounds). Indoor maps keep their dark surround.

## Edge kinds that carry on outwards as they are; every other edge kind becomes woods.
const CARRY: Array[int] = [TilesetFactory.Kind.GRASS, TilesetFactory.Kind.PATH, TilesetFactory.Kind.WATER,
	TilesetFactory.Kind.TREE, TilesetFactory.Kind.CLIFF, TilesetFactory.Kind.REEDS, TilesetFactory.Kind.SCREE,
	TilesetFactory.Kind.ROCK]
## Tall grass at the edge carries on as plain grass, so nothing outside looks like an encounter.
const SOFTEN: Dictionary[int, int] = {TilesetFactory.Kind.TALL_GRASS: TilesetFactory.Kind.GRASS,
	TilesetFactory.Kind.FLOWER: TilesetFactory.Kind.GRASS, TilesetFactory.Kind.WADE: TilesetFactory.Kind.WATER}

var map: MapData
## Cells drawn around the map on each side.
var ring: int = 0

func _ready() -> void:
	z_index = -1
	get_viewport().size_changed.connect(refresh)

## The kind drawn at [param cell] outside [param m]: its nearest edge cell's kind, softened.
static func kind_outside(m: MapData, cell: Vector2i) -> int:
	var edge := Vector2i(clampi(cell.x, 0, m.width - 1), clampi(cell.y, 0, m.height - 1))
	var k: int = m.kind_at(edge)
	k = SOFTEN.get(k, k)
	return k if k in CARRY else TilesetFactory.Kind.TREE

## Cells needed on each side so a view of [param vp] pixels never shows past the surround,
## wherever the camera stands.
static func ring_for(vp: Vector2) -> int:
	return int(ceilf(maxf(vp.x, vp.y) / TilesetFactory.TILE / 2.0)) + 1

## Draws the surround of [param m] (nothing for an indoor map).
func show_map(m: MapData) -> void:
	map = m
	ring = 0
	refresh()

func refresh() -> void:
	if map == null or not is_inside_tree():
		return
	var need: int = ring_for(get_viewport().get_visible_rect().size) if map.outdoor else 0
	if need == ring and get_used_cells().size() > 0:
		return
	ring = need
	clear()
	if ring <= 0:
		return
	tile_set = TilesetFactory.get_tileset(map.region)
	# Each cell's kind once, though atlas_coords asks for every neighbour (1.3.2 perf pass).
	var kinds: Dictionary[Vector2i, int] = {}
	var outside := func(c: Vector2i) -> int:
		if not kinds.has(c):
			kinds[c] = kind_outside(map, c)
		return kinds[c]
	for y: int in range(-ring, map.height + ring):
		for x: int in range(-ring, map.width + ring):
			var c := Vector2i(x, y)
			if map.in_bounds(c):
				continue
			set_cell(c, 0, TilesetFactory.atlas_coords(outside.call(c), c, outside))
