class_name SpirlogMarks
extends RefCounted
## Own 7x7 marks for the Spirlog list (plan item 1934): an eye for "seen", a band for
## "bonded", and an empty space of the same size so names line up. A lantern marks a kind that
## joined from an event such as the Lamp Watch (200 list item 137).

const LEGEND: String = "Eye: seen. Band: bonded."

const EYE: Array[String] = [".......", ".......", "..###..", ".#.#.#.", "#.###.#", ".#...#.", "..###.."]
const LANTERN: Array[String] = ["..###..", "...#...", ".#####.", ".#.#.#.", ".#.#.#.", ".#####.", "..###.."]
const BAND: Array[String] = ["..###..", ".#...#.", "#.....#", "#######", "#.....#", ".#...#.", "..###.."]

static var _cache: Dictionary[String, ImageTexture] = {}

static func seen() -> Texture2D:
	return _make("eye", EYE)

static func bonded() -> Texture2D:
	return _make("band", BAND)

## The event badge: a small lantern.
static func event(ink: Color = UITheme.INK) -> Texture2D:
	return _make("lantern", LANTERN, ink)

## Draws the event badge at the right end of a Spirlog row [param b].
static func draw_event_badge(b: Button) -> void:
	var tex: Texture2D = event(b.get_theme_color("font_focus_color" if b.has_focus() else "font_color", "Button"))
	b.draw_texture(tex, Vector2(b.size.x - tex.get_width() - 4, floorf((b.size.y - tex.get_height()) / 2.0)))

static func none() -> Texture2D:
	return _make("none", [] as Array[String])

static func _make(key: String, rows: Array[String], ink: Color = UITheme.INK) -> Texture2D:
	var k: String = key + ink.to_html()
	if _cache.has(k):
		return _cache[k]
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == "#":
				img.set_pixel(x, y, ink)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex
