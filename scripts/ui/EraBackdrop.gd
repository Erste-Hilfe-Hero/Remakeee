class_name EraBackdrop
extends RefCounted
## Painter of the era scenes behind the title, the finale card, the change scene and the save
## card (docs/ERA_LOOK_TITLE.md): the lighthouse lake, redrawn the way each handheld step could
## draw it. I: four inks, nothing moves. II: flat limited colour, clouds and hills scroll in
## whole pixels. III: banded gradients, shaded hills, a flying silhouette. IV: four parallax
## layers under a low sun, a lake drawn in perspective. V: aurora, waves, motes, a camera that
## drifts, and the era's legend as a huge shape in the sky. Colours: data/era_moments.json.
## Everything is drawn with primitives into the caller's canvas item; no image files.

## Height the scenes were laid out for; every size scales with rect height / BASE_H.
const BASE_H: float = 148.0
const HORIZON: float = 0.62
const FRAME_BORDER: int = 2

static var _legend_tex: Dictionary[String, Texture2D] = {}

## Paints the scene of era [param e] at second [param t] into [param r] of [param ci].
## [param still]: nothing moves (reduced motion, thumbnails).
static func paint(ci: CanvasItem, r: Rect2, e: int, t: float, still: bool = false) -> void:
	e = clampi(e, 1, 5)
	var cfg: Dictionary = EraMoments.title(e)
	if still:
		t = 0.0
	var u: float = r.size.y / BASE_H
	var lake_y: float = floorf(r.position.y + r.size.y * HORIZON)
	if bool(cfg.get("camera", false)) and not still:
		# Era V: the whole view drifts and leans in a little.
		var zoom: float = 1.05 + 0.04 * sin(t * 0.23)
		var c: Vector2 = r.get_center() + Vector2(sin(t * 0.17) * 6.0 * u, cos(t * 0.13) * 3.0 * u)
		ci.draw_set_transform(c - c * zoom + Vector2(sin(t * 0.11) * 4.0 * u, 0), 0.0, Vector2(zoom, zoom))
	_sky(ci, r, e, lake_y, t, u)
	_hills(ci, r, e, lake_y, t, u, cfg)
	_lake(ci, r, e, lake_y, t, u)
	_lighthouse(ci, r, e, lake_y, t, u)
	if bool(cfg.get("flyer", false)):
		_flyers(ci, r, e, t, u)
	_shore(ci, r, e, t, u)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _bands(e: int) -> int:
	return [1, 1, 2, 8, 16, 32][e]

static func _sky(ci: CanvasItem, r: Rect2, e: int, lake_y: float, t: float, u: float) -> void:
	var top: Color = EraMoments.col(e, "sky_top")
	var low: Color = EraMoments.col(e, "sky_low")
	var sky_h: float = lake_y - r.position.y
	var n: int = _bands(e)
	for i: int in n:
		var y0: float = r.position.y + floorf(sky_h * i / n)
		var y1: float = r.position.y + floorf(sky_h * (i + 1) / n)
		var k: float = float(i) / maxf(n - 1, 1)
		ci.draw_rect(Rect2(r.position.x, y0, r.size.x, y1 - y0), top.lerp(low, k * k if e >= 3 else k))
	if e <= 2:
		# One dithered seam instead of a gradient: the limited-colour way to blend.
		var seam: float = r.position.y + floorf(sky_h * (0.5 if e == 2 else 0.86))
		var c: Color = low if e == 2 else EraMoments.col(e, "far")
		for y: int in range(int(seam) - 6, int(seam)):
			for x: int in range(int(r.position.x) + (y % 2), int(r.end.x), 2):
				if y > seam - 6 + (x % 3):
					ci.draw_rect(Rect2(x, y, 1, 1), c)
		if e == 1:
			ci.draw_rect(Rect2(r.position.x, seam, r.size.x, lake_y - seam), c)
	var sun: Color = EraMoments.col(e, "sun")
	var sun_at := Vector2(r.position.x + r.size.x * (0.82 if e != 4 else 0.62), r.position.y + sky_h * [0.0, 0.36, 0.98, 0.52, 0.86, 0.42][e])
	var rad: float = [0.0, 6.0, 15.0, 9.0, 22.0, 8.0][e] * u
	if e == 1 or e == 5:
		# Night eras: stars, and a moon with a bite taken out.
		for i: int in (22 if e == 1 else 40):
			var sx: float = r.position.x + fmod(i * 53.0 + 11.0, r.size.x)
			var sy: float = r.position.y + fmod(i * 31.0 + 5.0, sky_h * 0.8)
			var a: float = 1.0 if e == 1 else 0.55 + 0.45 * sin(t * (1.0 + i % 4) + i)
			ci.draw_rect(Rect2(roundf(sx), roundf(sy), 1, 1), Color(sun, a))
		if e == 5:
			_aurora(ci, r, lake_y, t, u)
		ci.draw_circle(sun_at, rad, sun)
		ci.draw_circle(sun_at + Vector2(rad * 0.5, -rad * 0.3), rad * 0.85, top)
	else:
		for ring: int in (0 if e == 2 else (2 if e == 3 else 4)):
			ci.draw_circle(sun_at, rad + (ring + 1) * 3.0 * u, Color(sun, 0.16))
		ci.draw_circle(sun_at, rad, sun)
	_clouds(ci, r, e, lake_y, t, u)

static func _aurora(ci: CanvasItem, r: Rect2, lake_y: float, t: float, u: float) -> void:
	var glow: Color = EraMoments.col(5, "accent")
	for band: int in 3:
		var pts := PackedVector2Array()
		var low := PackedVector2Array()
		var base: float = r.position.y + (18.0 + band * 15.0) * u
		for i: int in 13:
			var x: float = r.position.x + r.size.x * i / 12.0
			var y: float = base + sin(i * 0.9 + t * (0.5 + band * 0.2) + band * 2.0) * 7.0 * u
			pts.append(Vector2(x, y))
			low.append(Vector2(x, y + (16.0 + 5.0 * sin(i * 1.7 + t * 0.8)) * u))
		low.reverse()
		pts.append_array(low)
		ci.draw_colored_polygon(pts, Color(glow, 0.10 + 0.05 * band))

static func _clouds(ci: CanvasItem, r: Rect2, e: int, lake_y: float, t: float, u: float) -> void:
	if e == 1:
		return
	var speed: float = float(EraMoments.title(e).get("scroll", 0.0))
	var c: Color = EraMoments.col(e, "cloud")
	var span: float = r.size.x + 60.0 * u
	for i: int in (3 if e <= 3 else 5):
		var depth: float = 1.0 if e <= 3 else 0.5 + 0.25 * (i % 3)
		var x: float = fmod(i * 67.0 * u + t * speed * depth, span) - 40.0 * u
		var y: float = r.position.y + (20.0 + (i * 23) % 44) * u
		if e == 2:
			x = floorf(x)
		var w: float = (26.0 + (i % 2) * 10.0) * u * depth
		var at := Vector2(r.position.x + x, y)
		if e == 2:
			# Flat two-row clouds made of rectangles.
			ci.draw_rect(Rect2(at, Vector2(w, 4.0 * u)).abs(), c)
			ci.draw_rect(Rect2(at + Vector2(4.0 * u, -3.0 * u), Vector2(w * 0.55, 3.0 * u)).abs(), c)
		else:
			var a: float = 1.0 if e == 3 else 0.7
			for k: int in 4:
				ci.draw_circle(at + Vector2(w * (0.15 + 0.23 * k), -absf(sin(k * 1.9 + i)) * 3.0 * u), w * 0.2, Color(c, a))
			ci.draw_rect(Rect2(at + Vector2(w * 0.05, 0), Vector2(w * 0.9, w * 0.16)), Color(c, a))
			# A shaded underside from Era III on.
			ci.draw_rect(Rect2(at + Vector2(w * 0.1, w * 0.16), Vector2(w * 0.8, maxf(u, 1.0))), Color(EraMoments.col(e, "far"), 0.5))

## Ridge line of hill layer [param layer] at screen x, in px above the lake line.
static func ridge(x: float, layer: int, u: float) -> float:
	var f: float = 0.045 / (1.0 + layer * 0.35)
	return (5.0 + layer * 5.0 + 5.0 * sin(x * f / u + layer * 1.7) + 3.0 * sin(x * f * 2.3 / u + layer * 0.6)) * u

## Ridge height at [param x], at least 1 px, in 2 px steps in the limited-colour eras.
static func _ridge_h(x: float, layer: int, u: float, e: int) -> float:
	var h: float = ridge(x, layer, u)
	if e <= 2:
		h = floorf(h / maxf(2.0 * u, 1.0)) * maxf(2.0 * u, 1.0)
	return maxf(h, 1.0)

static func _hills(ci: CanvasItem, r: Rect2, e: int, lake_y: float, t: float, u: float, cfg: Dictionary) -> void:
	var layers: int = maxi(int(cfg.get("layers", 1)), 1)
	var speed: float = float(cfg.get("scroll", 0.0))
	var far: Color = EraMoments.col(e, "far")
	var mid: Color = EraMoments.col(e, "mid")
	var legend: String = str(cfg.get("legend", ""))
	for li: int in layers:
		# Farthest layer first; near layers are lower, darker in tone and move faster.
		var layer: int = layers - 1 - li
		var depth: float = 1.0 / (1.0 + layer)
		var shift: float = t * speed * depth * (0.5 if e == 2 else 1.0)
		if e >= 4:
			shift += sin(t * 0.25) * 14.0 * u * depth
		if e == 2:
			shift = floorf(shift)
		var col: Color = mid.lerp(far, float(layer) / maxf(layers - 1, 1)) if layers > 1 else far
		# The ridge as a row of narrow quads (one big polygon fails to triangulate on flat spots).
		var quads: Array[PackedVector2Array] = []
		var step: float = maxf(4.0 * u, 2.0)
		var x: float = 0.0
		var last := Vector2(r.position.x, lake_y - _ridge_h(shift, layer, u, e))
		while x < r.size.x:
			x = minf(x + step, r.size.x)
			var next := Vector2(r.position.x + x, lake_y - _ridge_h(x + shift, layer, u, e))
			quads.append(PackedVector2Array([Vector2(last.x, lake_y), last, next, Vector2(next.x, lake_y)]))
			last = next
		# The legend stands behind the nearest ridge, in front of the far ones.
		if not legend.is_empty() and layer == 0:
			_legend(ci, r, legend, lake_y, t, u)
		for q: PackedVector2Array in quads:
			ci.draw_colored_polygon(q, col)
		if e >= 3:
			# Etched shading: short strokes on the shadow side of each ridge.
			var dark: Color = Color(EraMoments.col(e, "ink"), 0.22)
			var sx: float = fmod(-shift, 6.0 * u)
			while sx < r.size.x:
				var h2: float = ridge(sx + shift, layer, u)
				if h2 > 3.0 * u:
					ci.draw_line(Vector2(r.position.x + sx, lake_y - h2 + 2.0 * u), Vector2(r.position.x + sx - 2.0 * u, lake_y - h2 * 0.45), dark, 1.0)
				sx += 6.0 * u

static func _legend(ci: CanvasItem, r: Rect2, species: String, lake_y: float, t: float, u: float) -> void:
	if not _legend_tex.has(species):
		var p: String = EraManager.art_path_from("spirlings/%s_front.png" % species, EraManager.NEWEST)
		_legend_tex[species] = load(p) if not p.is_empty() else null
	var tex: Texture2D = _legend_tex[species]
	if tex == null:
		return
	# Breathing: the shape swells and sinks a little, feet planted behind the ridge.
	var breath: float = 1.0 + 0.025 * sin(t * 1.3)
	var size := Vector2(66.0 * u, 66.0 * u * breath)
	var at := Vector2(r.position.x + r.size.x * 0.66 - size.x * 0.5, lake_y - size.y + 9.0 * u)
	var rim: Color = EraMoments.col(5, "accent")
	for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(0, -2)]:
		ci.draw_texture_rect(tex, Rect2(at + o * u, size), false, Color(rim.r * 4.0, rim.g * 4.0, rim.b * 4.0, 0.5 + 0.2 * sin(t * 1.3)))
	var shade: Color = EraMoments.col(5, "far").darkened(0.45)
	ci.draw_texture_rect(tex, Rect2(at, size), false, Color(shade.r, shade.g, shade.b, 1.0))

static func _lake(ci: CanvasItem, r: Rect2, e: int, lake_y: float, t: float, u: float) -> void:
	var water: Color = EraMoments.col(e, "water")
	var glint: Color = EraMoments.col(e, "glint")
	var h: float = r.end.y - lake_y
	var n: int = 1 if e <= 2 else (3 if e == 3 else 6)
	for i: int in n:
		var y0: float = lake_y + floorf(h * i / n)
		ci.draw_rect(Rect2(r.position.x, y0, r.size.x, lake_y + floorf(h * (i + 1) / n) - y0), water.lerp(EraMoments.col(e, "ink"), 0.35 * i / maxf(n, 1)))
	if e >= 3:
		# The sun or moon lies on the water as a broken column of light.
		var sx: float = r.position.x + r.size.x * (0.82 if e != 4 else 0.62)
		for i: int in int(h / (3.0 * u)):
			var w: float = (10.0 + i * (1.5 if e >= 4 else 0.6) + 3.0 * sin(t * 2.0 + i)) * u
			ci.draw_rect(Rect2(sx - w * 0.5, lake_y + i * 3.0 * u + u, w, maxf(u, 1.0)), Color(EraMoments.col(e, "sun"), 0.55 - 0.03 * i))
	var rows: int = 5 if e <= 3 else 8
	for i: int in rows * 2:
		var row: int = i % rows
		# Perspective from Era IV: rows spread apart and glints grow toward the viewer.
		var k: float = float(row) / rows
		var gy: float = lake_y + (4.0 + row * 6.0) * u if e <= 3 else lake_y + (2.0 + k * k * (h / u - 4.0)) * u
		var len: float = (6.0 + i % 3 * 2.0) * u * (1.0 if e <= 3 else 0.6 + k * 1.6)
		var gx: float = fmod(i * 41.0 * u + t * (4.0 + i % 3) * u * (1.0 if e <= 3 else 0.5 + k), r.size.x + 20.0 * u) - 10.0 * u
		if e <= 2:
			gx = roundf(gx)
		elif e == 5:
			gy += sin(t * 1.6 + i) * 1.5 * u
		if e == 1 and i >= rows:
			continue
		ci.draw_rect(Rect2(r.position.x + gx, floorf(gy), len, maxf(floorf(u), 1.0)), Color(glint, 1.0 if e <= 2 else 0.8))
	if e == 5:
		# Living water: slow wave lines.
		for i: int in 5:
			var pts := PackedVector2Array()
			var wy: float = lake_y + (6.0 + i * 9.0) * u
			for x: int in range(0, int(r.size.x) + 9, 8):
				pts.append(Vector2(r.position.x + x, wy + sin(x * 0.06 / u + t * 1.4 + i * 1.3) * (1.0 + i * 0.4) * u))
			ci.draw_polyline(pts, Color(glint, 0.25), 1.0)

static func _lighthouse(ci: CanvasItem, r: Rect2, e: int, lake_y: float, t: float, u: float) -> void:
	var ink: Color = EraMoments.col(e, "ink")
	var paper: Color = EraMoments.col(e, "paper")
	var accent: Color = EraMoments.col(e, "accent")
	var bx: float = r.position.x + 20.0 * u
	var top: float = lake_y - 44.0 * u
	# Rock.
	ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 18.0 * u, lake_y + 6.0 * u), Vector2(bx - 10.0 * u, lake_y - 5.0 * u),
		Vector2(bx + 11.0 * u, lake_y - 7.0 * u), Vector2(bx + 20.0 * u, lake_y + 6.0 * u)]), ink)
	if e >= 3:
		ci.draw_line(Vector2(bx - 9.0 * u, lake_y - 4.0 * u), Vector2(bx + 10.0 * u, lake_y - 6.0 * u), Color(paper, 0.35), 1.0)
	# Tower: a tapering shaft with bands, the lamp room and a cap.
	var shaft := PackedVector2Array([Vector2(bx - 6.0 * u, lake_y - 5.0 * u), Vector2(bx - 4.0 * u, top + 9.0 * u),
		Vector2(bx + 4.0 * u, top + 9.0 * u), Vector2(bx + 6.0 * u, lake_y - 5.0 * u)])
	ci.draw_colored_polygon(shaft, paper if e >= 2 else EraMoments.col(e, "accent"))
	for b: int in 2:
		var y: float = top + (15.0 + b * 13.0) * u
		var half: float = (4.4 + b * 0.8) * u
		ci.draw_rect(Rect2(bx - half, y, half * 2.0, 5.0 * u), accent if e >= 2 else ink)
	if e >= 3:
		# Shade on the lee side of the shaft.
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx + 1.5 * u, top + 9.0 * u), Vector2(bx + 4.0 * u, top + 9.0 * u),
			Vector2(bx + 6.0 * u, lake_y - 5.0 * u), Vector2(bx + 2.5 * u, lake_y - 5.0 * u)]), Color(ink, 0.28))
	var closed := shaft.duplicate()
	closed.append(shaft[0])
	ci.draw_polyline(closed, ink, 1.0)
	ci.draw_rect(Rect2(bx - 5.0 * u, top + 3.0 * u, 10.0 * u, 6.0 * u), ink)
	ci.draw_rect(Rect2(bx - 3.0 * u, top + 4.0 * u, 6.0 * u, 4.0 * u), EraMoments.col(e, "sun"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 6.0 * u, top + 3.0 * u), Vector2(bx, top - 3.0 * u), Vector2(bx + 6.0 * u, top + 3.0 * u)]), ink)
	# The beam: two fixed positions in the limited-colour eras, a smooth sweep later.
	var lamp := Vector2(bx, top + 6.0 * u)
	var a: float = sin(t * 0.6) * 0.5 + 0.1
	if e <= 2:
		a = 0.1 if int(t / 0.8) % 2 == 0 else -0.25
	var len: float = r.size.x * 1.2
	var spread: float = 0.08
	ci.draw_colored_polygon(PackedVector2Array([lamp, lamp + Vector2(cos(a - spread), sin(a - spread)) * len, lamp + Vector2(cos(a + spread), sin(a + spread)) * len]),
		Color(EraMoments.col(e, "sun"), 0.3))
	if e >= 4:
		ci.draw_colored_polygon(PackedVector2Array([lamp, lamp + Vector2(cos(a - spread * 0.4), sin(a - spread * 0.4)) * len, lamp + Vector2(cos(a + spread * 0.4), sin(a + spread * 0.4)) * len]),
			Color(EraMoments.col(e, "sun"), 0.25))

## A long-tailed marsh bird of our own, as a silhouette: body, tail and two wings that beat.
static func flyer_points(at: Vector2, s: float, flap: float) -> Array[PackedVector2Array]:
	var body := PackedVector2Array([at + Vector2(-7, 0) * s, at + Vector2(-2, -1.5) * s, at + Vector2(4, -0.5) * s,
		at + Vector2(11, 1.5) * s, at + Vector2(4, 1.2) * s, at + Vector2(-2, 1.5) * s])
	var tip: float = -6.0 * flap
	var wing_a := PackedVector2Array([at + Vector2(-2, -0.5) * s, at + Vector2(1.5, tip - 1.0) * s, at + Vector2(3, 0) * s])
	var wing_b := PackedVector2Array([at + Vector2(-0.5, 0) * s, at + Vector2(4.5, tip * 0.7) * s, at + Vector2(4, 0.5) * s])
	return [body, wing_a, wing_b]

static func _flyers(ci: CanvasItem, r: Rect2, e: int, t: float, u: float) -> void:
	var ink: Color = EraMoments.col(e, "ink")
	var count: int = 1 if e == 3 else 3
	var period: float = 11.0
	var k: float = fmod(t + 3.0, period) / period
	for i: int in count:
		var x: float = r.end.x + 20.0 * u - k * (r.size.x + 60.0 * u) + i * 13.0 * u
		var y: float = r.position.y + (40.0 + i * 7.0) * u + sin(k * TAU * 2.0 + i) * 4.0 * u
		var s: float = u * (1.0 if e == 3 else 1.3 - i * 0.25)
		for poly: PackedVector2Array in flyer_points(Vector2(x, y), s, sin(t * 7.0 + i * 1.3)):
			ci.draw_colored_polygon(poly, ink)

static func _shore(ci: CanvasItem, r: Rect2, e: int, t: float, u: float) -> void:
	var shore_y: float = r.end.y - 6.0 * u
	var shore: Color = EraMoments.col(e, "shore")
	var ink: Color = EraMoments.col(e, "ink")
	ci.draw_rect(Rect2(r.position.x, shore_y - 2.0 * u, r.size.x, r.end.y - shore_y + 2.0 * u), shore)
	ci.draw_rect(Rect2(r.position.x, shore_y - 2.0 * u, r.size.x, maxf(floorf(u), 1.0)), ink)
	if e < 3:
		return
	# Grass tufts on the near shore; they sway from Era IV on.
	var mid: Color = EraMoments.col(e, "mid")
	var x: float = 3.0 * u
	var i: int = 0
	while x < r.size.x:
		var sway: float = sin(t * 1.8 + i) * 1.5 * u if e >= 4 else 0.0
		var base := Vector2(r.position.x + x, shore_y - 2.0 * u)
		var hgt: float = (3.0 + (i * 7) % 4) * u * (1.4 if e >= 4 else 1.0)
		ci.draw_line(base, base + Vector2(sway - u, -hgt), mid, maxf(floorf(u), 1.0))
		ci.draw_line(base + Vector2(u, 0), base + Vector2(sway + 2.0 * u, -hgt * 0.8), mid.darkened(0.2), maxf(floorf(u), 1.0))
		x += (5.0 + (i * 5) % 6) * u
		i += 1

## Rising motes of light (Era V), drawn above the cast by the title art.
static func motes(ci: CanvasItem, r: Rect2, t: float) -> void:
	var u: float = r.size.y / BASE_H
	var c: Color = EraMoments.col(5, "accent")
	for i: int in 16:
		var life: float = fmod(t * (0.12 + (i % 5) * 0.03) + i * 0.37, 1.0)
		var x: float = r.position.x + fmod(i * 61.0 * u + sin(t * 0.7 + i) * 6.0 * u, r.size.x)
		var y: float = r.end.y - life * r.size.y * 0.7
		ci.draw_rect(Rect2(roundf(x), roundf(y), maxf(u, 1.0), maxf(u, 1.0)), Color(c, sin(life * PI) * 0.9))

## Draws the menu frame of era [param e] (data "frame") around [param r]: I a notched double
## ink rule, II a rounded colour-wash line, III a bevelled plate with a dotted gold rule, IV a
## rounded panel with a drop shadow, V a glossy rounded panel. [param reveal] 0..1 draws only
## the left share of it (the change scene redraws the frame from left to right).
static func draw_frame(ci: CanvasItem, r: Rect2, e: int, reveal: float = 1.0) -> void:
	e = clampi(e, 1, 5)
	if reveal <= 0.0:
		return
	var ink: Color = EraMoments.col(e, "ink")
	var paper: Color = EraMoments.col(e, "paper")
	var accent: Color = EraMoments.col(e, "accent")
	var part := Rect2(r.position, Vector2(r.size.x * clampf(reveal, 0.0, 1.0), r.size.y))
	var whole: bool = reveal >= 1.0
	match EraMoments.frame(e):
		"ink":
			ci.draw_rect(part, paper)
			ci.draw_rect(part, ink, false, 1.0)
			if whole:
				ci.draw_rect(r.grow(-2.0), ink, false, 1.0)
				for c: Vector2 in [r.position, Vector2(r.end.x - 3, r.position.y), Vector2(r.position.x, r.end.y - 3), r.end - Vector2(3, 3)]:
					ci.draw_rect(Rect2(c, Vector2(3, 3)), ink)
		"wash":
			var sb := StyleBoxFlat.new()
			sb.bg_color = paper
			sb.border_color = EraMoments.col(e, "sky_top")
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(2)
			sb.anti_aliasing = false
			ci.draw_style_box(sb, part)
			ci.draw_rect(Rect2(part.position + Vector2(2, part.size.y - 3), Vector2(maxf(part.size.x - 4, 0), 1)), accent)
		"bevel":
			ci.draw_rect(part, paper)
			ci.draw_rect(part, ink, false, 1.0)
			ci.draw_rect(Rect2(part.position + Vector2(1, 1), Vector2(maxf(part.size.x - 2, 0), 1)), Color.WHITE)
			ci.draw_rect(Rect2(part.position + Vector2(1, part.size.y - 2), Vector2(maxf(part.size.x - 2, 0), 1)), EraMoments.col(e, "shore"))
			var x: float = part.position.x + 4
			while x < part.end.x - 3:
				ci.draw_rect(Rect2(x, part.position.y + 3, 1, 1), accent)
				ci.draw_rect(Rect2(x, part.end.y - 4, 1, 1), accent)
				x += 3
		"round", "gloss":
			var gloss: bool = EraMoments.frame(e) == "gloss"
			var sb := StyleBoxFlat.new()
			sb.bg_color = paper
			sb.border_color = ink if not gloss else accent
			sb.set_border_width_all(FRAME_BORDER)
			sb.set_corner_radius_all(6 if not gloss else 9)
			sb.shadow_color = Color(ink, 0.45)
			sb.shadow_size = 3
			sb.shadow_offset = Vector2(0, 2)
			ci.draw_style_box(sb, part)
			if gloss and part.size.x > 20:
				ci.draw_rect(Rect2(part.position + Vector2(8, 3), Vector2(part.size.x - 16, maxf(part.size.y * 0.28, 2))), Color(1, 1, 1, 0.35))
