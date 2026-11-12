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
## Worn shop hat (HatArt.KINDS, item 4283): the Wayfarer is then seen from behind beside the
## partner, wearing it. "" draws no Wayfarer.
var hat: String = ""
## Colour roles of the era (data/era_battle_feel.json "backdrop_colours"): Era I keeps the
## screen inks (the palette filter maps them), Era II takes a few flat colours per place, Era III
## a richer set with a two-tone sky and a highlight on the banks.
var era: int = 1
var _bg: Color = UITheme.BG
var _ink: Color = UITheme.INK
var _mid: Color = UITheme.MID
var _acc: Color = UITheme.ACCENT
var _sky: Color = Color.TRANSPARENT
var _sky_low: Color = Color.TRANSPARENT
var _hi: Color = Color.TRANSPARENT
## Sky bands of the Era III gradient (each band dithers into the next).
const SKY_BANDS: int = 8

func set_scene(p_kind: String, p_foe: Rect2, p_player: Rect2) -> void:
	kind = p_kind if p_kind in KINDS or p_kind in SHOP_KINDS else "field"
	foe_rect = p_foe
	player_rect = p_player
	era = EraManager.active_era()
	_apply_colours(EraBattleFeel.backdrop_colours(era, kind))
	queue_redraw()

func _apply_colours(c: Dictionary) -> void:
	_bg = Color(str(c.get("bg", UITheme.BG.to_html())))
	_ink = Color(str(c.get("ink", UITheme.INK.to_html())))
	_mid = Color(str(c.get("mid", UITheme.MID.to_html())))
	_acc = Color(str(c.get("accent", UITheme.ACCENT.to_html())))
	_sky = Color(str(c["sky"])) if c.has("sky") else Color.TRANSPARENT
	_sky_low = Color(str(c["sky_low"])) if c.has("sky_low") else Color.TRANSPARENT
	_hi = Color(str(c["hi"])) if c.has("hi") else Color.TRANSPARENT

## Era II: one flat sky colour. Era III: [constant SKY_BANDS] bands from the top colour to the
## low one, each border dithered on a 2 px checker. Era I keeps the parchment haze.
func _draw_sky(w: float, hy: float) -> void:
	if _sky.a <= 0.0:
		for y: int in 6:
			for x: int in int(w):
				if (x + y) % (2 + y) == 0:
					draw_rect(Rect2(x, y, 1, 1), _acc)
		return
	if _sky_low.a <= 0.0:
		draw_rect(Rect2(0, 0, w, hy), _sky)
		return
	var band: float = ceilf(hy / SKY_BANDS)
	for i: int in SKY_BANDS:
		draw_rect(Rect2(0, i * band, w, band), _sky.lerp(_sky_low, i / float(SKY_BANDS - 1)))
		if i > 0:
			var prev: Color = _sky.lerp(_sky_low, (i - 1) / float(SKY_BANDS - 1))
			for x: int in range(0, int(w), 2):
				draw_rect(Rect2(x + (i % 2), i * band, 1, 1), prev)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var hy: float = floorf(h * HORIZON)
	draw_rect(Rect2(0, 0, w, h), _bg)
	_draw_sky(w, hy)
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
		if hat in HatArt.KINDS:
			_wayfarer(Vector2(player_rect.position.x - 4, player_rect.end.y - 3))

## The Wayfarer from behind (head and shoulders) with the worn hat; [param foot] is the
## bottom middle.
func _wayfarer(foot: Vector2) -> void:
	var f: Vector2 = foot.round()
	draw_rect(Rect2(f.x - 7, f.y - 6, 14, 6), GameState.body_color())
	draw_rect(Rect2(f.x - 7, f.y - 6, 14, 6), _ink, false, 1.0)
	draw_rect(Rect2(f.x - 3, f.y - 12, 6, 6), _ink)
	draw_rect(Rect2(f.x - 2, f.y - 11, 4, 4), _mid)
	HatArt.draw(self, Vector2(f.x, f.y - 11), hat)

func _draw_shop(w: float, h: float, hy: float) -> void:
	match kind:
		"moon_lake":
			draw_rect(Rect2(0, 0, w, hy), _ink)
			draw_circle(Vector2(w * 0.72, hy * 0.35), 7.0, _bg)
			draw_circle(Vector2(w * 0.72 + 3, hy * 0.35 - 2), 6.0, _ink)
			for i: int in 10:
				draw_rect(Rect2(fmod(i * 47.0, w), 3 + fmod(i * 13.0, hy - 8), 1, 1), _bg)
			_hills(hy, 4.0, 0.09, _mid)
			draw_rect(Rect2(0, hy, w, h - hy), _mid)
			for i: int in 6:
				var y: float = hy + 5 + i * 10
				draw_rect(Rect2(w * 0.72 - 6 + (i % 2) * 3, y, 12 - i, 1), _bg)
				draw_rect(Rect2(fmod(i * 53.0, w), y + 3, 8, 1), _acc)
		"copper_wood":
			_hills(hy, 6.0, 0.08, _mid)
			for i: int in 9:
				var x: float = fmod(i * 31.0 + 5.0, w)
				var top: float = hy - 26.0 - fmod(i * 7.0, 10.0)
				draw_rect(Rect2(x + 3, top + 12, 2, hy - top - 12), _ink)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 2, top + 16), Vector2(x + 4, top), Vector2(x + 10, top + 16)]), _mid)
				draw_polyline(PackedVector2Array([Vector2(x - 2, top + 16), Vector2(x + 4, top), Vector2(x + 10, top + 16)]), _ink, 1.0)
			_ground(hy)
			for i: int in 14:
				draw_rect(Rect2(fmod(i * 23.0, w), hy + 3 + fmod(i * 11.0, h - hy - 6), 2, 1), _mid)
		"mist_harbour":
			_hills(hy, 3.0, 0.05, _mid)
			draw_rect(Rect2(0, hy, w, h - hy), _acc)
			for i: int in 5:
				var x: float = w * (0.08 + i * 0.21)
				draw_rect(Rect2(x, hy - 10, 2, 22), _ink)
			for i: int in 4:
				var y: float = hy - 6 + i * 12
				for x: int in range(0, int(w), 2):
					if (x / 2 + i) % 3 != 0:
						draw_rect(Rect2(x, y, 1, 1), _bg)
		"star_meadow":
			draw_rect(Rect2(0, 0, w, hy), _ink)
			for i: int in 18:
				var p := Vector2(fmod(i * 37.0 + 3.0, w), 2 + fmod(i * 19.0, hy - 6))
				draw_rect(Rect2(p, Vector2.ONE), _bg)
				if i % 4 == 0:
					draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), _acc)
			_ground(hy)
			for i: int in 16:
				draw_rect(Rect2(fmod(i * 29.0 + 11.0, w), hy + 4 + fmod(i * 13.0, h - hy - 6), 1, 1), _bg)
		"ash_field":
			draw_rect(Rect2(0, 0, w, hy), _mid)
			_peaks(hy, 18.0, 7, _ink)
			_ground(hy)
			for i: int in 24:
				draw_rect(Rect2(fmod(i * 41.0, w), fmod(i * 23.0, h), 1, 1), _bg)
		"glass_grotto":
			draw_rect(Rect2(0, 0, w, h), _ink)
			var step: float = w / 9.0
			for i: int in 10:
				var x: float = i * step
				draw_colored_polygon(PackedVector2Array([Vector2(x - step * 0.5, 0), Vector2(x, 10.0 + fmod(i * 7.0, 12.0)), Vector2(x + step * 0.5, 0)]), _mid)
			draw_rect(Rect2(0, hy, w, h - hy), _mid)
			for i: int in 6:
				var x: float = w * (0.06 + i * 0.17)
				draw_colored_polygon(PackedVector2Array([Vector2(x, hy), Vector2(x + 3, hy - 12.0 - (i % 3) * 4), Vector2(x + 6, hy)]), _acc)
				draw_line(Vector2(x + 3, hy - 10.0 - (i % 3) * 4), Vector2(x + 3, hy - 2), _bg, 1.0)

func _draw_place(w: float, h: float, hy: float) -> void:
	match kind:
		"lake":
			_hills(hy, 5.0, 0.11, _mid)
			draw_rect(Rect2(0, hy, w, h - hy), _acc)
			for i: int in 7:
				var y: float = hy + 4 + i * 9
				var x0: float = fmod(i * 37.0, w)
				draw_rect(Rect2(x0, y, 10, 1), _bg)
				draw_rect(Rect2(fmod(x0 + 60.0, w), y + 4, 6, 1), _mid)
		"voice":
			draw_rect(Rect2(0, 0, w, hy), _ink)
			for i: int in 12:
				draw_rect(Rect2(fmod(i * 53.0, w), 4 + fmod(i * 17.0, hy - 10), 1, 1), _bg)
			draw_rect(Rect2(0, hy, w, h - hy), _mid)
			for i: int in 4:
				var x: float = w * (0.15 + i * 0.24)
				for y: int in range(int(hy * 0.2), int(hy), 2):
					draw_rect(Rect2(x, y, 2, 1), _acc)
			for i: int in 7:
				var y: float = hy + 4 + i * 9
				var x0: float = fmod(i * 41.0, w)
				draw_rect(Rect2(x0, y, 12, 1), _bg)
		"ridge":
			_peaks(hy, 22.0, 9, _mid)
			_ground(hy)
		"ember":
			_peaks(hy, 30.0, 6, _ink)
			for i: int in 3:
				var x: float = w * (0.2 + i * 0.3)
				draw_rect(Rect2(x, hy - 34 - i * 4, 3, 3), _mid)
				draw_rect(Rect2(x + 3, hy - 40 - i * 4, 2, 2), _mid)
			_ground(hy)
		_:
			_hills(hy, 9.0, 0.07, _mid)
			_ground(hy)

func _ground(hy: float) -> void:
	draw_rect(Rect2(0, hy, size.x, size.y - hy), _acc)
	draw_rect(Rect2(0, hy, size.x, 1), _ink)
	for i: int in 18:
		var x: float = fmod(i * 29.0 + 7.0, size.x)
		var y: float = hy + 6 + fmod(i * 17.0, size.y - hy - 8)
		draw_rect(Rect2(x, y, 1, 1), _mid)
		draw_rect(Rect2(x + 2, y, 1, 1), _mid)
		draw_rect(Rect2(x + 1, y + 1, 1, 1), _mid)

func _hills(hy: float, amp: float, freq: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, hy))
	for x: int in range(0, int(size.x) + 4, 4):
		pts.append(Vector2(x, roundf(hy - amp - amp * sin(x * freq) * 0.8 - 3.0 * sin(x * freq * 3.1))))
	pts.append(Vector2(size.x, hy))
	draw_colored_polygon(pts, col)
	for i: int in range(1, pts.size() - 2):
		draw_line(pts[i], pts[i + 1], _ink, 1.0)

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
	draw_polyline(pts, _ink, 1.0)

func _cloud(at: Vector2, w: float) -> void:
	var p: Vector2 = at.round()
	draw_rect(Rect2(p.x, p.y, w, 3), _acc)
	draw_rect(Rect2(p.x + 3, p.y - 2, w * 0.5, 2), _acc)
	draw_rect(Rect2(p.x, p.y + 3, w, 1), _mid)

## A flat-topped earth slab: grass lip, ink edge, dithered soil face.
func _bank(r: Rect2) -> void:
	var rr := Rect2(r.position.round(), r.size.round())
	draw_rect(rr, _mid)
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, 2)), _acc)
	draw_rect(Rect2(rr.position + Vector2(0, 2), Vector2(rr.size.x, 1)), _ink)
	draw_rect(Rect2(rr.position + Vector2(0, rr.size.y - 1), Vector2(rr.size.x, 1)), _ink)
	for x: int in range(int(rr.position.x), int(rr.end.x), 2):
		for y: int in range(int(rr.position.y) + 4, int(rr.end.y) - 1, 2):
			if (x / 2 + y / 2) % 2 == 0:
				draw_rect(Rect2(x, y, 1, 1), _ink)
	# Era III: a light edge along the lip and a darker foot, so the bank reads as raised.
	if _hi.a > 0.0:
		draw_rect(Rect2(rr.position + Vector2(1, 0), Vector2(rr.size.x - 2, 1)), _hi)
		draw_rect(Rect2(rr.position + Vector2(0, rr.size.y), Vector2(rr.size.x, 1)), Color(_ink, 0.4))
	if era >= 2:
		_bank_terrain(rr)
		return
	# Grass tufts along the lip.
	for x: int in range(int(rr.position.x) + 3, int(rr.end.x) - 2, 7):
		draw_rect(Rect2(x, rr.position.y - 1, 1, 1), _ink)
		draw_rect(Rect2(x + 2, rr.position.y - 1, 1, 1), _ink)

## Era II/III: each place gets its own bank (owner plan, per-terrain platforms): lake banks are
## stepping stones with water lapping at the foot, ridge banks cut stone, ember banks basalt with
## glowing cracks, voice banks glow with motes, field banks keep their grass.
func _bank_terrain(rr: Rect2) -> void:
	var x0: int = int(rr.position.x)
	var x1: int = int(rr.end.x)
	var top: float = rr.position.y
	var foot: float = rr.end.y
	match kind:
		"lake":
			for x: int in range(x0 - 4, x1 + 4, 6):
				draw_rect(Rect2(x, foot + 1, 3, 1), _acc)
				draw_rect(Rect2(x + 3, foot + 3, 2, 1), _bg)
			for x: int in range(x0 + 6, x1 - 4, 12):
				draw_rect(Rect2(x, top + 4, 1, rr.size.y - 5), _ink)
		"ridge":
			for row: int in 2:
				var y: float = top + 3 + row * 3
				for x: int in range(x0 + (row * 4), x1, 8):
					draw_rect(Rect2(x, y, 1, 3), _ink)
			for x: int in range(x0 + 2, x1 - 2, 9):
				draw_rect(Rect2(x, top - 1, 3, 1), _mid)
		"ember":
			for x: int in range(x0 + 4, x1 - 3, 10):
				draw_rect(Rect2(x, top + 3, 1, 2), _acc)
				draw_rect(Rect2(x + 1, top + 5, 2, 1), _acc)
			for x: int in range(x0 + 1, x1 - 1, 5):
				draw_rect(Rect2(x, top - 1, 1, 1), _ink)
		"voice":
			for x: int in range(x0 + 3, x1 - 2, 8):
				draw_rect(Rect2(x, top - 3 - (x / 8) % 3, 1, 1), _acc)
			draw_rect(Rect2(rr.position + Vector2(0, 2), Vector2(rr.size.x, 1)), _acc)
		_:
			for x: int in range(x0 + 3, x1 - 2, 7):
				draw_rect(Rect2(x, top - 1, 1, 1), _ink)
				draw_rect(Rect2(x + 2, top - 1, 1, 1), _ink)
				if era >= 3:
					draw_rect(Rect2(x + 1, top - 2, 1, 1), _mid)
