class_name SpirlogMarks
extends RefCounted
## Own 7x7 marks for the Spirlog list (plan item 1934): an eye for "seen", a band for
## "bonded", and an empty space of the same size so names line up.

const LEGEND: String = "Eye: seen. Band: bonded."

const EYE: Array[String] = [".......", ".......", "..###..", ".#.#.#.", "#.###.#", ".#...#.", "..###.."]
const BAND: Array[String] = ["..###..", ".#...#.", "#.....#", "#######", "#.....#", ".#...#.", "..###.."]

static var _cache: Dictionary[String, ImageTexture] = {}

static func seen() -> Texture2D:
	return _make("eye", EYE)

static func bonded() -> Texture2D:
	return _make("band", BAND)

static func none() -> Texture2D:
	return _make("none", [] as Array[String])

static func _make(key: String, rows: Array[String]) -> Texture2D:
	var k: String = key + UITheme.INK.to_html()
	if _cache.has(k):
		return _cache[k]
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == "#":
				img.set_pixel(x, y, UITheme.INK)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex
