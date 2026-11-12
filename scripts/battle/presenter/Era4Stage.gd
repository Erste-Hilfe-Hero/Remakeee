class_name Era4Stage
extends Control
## Era IV (Panorama) battle stage, design plan 331-333: a 2.5D floor in slanted perspective
## that shrinks toward a vanishing point, flat-topped slabs with a side face and a cast shadow
## for each side (no oval platforms, LEGAL.md layout rule) and 3 parallax layers that drift.
## Values come from data/era4_stage.json via EraManager.stage_config().

var cfg: Dictionary = {}
var _time: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cfg = EraManager.stage_config().duplicate()
	cfg["colors"] = EraManager.stage_colors(EraManager.current_region)

## Tints the stage for the place the battle started (lake, ridge, ember, voice).
func set_terrain(terrain: String) -> void:
	cfg["colors"] = EraManager.stage_colors(EraManager.current_region, terrain)
	queue_redraw()

func _process(delta: float) -> void:
	if Juice.reduced():
		return
	_time += delta
	queue_redraw()

## Screen y of floor depth [param d] (0 horizon .. 1 bottom) in a field of height [param h].
static func depth_y(c: Dictionary, d: float, h: float) -> float:
	var hy: float = h * float(c.get("horizon", 0.34))
	return hy + (h - hy) * clampf(d, 0.0, 1.0)

## Sprite scale at depth [param d]: far things are smaller.
static func depth_scale(c: Dictionary, d: float) -> float:
	return lerpf(float(c.get("far_scale", 0.62)), float(c.get("near_scale", 1.0)), clampf(d, 0.0, 1.0))

## Floor point for screen fraction [param fx] at depth [param d]; x converges on the vanishing point.
static func project(c: Dictionary, fx: float, d: float, sz: Vector2) -> Vector2:
	var vx: float = sz.x * float(c.get("vanish_x", 0.5))
	var x: float = vx + (fx * sz.x - vx) * lerpf(0.0, 1.0, clampf(d, 0.0, 1.0))
	return Vector2(x, depth_y(c, d, sz.y))

## Top face of a slab as 4 corners (far left, far right, near right, near left).
static func slab_quad(c: Dictionary, side: String, sz: Vector2) -> PackedVector2Array:
	var s: Dictionary = c["slabs"][side]
	var d: float = float(s["depth"])
	var l: float = float(s["length"]) / 2.0
	var hw: float = float(s["width"]) / 2.0
	var x: float = float(s["x"])
	var far_w: float = hw * depth_scale(c, d - l) * sz.x
	var near_w: float = hw * depth_scale(c, d + l) * sz.x
	var fy: float = depth_y(c, d - l, sz.y)
	var ny: float = depth_y(c, d + l, sz.y)
	var cx: float = x * sz.x
	return PackedVector2Array([Vector2(cx - far_w, fy), Vector2(cx + far_w, fy), Vector2(cx + near_w, ny), Vector2(cx - near_w, ny)])

## Where a Spirling of base size [param base] stands on [param side]'s slab: its rect.
static func sprite_rect(c: Dictionary, side: String, sz: Vector2, base: float) -> Rect2:
	var q: PackedVector2Array = slab_quad(c, side, sz)
	var foot: Vector2 = Vector2((q[0].x + q[1].x) / 2.0, lerpf(q[0].y, q[3].y, 0.6))
	var s: float = roundf(base * depth_scale(c, float(c["slabs"][side]["depth"])))
	return Rect2(Vector2(roundf(foot.x - s / 2.0), roundf(foot.y - s)), Vector2(s, s))

func _col(key: String) -> Color:
	return Color(String(cfg["colors"][key]))

func _draw() -> void:
	if cfg.is_empty():
		return
	var w: float = size.x
	var h: float = size.y
	var hy: float = depth_y(cfg, 0.0, h)
	for y: int in int(hy):
		draw_rect(Rect2(0, y, w, 1), _col("sky_top").lerp(_col("sky_low"), y / maxf(hy, 1.0)))
	_draw_layers(w, hy)
	_draw_floor(Vector2(w, h), hy)
	for side: String in ["foe", "player"]:
		_draw_slab(side, Vector2(w, h))

func _draw_layers(w: float, hy: float) -> void:
	var layers: Array = cfg.get("layers", [])
	for i: int in layers.size():
		var L: Dictionary = layers[i]
		var top: float = hy - float(L["height"]) * size.y
		var shift: float = fposmod(_time * float(L["drift"]), w)
		var pts := PackedVector2Array([Vector2(0, hy)])
		var step: float = 6.0
		var x: float = 0.0
		while x <= w + step:
			var t: float = (x + shift) / w * TAU * (2 + i)
			pts.append(Vector2(x, top + float(L["amp"]) * (1.0 + sin(t) * 0.5 + sin(t * 2.3 + i) * 0.5)))
			x += step
		pts.append(Vector2(w + step, hy))
		draw_colored_polygon(pts, _col(String(L["name"])))

func _draw_floor(sz: Vector2, hy: float) -> void:
	var rows: int = int(cfg.get("floor_rows", 6))
	for y: int in int(sz.y - hy):
		var d: float = y / maxf(sz.y - hy, 1.0)
		draw_rect(Rect2(0, hy + y, sz.x, 1), _col("floor_far").lerp(_col("floor_near"), d))
	var grid: Color = _col("grid")
	grid.a = 0.5
	var n: int = int(cfg.get("floor_lines", 9))
	for i: int in n:
		var fx: float = -0.5 + 2.0 * i / float(n - 1)
		draw_line(project(cfg, fx, 0.0, sz), project(cfg, fx, 1.0, sz), grid, 1.0)
	for r: int in range(1, rows + 1):
		var d: float = pow(r / float(rows), 1.6)
		var y: float = roundf(depth_y(cfg, d, sz.y))
		draw_line(Vector2(0, y), Vector2(sz.x, y), grid, 1.0)

func _draw_slab(side: String, sz: Vector2) -> void:
	var q: PackedVector2Array = slab_quad(cfg, side, sz)
	var t: float = float(cfg.get("slab_thickness", 6))
	var sh: Color = _col("shadow")
	sh.a = float(cfg.get("shadow_alpha", 0.35))
	var off := Vector2(t, t * 0.6)
	draw_colored_polygon(PackedVector2Array([q[0] + off, q[1] + off, q[2] + off + Vector2(0, t), q[3] + off + Vector2(0, t)]), sh)
	draw_colored_polygon(PackedVector2Array([q[3], q[2], q[2] + Vector2(0, t), q[3] + Vector2(0, t)]), _col("slab_side"))
	draw_colored_polygon(q, _col("slab_top"))
	draw_polyline(PackedVector2Array([q[0], q[1], q[2], q[3], q[0]]), _col("slab_side"), 1.0)
