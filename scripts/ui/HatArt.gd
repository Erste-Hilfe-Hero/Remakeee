class_name HatArt
extends RefCounted
## Wanderer hats from the shop (item 4283), drawn with primitives in the ink palette.
## Only looks. The same drawing is used on the map walker and in the battle picture.

const KINDS: Array[String] = ["wide_brim", "wool_cap", "feather_hat", "lantern_hood", "straw_hat", "tricorn"]

## Draws hat [param kind] on [param ci] with the middle of its brim at [param at].
## [param s] scales every pixel (1 on the map, 2 in the battle picture).
static func draw(ci: CanvasItem, at: Vector2, kind: String, s: int = 1) -> void:
	if not kind in KINDS:
		return
	var o: Vector2 = at.round()
	var px := func(x: int, y: int, w: int, h: int, c: Color) -> void:
		ci.draw_rect(Rect2(o.x + x * s, o.y + y * s, w * s, h * s), c)
	match kind:
		"wide_brim":
			px.call(-6, 0, 12, 1, UITheme.INK)
			px.call(-3, -3, 6, 3, UITheme.MID)
			px.call(-3, -1, 6, 1, UITheme.INK)
		"wool_cap":
			px.call(-4, -1, 8, 2, UITheme.ACCENT)
			px.call(-3, -3, 6, 2, UITheme.MID)
			px.call(-1, -4, 2, 1, UITheme.ACCENT)
			px.call(-4, 0, 8, 1, UITheme.INK)
		"feather_hat":
			px.call(-4, 0, 8, 1, UITheme.INK)
			px.call(-3, -2, 6, 2, UITheme.MID)
			px.call(2, -5, 1, 3, UITheme.ACCENT)
			px.call(3, -6, 1, 2, UITheme.BG)
		"lantern_hood":
			px.call(-4, -3, 8, 4, UITheme.INK)
			px.call(-3, -2, 6, 2, UITheme.MID)
			px.call(-1, -5, 2, 2, UITheme.ACCENT)
		"straw_hat":
			px.call(-6, 0, 12, 1, UITheme.ACCENT)
			px.call(-3, -2, 6, 2, UITheme.ACCENT)
			px.call(-3, -1, 6, 1, UITheme.MID)
			px.call(-6, 1, 12, 1, UITheme.INK)
		"tricorn":
			px.call(-5, -1, 10, 2, UITheme.INK)
			px.call(-3, -3, 6, 2, UITheme.INK)
			px.call(-5, -2, 1, 1, UITheme.INK)
			px.call(4, -2, 1, 1, UITheme.INK)
			px.call(-2, -2, 4, 1, UITheme.ACCENT)
