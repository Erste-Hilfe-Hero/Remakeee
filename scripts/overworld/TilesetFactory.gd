class_name TilesetFactory
extends RefCounted
## Builds the placeholder overworld TileSet in code (coloured 16 px squares with simple
## marks), so no third-party tiles are needed. Real Tiled/YATI tilesets replace this later.

const TILE: int = 16

## Tile kinds. The atlas column equals the enum value.
enum Kind { GRASS, TALL_GRASS, PATH, WATER, TREE, WALL, ROOF, DOOR, FLOOR, FENCE, SIGN, FLOWER, COUNTER, INNER_WALL, SPRING, RIFT }

## Map character -> tile kind.
const LEGEND: Dictionary[String, int] = {
	".": Kind.GRASS, ",": Kind.TALL_GRASS, "_": Kind.PATH, "~": Kind.WATER, "T": Kind.TREE,
	"H": Kind.WALL, "R": Kind.ROOF, "D": Kind.DOOR, "f": Kind.FLOOR, "#": Kind.FENCE,
	"S": Kind.SIGN, "*": Kind.FLOWER, "C": Kind.COUNTER, "W": Kind.INNER_WALL, "o": Kind.SPRING,
	"X": Kind.RIFT,
}

const SOLID: Array[int] = [Kind.WATER, Kind.TREE, Kind.WALL, Kind.ROOF, Kind.FENCE, Kind.SIGN, Kind.COUNTER, Kind.INNER_WALL, Kind.SPRING]

const COLORS: Dictionary[int, Color] = {
	Kind.GRASS: Color("9cc46a"), Kind.TALL_GRASS: Color("5f9a3e"), Kind.PATH: Color("d8c08a"),
	Kind.WATER: Color("4a86c8"), Kind.TREE: Color("2f5e2a"), Kind.WALL: Color("e3d6b8"),
	Kind.ROOF: Color("a9533c"), Kind.DOOR: Color("5a3a28"), Kind.FLOOR: Color("c9a26e"),
	Kind.FENCE: Color("8a6440"), Kind.SIGN: Color("b88a52"), Kind.FLOWER: Color("9cc46a"),
	Kind.COUNTER: Color("7a5a3a"), Kind.INNER_WALL: Color("6b5a4a"), Kind.SPRING: Color("7fc6e0"),
	Kind.RIFT: Color("3a2a55"),
}

static var _tileset: TileSet

static func kind_for(ch: String) -> int:
	return LEGEND.get(ch, Kind.GRASS)

static func is_solid(kind: int) -> bool:
	return kind in SOLID

static func get_tileset() -> TileSet:
	if _tileset == null:
		_tileset = _build()
	return _tileset

static func _build() -> TileSet:
	var count: int = Kind.size()
	var img := Image.create(TILE * count, TILE, false, Image.FORMAT_RGBA8)
	for k: int in count:
		_paint(img, k)
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	for k: int in count:
		src.create_tile(Vector2i(k, 0))
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
