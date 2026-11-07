class_name BattleBackdrop
extends Control
## Era I battle backdrop drawn with primitives: sky, a horizon that matches the place the
## battle started (field, lake, ridge or ember hollow) and two raised earth banks the
## Spirlings stand on. Banks are flat-topped slabs, not oval platforms (LEGAL.md layout rule).

## "voice": the lake at night with columns of light, only for First Voices (plan area 1, item 154).
const KINDS: Array[String] = ["field", "lake", "ridge", "ember", "voice"]
## Shop backdrops (item 4281): only looks, worn from the shop page of an owned one.
const SHOP_KINDS: Array[String] = ["moon_lake", "copper_wood", "mist_harbour", "star_meadow", "ash_field", "glass_grotto"]
const HORIZON: float = 0.42
const BANK_DEPTH: int = 7

var kind: String = "field"
var foe_rect: Rect2
var player_rect: Rect2

func set_scene(p_kind: String, p_foe: Rect2, p_player: Rect2) -> void:
	kind = p_kind if p_kind in KINDS or p_kind in SHOP_KINDS else "field"
	foe_rect = p_foe
	player_rect = p_player
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var hy: float = floorf(h * HORIZON)
	draw_rect(Rect2(0, 0, w, h), UITheme.BG)
	# Dithered haze at the top of the sky.
	for y: int in 6:
		for x: int in int(w):
			if (x + y) % (2 + y) == 0:
				draw_rect(Rect2(x, y, 1, 1), UITheme.ACCENT)
	_cloud(Vector2(w * 0.18, hy * 0.35), 14)
	_cloud(Vector2(w * 0.62, hy * 0.18), 10)
	if kind in SHOP_KINDS:
		_draw_shop(w, h, hy)
	else:
		_draw_place(w, h, hy)
	if foe_rect.size.x > 0.0:
		_bank(Rect2(foe_rect.position.x - 8, foe_rect.end.y - 6, foe_rect.size.x + 16, BANK_DEPTH))
	if player_rect.size.x > 0.0:
		_bank(Rect2(-4, player_rect.end.y - 6, player_rect.end.x + 18, BANK_DEPTH + 4))

func _draw_shop(w: float, h: float, hy: float) -> void:
	match kind:
		"moon_lake":
			draw_rect(Rect2(0, 0, w, hy), UITheme.INK)
			draw_circle(Vector2(w * 0.72, hy * 0.35), 7.0, UITheme.BG)
			draw_circle(Vector2(w * 0.72 + 3, hy * 0.35 - 2), 6.0, UITheme.INK)
			for i: int in 10:
				draw_rect(Rect2(fmod(i * 47.0, w), 3 + fmod(i * 13.0, hy - 8), 1, 1), UITheme.BG)
			_hills(hy, 4.0, 0.09, UITheme.MID)
			draw_rect(Rect2(0, hy, w, h - hy), UITheme.MID)
			for i: int in 6:
				var y: float = hy + 5 + i * 10
				draw_rect(Rect2(w * 0.72 - 6 + (i % 2) * 3, y, 12 - i, 1), UITheme.BG)
				draw_rect(Rect2(fmod(i * 53.0, w), y + 3, 8, 1), UITheme.ACCENT)
		"copper_wood":
			_hills(hy, 6.0, 0.08, UITheme.MID)
			for i: int in 9:
				var x: float = fmod(i * 31.0 + 5.0, w)
				var top: float = hy - 26.0 - fmod(i * 7.0, 10.0)
				draw_rect(Rect2(x + 3, top + 12, 2, hy - top - 12), UITheme.INK)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 2, top + 16), Vector2(x + 4, top), Vector2(x + 10, top + 16)]), UITheme.MID)
				draw_polyline(PackedVector2Array([Vector2(x - 2, top + 16), Vector2(x + 4, top), Vector2(x + 10, top + 16)]), UITheme.INK, 1.0)
			_ground(hy)
			for i: int in 14:
				draw_rect(Rect2(fmod(i * 23.0, w), hy + 3 + fmod(i * 11.0, h - hy - 6), 2, 1), UITheme.MID)
		"mist_harbour":
			_hills(hy, 3.0, 0.05, UITheme.MID)
			draw_rect(Rect2(0, hy, w, h - hy), UITheme.ACCENT)
			for i: int in 5:
				var x: float = w * (0.08 + i * 0.21)
				draw_rect(Rect2(x, hy - 10, 2, 22), UITheme.INK)
			for i: int in 4:
				var y: float = hy - 6 + i * 12
				for x: int in range(0, int(w), 2):
					if (x / 2 + i) % 3 != 0:
						draw_rect(Rect2(x, y, 1, 1), UITheme.BG)
		"star_meadow":
			draw_rect(Rect2(0, 0, w, hy), UITheme.INK)
			for i: int in 18:
				var p := Vector2(fmod(i * 37.0 + 3.0, w), 2 + fmod(i * 19.0, hy - 6))
				draw_rect(Rect2(p, Vector2.ONE), UITheme.BG)
				if i % 4 == 0:
					draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), UITheme.ACCENT)
			_ground(hy)
			for i: int in 16:
				draw_rect(Rect2(fmod(i * 29.0 + 11.0, w), hy + 4 + fmod(i * 13.0, h - hy - 6), 1, 1), UITheme.BG)
		"ash_field":
			draw_rect(Rect2(0, 0, w, hy), UITheme.MID)
			_peaks(hy, 18.0, 7, UITheme.INK)
			_ground(hy)
			for i: int in 24:
				draw_rect(Rect2(fmod(i * 41.0, w), fmod(i * 23.0, h), 1, 1), UITheme.BG)
		"glass_grotto":
			draw_rect(Rect2(0, 0, w, h), UITheme.INK)
			var step: float = w / 9.0
			for i: int in 10:
				var x: float = i * step
				draw_colored_polygon(PackedVector2Array([Vector2(x - step * 0.5, 0), Vector2(x, 10.0 + fmod(i * 7.0, 12.0)), Vector2(x + step * 0.5, 0)]), UITheme.MID)
			draw_rect(Rect2(0, hy, w, h - hy), UITheme.MID)
			for i: int in 6:
				var x: float = w * (0.06 + i * 0.17)
				draw_colored_polygon(PackedVector2Array([Vector2(x, hy), Vector2(x + 3, hy - 12.0 - (i % 3) * 4), Vector2(x + 6, hy)]), UITheme.ACCENT)
				draw_line(Vector2(x + 3, hy - 10.0 - (i % 3) * 4), Vector2(x + 3, hy - 2), UITheme.BG, 1.0)

func _draw_place(w: float, h: float, hy: float) -> void:
	match kind:
		"lake":
			_hills(hy, 5.0, 0.11, UITheme.MID)
			draw_rect(Rect2(0, hy, w, h - hy), UITheme.ACCENT)
			for i: int in 7:
				var y: float = hy + 4 + i * 9
				var x0: float = fmod(i * 37.0, w)
				draw_rect(Rect2(x0, y, 10, 1), UITheme.BG)
				draw_rect(Rect2(fmod(x0 + 60.0, w), y + 4, 6, 1), UITheme.MID)
		"voice":
			draw_rect(Rect2(0, 0, w, hy), UITheme.INK)
			for i: int in 12:
				draw_rect(Rect2(fmod(i * 53.0, w), 4 + fmod(i * 17.0, hy - 10), 1, 1), UITheme.BG)
			draw_rect(Rect2(0, hy, w, h - hy), UITheme.MID)
			for i: int in 4:
				var x: float = w * (0.15 + i * 0.24)
				for y: int in range(int(hy * 0.2), int(hy), 2):
					draw_rect(Rect2(x, y, 2, 1), UITheme.ACCENT)
			for i: int in 7:
				var y: float = hy + 4 + i * 9
				var x0: float = fmod(i * 41.0, w)
				draw_rect(Rect2(x0, y, 12, 1), UITheme.BG)
		"ridge":
			_peaks(hy, 22.0, 9, UITheme.MID)
			_ground(hy)
		"ember":
			_peaks(hy, 30.0, 6, UITheme.INK)
			for i: int in 3:
				var x: float = w * (0.2 + i * 0.3)
				draw_rect(Rect2(x, hy - 34 - i * 4, 3, 3), UITheme.MID)
				draw_rect(Rect2(x + 3, hy - 40 - i * 4, 2, 2), UITheme.MID)
			_ground(hy)
		_:
			_hills(hy, 9.0, 0.07, UITheme.MID)
			_ground(hy)

func _ground(hy: float) -> void:
	draw_rect(Rect2(0, hy, size.x, size.y - hy), UITheme.ACCENT)
	draw_rect(Rect2(0, hy, size.x, 1), UITheme.INK)
	for i: int in 18:
		var x: float = fmod(i * 29.0 + 7.0, size.x)
		var y: float = hy + 6 + fmod(i * 17.0, size.y - hy - 8)
		draw_rect(Rect2(x, y, 1, 1), UITheme.MID)
		draw_rect(Rect2(x + 2, y, 1, 1), UITheme.MID)
		draw_rect(Rect2(x + 1, y + 1, 1, 1), UITheme.MID)

func _hills(hy: float, amp: float, freq: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, hy))
	for x: int in range(0, int(size.x) + 4, 4):
		pts.append(Vector2(x, roundf(hy - amp - amp * sin(x * freq) * 0.8 - 3.0 * sin(x * freq * 3.1))))
	pts.append(Vector2(size.x, hy))
	draw_colored_polygon(pts, col)
	for i: int in range(1, pts.size() - 2):
		draw_line(pts[i], pts[i + 1], UITheme.INK, 1.0)

func _peaks(hy: float, height: float, count: int, col: Color) -> void:
	var step: float = size.x / float(count)
	var pts := PackedVector2Array([Vector2(0, hy)])
	for i: int in count + 1:
		var x: float = i * step
		var tall: float = height * (0.55 + 0.45 * absf(sin(i * 1.7)))
		pts.append(Vector2(x - step * 0.5, hy - tall))
		pts.append(Vector2(x, hy - tall * 0.35))
	pts.append(Vector2(size.x, hy))
	draw_colored_polygon(pts, col)
	draw_polyline(pts, UITheme.INK, 1.0)

func _cloud(at: Vector2, w: float) -> void:
	var p: Vector2 = at.round()
	draw_rect(Rect2(p.x, p.y, w, 3), UITheme.ACCENT)
	draw_rect(Rect2(p.x + 3, p.y - 2, w * 0.5, 2), UITheme.ACCENT)
	draw_rect(Rect2(p.x, p.y + 3, w, 1), UITheme.MID)

## A flat-topped earth slab: grass lip, ink edge, dithered soil face.
func _bank(r: Rect2) -> void:
	var rr := Rect2(r.position.round(), r.size.round())
	draw_rect(rr, UITheme.MID)
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, 2)), UITheme.ACCENT)
	draw_rect(Rect2(rr.position + Vector2(0, 2), Vector2(rr.size.x, 1)), UITheme.INK)
	draw_rect(Rect2(rr.position + Vector2(0, rr.size.y - 1), Vector2(rr.size.x, 1)), UITheme.INK)
	for x: int in range(int(rr.position.x), int(rr.end.x), 2):
		for y: int in range(int(rr.position.y) + 4, int(rr.end.y) - 1, 2):
			if (x / 2 + y / 2) % 2 == 0:
				draw_rect(Rect2(x, y, 1, 1), UITheme.INK)
	# Grass tufts along the lip.
	for x: int in range(int(rr.position.x) + 3, int(rr.end.x) - 2, 7):
		draw_rect(Rect2(x, rr.position.y - 1, 1, 1), UITheme.INK)
		draw_rect(Rect2(x + 2, rr.position.y - 1, 1, 1), UITheme.INK)
