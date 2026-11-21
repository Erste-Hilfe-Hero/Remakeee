class_name HatArt
extends RefCounted
## Wanderer hats from the shop (item 4283), drawn with primitives in the ink palette.
## Only looks. The same drawing is used on the map walker and in the battle picture.

const KINDS: Array[String] = ["wide_brim", "wool_cap", "feather_hat", "lantern_hood", "straw_hat", "tricorn"]

## The hat's pixel rects [x, y, w, h, colour] around the middle of its brim (0, 0).
static func rects(kind: String) -> Array:
	match kind:
		"wide_brim":
			return [[-6, 0, 12, 1, UITheme.INK], [-3, -3, 6, 3, UITheme.MID], [-3, -1, 6, 1, UITheme.INK]]
		"wool_cap":
			return [[-4, -1, 8, 2, UITheme.ACCENT], [-3, -3, 6, 2, UITheme.MID], [-1, -4, 2, 1, UITheme.ACCENT], [-4, 0, 8, 1, UITheme.INK]]
		"feather_hat":
			return [[-4, 0, 8, 1, UITheme.INK], [-3, -2, 6, 2, UITheme.MID], [2, -5, 1, 3, UITheme.ACCENT], [3, -6, 1, 2, UITheme.BG]]
		"lantern_hood":
			return [[-4, -3, 8, 4, UITheme.INK], [-3, -2, 6, 2, UITheme.MID], [-1, -5, 2, 2, UITheme.ACCENT]]
		"straw_hat":
			return [[-6, 0, 12, 1, UITheme.ACCENT], [-3, -2, 6, 2, UITheme.ACCENT], [-3, -1, 6, 1, UITheme.MID], [-6, 1, 12, 1, UITheme.INK]]
		"tricorn":
			return [[-5, -1, 10, 2, UITheme.INK], [-3, -3, 6, 2, UITheme.INK], [-5, -2, 1, 1, UITheme.INK], [4, -2, 1, 1, UITheme.INK], [-2, -2, 4, 1, UITheme.ACCENT]]
	return []

## Draws hat [param kind] on [param ci] with the middle of its brim at [param at].
## [param s] scales every pixel (1 on the map, 2 in the battle picture).
static func draw(ci: CanvasItem, at: Vector2, kind: String, s: int = 1) -> void:
	var o: Vector2 = at.round()
	for r: Array in rects(kind):
		ci.draw_rect(Rect2(o.x + r[0] * s, o.y + r[1] * s, r[2] * s, r[3] * s), r[4])

## Paints hat [param kind] into [param img] at [param at], each pixel [param s] wide (shop preview).
static func paint(img: Image, at: Vector2i, kind: String, s: int = 1) -> void:
	for r: Array in rects(kind):
		img.fill_rect(Rect2i(at.x + r[0] * s, at.y + r[1] * s, r[2] * s, r[3] * s), r[4])
