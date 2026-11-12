class_name ElementIcons
extends RefCounted
## Original 7x7 pixel symbols for the elements, so an element never depends on colour alone
## (Era I shows only four greens, and some players can't tell colours apart).

const SIZE: int = 7
const GLYPHS: Dictionary[int, Array] = {
	Elements.E.EMBER: ["...#...", "..##...", "..###..", ".##.##.", ".#...#.", ".##.##.", "..###.."],  # flame
	Elements.E.TIDE:  [".......", ".##....", "#..#..#", "....##.", ".##....", "#..#..#", "....##."],  # two waves
	Elements.E.BLOOM: ["....###", "..##..#", ".#...#.", ".#..#..", ".#.#...", "..#....", ".#....."],  # leaf
	Elements.E.VOLT:  ["...##..", "..##...", ".##....", ".####..", "...##..", "..##...", ".#....."],  # bolt
	Elements.E.STONE: [".......", "..###..", ".#...#.", "#..#..#", "#.#...#", ".#...#.", "..###.."],  # pebble
	Elements.E.GALE:  [".......", "#####..", ".....#.", "####.#.", "....#..", "######.", "......#"],  # gusts
	Elements.E.LUMEN: ["...#...", ".#.#.#.", "..###..", "###.###", "..###..", ".#.#.#.", "...#..."],  # star
	Elements.E.UMBRA: ["..###..", ".##....", "##.....", "##.....", "##.....", ".##....", "..###.."],  # crescent
	Elements.E.INK:   ["......#", ".....#.", "....#..", "...#...", "..#....", ".###...", "..#...."],  # quill and drop
	Elements.E.ECHO:  ["..###..", ".#...#.", ".#...#.", ".#...#.", "#######", "...#...", "......."],  # bell
	Elements.E.RUST:  ["..#.#..", ".#####.", "##...##", ".#.#.#.", "##...##", ".#####.", "..#.#.."],  # cog
	Elements.E.MASK:  [".......", "#######", "#.###.#", "#######", ".#####.", "..#.#..", "......."],  # mask
	Elements.E.ACID:  ["...#...", "..###..", ".##.##.", ".#####.", "..###..", "#.....#", ".#...#."],  # drop and fizz
	Elements.E.FROST: ["...#...", "#.#.#.#", ".#####.", "##.#.##", ".#####.", "#.#.#.#", "...#..."],  # snowflake
	Elements.E.GILT:  [".......", "..###..", ".#...#.", "#.###.#", ".#...#.", "..###..", "......."],  # coin
	Elements.E.ZENITH: ["...#...", "..###..", ".#.#.#.", "...#...", ".......", "#######", "......."],  # sun over the horizon
}

static var _cache: Dictionary[String, ImageTexture] = {}

static func texture(element: int, color: Color = UITheme.INK) -> ImageTexture:
	var key: String = "%d:%s" % [element, color.to_html()]
	if not _cache.has(key):
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		_paint(img, element, color, Vector2i.ZERO)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

## 9x9 version with a 1 px paper outline, readable on light and dark (focused) buttons.
static func outlined(element: int, color: Color = UITheme.INK, outline: Color = UITheme.BG) -> ImageTexture:
	var key: String = "o%d:%s:%s" % [element, color.to_html(), outline.to_html()]
	if not _cache.has(key):
		var img := Image.create(SIZE + 2, SIZE + 2, false, Image.FORMAT_RGBA8)
		var rows: Array = GLYPHS.get(element, [])
		for y: int in rows.size():
			for x: int in mini(String(rows[y]).length(), SIZE):
				if String(rows[y])[x] == "#":
					for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]:
						img.set_pixelv(Vector2i(x, y) + d, outline)
		_paint(img, element, color, Vector2i.ONE)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

static func _paint(img: Image, element: int, color: Color, offset: Vector2i) -> void:
	var rows: Array = GLYPHS.get(element, [])
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in mini(row.length(), SIZE):
			if row[x] == "#":
				img.set_pixel(x + offset.x, y + offset.y, color)

## Draws the icons for [param elements] left to right on [param canvas]; returns the width used.
static func draw_row(canvas: CanvasItem, elements: Array[int], at: Vector2, color: Color = UITheme.INK) -> float:
	var x: float = at.x
	for e: int in elements:
		canvas.draw_texture(texture(e, color), Vector2(x, at.y))
		x += SIZE + 1
	return x - at.x
