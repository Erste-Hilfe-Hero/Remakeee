class_name TilesetFactory
extends RefCounted
## Builds the overworld TileSet. Uses the original Era I atlas (art/era1/tiles/overworld.png,
## made by tools/art/gen_tiles.py) and falls back to coloured squares if it is missing.
## Atlas layout: column = Kind, row = variant (neighbour mask or cosmetic variant).

const TILE: int = 16

## Tile kinds. The atlas column equals the enum value.
enum Kind { GRASS, TALL_GRASS, PATH, WATER, TREE, WALL, ROOF, DOOR, FLOOR, FENCE, SIGN, FLOWER, COUNTER, INNER_WALL, SPRING, RIFT, CLIFF, STAIRS, REEDS, SCREE, PIER, TOWER, LAMP, ROCK, WADE, BOULDER, PLATE, CRACKED, VINES, PLANK }

## Map character -> tile kind.
const LEGEND: Dictionary[String, int] = {
	".": Kind.GRASS, ",": Kind.TALL_GRASS, "_": Kind.PATH, "~": Kind.WATER, "T": Kind.TREE,
	"H": Kind.WALL, "R": Kind.ROOF, "D": Kind.DOOR, "f": Kind.FLOOR, "#": Kind.FENCE,
	"S": Kind.SIGN, "*": Kind.FLOWER, "C": Kind.COUNTER, "W": Kind.INNER_WALL, "o": Kind.SPRING,
	"X": Kind.RIFT, "^": Kind.CLIFF, "=": Kind.STAIRS, "%": Kind.REEDS, ":": Kind.SCREE,
	"+": Kind.PIER, "|": Kind.TOWER, "L": Kind.LAMP, "@": Kind.ROCK,
	# Area 3 (world): wading water, push boulder, pressure plate, cracked floor, vine wall,
	# plank gap. See MapData for how each one behaves.
	"w": Kind.WADE, "B": Kind.BOULDER, "P": Kind.PLATE, "k": Kind.CRACKED, "v": Kind.VINES,
	"Y": Kind.PLANK,
}

## Kinds the player walks into once they own a piece of Wayfarer Gear, always on foot:
## wading through shallow water, climbing a vine wall hand over hand. Plank gaps ("Y") need a
## plank laid with the Plank Bundle first (PuzzleRoom.lay_plank).
const GEAR_KINDS: Dictionary[int, String] = {
	Kind.WADE: "wading_boots", Kind.VINES: "climbing_pick",
}

## Wild Spirlings hide in ferns (tall grass), reeds and scree, not only in grass.
const ENCOUNTER_KINDS: Array[int] = [Kind.TALL_GRASS, Kind.REEDS, Kind.SCREE, Kind.WADE]

const SOLID: Array[int] = [Kind.WATER, Kind.TREE, Kind.WALL, Kind.ROOF, Kind.FENCE, Kind.SIGN, Kind.COUNTER, Kind.INNER_WALL, Kind.SPRING, Kind.CLIFF, Kind.TOWER, Kind.LAMP, Kind.ROCK, Kind.WADE, Kind.BOULDER, Kind.VINES, Kind.PLANK]

const COLORS: Dictionary[int, Color] = {
	Kind.GRASS: Color("9cc46a"), Kind.TALL_GRASS: Color("5f9a3e"), Kind.PATH: Color("d8c08a"),
	Kind.WATER: Color("4a86c8"), Kind.TREE: Color("2f5e2a"), Kind.WALL: Color("e3d6b8"),
	Kind.ROOF: Color("a9533c"), Kind.DOOR: Color("5a3a28"), Kind.FLOOR: Color("c9a26e"),
	Kind.FENCE: Color("8a6440"), Kind.SIGN: Color("b88a52"), Kind.FLOWER: Color("9cc46a"),
	Kind.COUNTER: Color("7a5a3a"), Kind.INNER_WALL: Color("6b5a4a"), Kind.SPRING: Color("7fc6e0"),
	Kind.RIFT: Color("3a2a55"), Kind.CLIFF: Color("8a7a5a"), Kind.STAIRS: Color("b0a080"),
	Kind.REEDS: Color("5a8a6a"), Kind.SCREE: Color("a09a8a"), Kind.PIER: Color("c09a6a"),
	Kind.TOWER: Color("e8e0d0"), Kind.LAMP: Color("f0d070"), Kind.ROCK: Color("7a7a6a"),
	Kind.WADE: Color("7aa8d8"), Kind.BOULDER: Color("8a8070"), Kind.PLATE: Color("b0a890"),
	Kind.CRACKED: Color("a08868"), Kind.VINES: Color("4a7a3a"), Kind.PLANK: Color("2a1e2c"),
}

## Era I atlas; runtime code uses atlas_path() so newer eras can swap it.
const ATLAS_PATH: String = "res://art/era1/tiles/overworld.png"
const ATLAS_REL: String = "tiles/overworld.png"
const VARIANT_ROWS: int = 16
## Kinds whose variant row is a neighbour mask (1 up, 2 right, 4 down, 8 left).
const MASKED: Array[int] = [Kind.PATH, Kind.WATER, Kind.ROOF, Kind.WALL, Kind.FENCE, Kind.CLIFF, Kind.PIER, Kind.WADE]
## Kinds with cosmetic variants 0..3 picked from the cell position.
const SCATTERED: Array[int] = [Kind.GRASS, Kind.TALL_GRASS, Kind.TREE, Kind.FLOWER, Kind.REEDS, Kind.SCREE, Kind.ROCK]
const MASK_DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

## Per-region looks (data/looks/<region>.json): own atlas and own Era I inks (Act III Ashmere).
const LOOKS_PATH: String = "res://data/looks/%s.json"

static var _tilesets: Dictionary = {}
static var _looks: Dictionary = {}
static var _has_atlas: bool = false

static func kind_for(ch: String) -> int:
	return LEGEND.get(ch, Kind.GRASS)

static func is_solid(kind: int) -> bool:
	return kind in SOLID

## The look of [param region], or {} when it has none.
static func look(region: String) -> Dictionary:
	if not _looks.has(region):
		var d: Variant = null
		var path: String = LOOKS_PATH % region
		if not region.is_empty() and FileAccess.file_exists(path):
			d = JSON.parse_string(FileAccess.get_file_as_string(path))
		_looks[region] = d if d is Dictionary else {}
	return _looks[region]

## Atlas for [param region]. A region atlas is used only in the era it was drawn for; a newer
## era keeps the shared atlas until it draws its own.
static func atlas_path(region: String = "") -> String:
	var base: String = EraManager.art_path(ATLAS_REL)
	var rel: String = str(look(region).get("atlas", ""))
	if base.is_empty() or rel.is_empty():
		return base
	var own: String = EraManager.art_path(rel)
	if own.is_empty() or own.get_slice("/", 3) != base.get_slice("/", 3):
		return base
	return own

## Drops the cached TileSets so the next get_tileset() rebuilds them for the active era.
static func clear_cache() -> void:
	_tilesets.clear()

static func get_tileset(region: String = "") -> TileSet:
	var atlas: String = atlas_path(region)
	if not _tilesets.has(atlas):
		_tilesets[atlas] = _build(atlas)
	return _tilesets[atlas]

## Neighbours that count as "the same" when picking a masked variant.
static func joins(kind: int, other: int) -> bool:
	if kind == other:
		return true
	match kind:
		Kind.PATH:
			return other == Kind.DOOR or other == Kind.SIGN
		Kind.WALL:
			return other == Kind.DOOR
		Kind.FENCE:
			return other == Kind.SIGN
		Kind.WATER:
			return other == Kind.REEDS or other == Kind.PIER or other == Kind.WADE
		Kind.PIER:
			return other == Kind.PATH or other == Kind.STAIRS
		Kind.CLIFF:
			return other == Kind.STAIRS
		Kind.WADE:
			return other == Kind.WATER
	return false

## Atlas coordinates for [param kind] at [param cell]; [param kind_at] returns the kind of
## any cell (out-of-bounds cells should return the same kind so map edges stay seamless).
static func atlas_coords(kind: int, cell: Vector2i, kind_at: Callable) -> Vector2i:
	if not _has_atlas:
		return Vector2i(kind, 0)
	if kind in MASKED:
		var mask: int = 0
		for i: int in MASK_DIRS.size():
			if joins(kind, int(kind_at.call(cell + MASK_DIRS[i]))):
				mask |= 1 << i
		return Vector2i(kind, mask)
	if kind in SCATTERED:
		var h: int = absi(cell.x * 7 + cell.y * 13 + (cell.x * cell.y) % 5)
		return Vector2i(kind, h % 4)
	return Vector2i(kind, 0)

static func _build(atlas: String) -> TileSet:
	var count: int = Kind.size()
	var tex: Texture2D
	var rows: int = 1
	_has_atlas = not atlas.is_empty()
	if _has_atlas:
		tex = load(atlas)
		rows = VARIANT_ROWS
	else:
		var img := Image.create(TILE * count, TILE, false, Image.FORMAT_RGBA8)
		for k: int in count:
			_paint(img, k)
		tex = ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	for r: int in rows:
		for k: int in count:
			src.create_tile(Vector2i(k, r))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts

static func _paint(img: Image, k: int) -> void:
	var ox: int = k * TILE
	var base: Color = COLORS[k]
	img.fill_rect(Rect2i(ox, 0, TILE, TILE), base)
	var dark: Color = base.darkened(0.35)
	var light: Color = base.lightened(0.3)
	match k:
		Kind.GRASS:
			for p: Vector2i in [Vector2i(3, 4), Vector2i(11, 9), Vector2i(6, 13)]:
				img.set_pixel(ox + p.x, p.y, dark)
		Kind.TALL_GRASS:
			for x: int in range(1, TILE, 4):
				img.fill_rect(Rect2i(ox + x, 4, 1, 9), dark)
				img.fill_rect(Rect2i(ox + x + 2, 2, 1, 9), light)
		Kind.PATH:
			img.set_pixel(ox + 4, 5, dark)
			img.set_pixel(ox + 12, 11, dark)
		Kind.WATER:
			img.fill_rect(Rect2i(ox + 2, 5, 5, 1), light)
			img.fill_rect(Rect2i(ox + 9, 11, 5, 1), light)
		Kind.TREE:
			img.fill_rect(Rect2i(ox + 2, 1, 12, 10), base.lightened(0.15))
			img.fill_rect(Rect2i(ox + 6, 11, 4, 5), Color("5a3a28"))
		Kind.WALL:
			img.fill_rect(Rect2i(ox, 15, TILE, 1), dark)
			img.fill_rect(Rect2i(ox + 4, 5, 8, 6), Color("8ab4d8"))
		Kind.ROOF:
			for y: int in range(0, TILE, 4):
				img.fill_rect(Rect2i(ox, y, TILE, 1), dark)
		Kind.DOOR:
			img.fill_rect(Rect2i(ox + 3, 2, 10, 14), dark)
			img.set_pixel(ox + 10, 9, Color("e8c860"))
		Kind.FLOOR:
			for y: int in range(3, TILE, 5):
				img.fill_rect(Rect2i(ox, y, TILE, 1), dark)
		Kind.FENCE:
			img.fill_rect(Rect2i(ox, 0, TILE, TILE), COLORS[Kind.GRASS])
			img.fill_rect(Rect2i(ox, 5, TILE, 2), base)
			img.fill_rect(Rect2i(ox, 10, TILE, 2), base)
			img.fill_rect(Rect2i(ox + 2, 3, 2, 12), dark)
			img.fill_rect(Rect2i(ox + 12, 3, 2, 12), dark)
		Kind.SIGN:
			img.fill_rect(Rect2i(ox, 0, TILE, TILE), COLORS[Kind.GRASS])
			img.fill_rect(Rect2i(ox + 2, 3, 12, 7), base)
			img.fill_rect(Rect2i(ox + 7, 10, 2, 5), dark)
		Kind.FLOWER:
			for p: Vector2i in [Vector2i(4, 4), Vector2i(11, 6), Vector2i(7, 11)]:
				img.fill_rect(Rect2i(ox + p.x, p.y, 2, 2), Color("f0e060"))
		Kind.COUNTER:
			img.fill_rect(Rect2i(ox, 0, TILE, 3), light)
		Kind.INNER_WALL:
			img.fill_rect(Rect2i(ox, 12, TILE, 4), dark)
		Kind.SPRING:
			img.fill_rect(Rect2i(ox, 0, TILE, TILE), COLORS[Kind.FLOOR])
			img.fill_rect(Rect2i(ox + 2, 2, 12, 12), base)
			img.fill_rect(Rect2i(ox + 5, 5, 6, 6), light)
		Kind.RIFT:
			img.fill_rect(Rect2i(ox + 4, 2, 8, 12), Color("9a6ad8"))
			img.fill_rect(Rect2i(ox + 6, 4, 4, 8), Color("e0d0ff"))
		Kind.WADE:
			img.fill_rect(Rect2i(ox + 3, 7, 10, 1), light)
		Kind.BOULDER:
			img.fill_rect(Rect2i(ox, 0, TILE, TILE), COLORS[Kind.GRASS])
			img.fill_rect(Rect2i(ox + 2, 3, 12, 11), base)
			img.fill_rect(Rect2i(ox + 4, 5, 4, 2), light)
		Kind.PLATE:
			img.fill_rect(Rect2i(ox + 3, 3, 10, 10), dark)
			img.fill_rect(Rect2i(ox + 4, 4, 8, 8), light)
		Kind.CRACKED:
			for i: int in 10:
				img.set_pixel(ox + 3 + i, 4 + (i * 7) % 8, dark)
		Kind.VINES:
			img.fill_rect(Rect2i(ox, 0, TILE, TILE), COLORS[Kind.CLIFF])
			for x: int in range(2, TILE, 5):
				img.fill_rect(Rect2i(ox + x, 0, 2, TILE), base)
		Kind.PLANK:
			img.fill_rect(Rect2i(ox, 0, TILE, 2), COLORS[Kind.CLIFF])
			img.fill_rect(Rect2i(ox, 14, TILE, 2), COLORS[Kind.CLIFF])
