class_name Era4Stage
extends Control
## Era IV (Panorama) and Era V (Living) battle stage, design plan 331-333 and
## docs/ERA_FEEL_BATTLE.md slice 5: a painted scene per place (meadow, cave, water, town, snow,
## ember, voice) in layers of depth (sky, distant range, far range, a mid row of trees, roofs or
## rocks, a textured floor) and a flat-topped turf slab with a side wall and a soft shadow for each
## side (no oval platforms, LEGAL.md layout rule). Era V adds golden-hour light above the sprites,
## a low sun with rays, rim light on the slabs, and drifting clouds, swaying grass and shimmering
## water (still under reduced motion).
## Geometry comes from data/era4_stage.json via EraManager.stage_config(), the look from
## data/era45_stage.json via Era45Look.

var cfg: Dictionary = {}
var era: int = 4
var scene_name: String = "meadow"
var pal: Dictionary = {}
var look: Dictionary = {}
var _time: float = 0.0
var _anim: Layer
var _knolls: Layer
var _light: Layer

## One drawing layer of the stage; the stage draws into it.
class Layer extends Control:
	var stage: Era4Stage
	var kind: String
	func _init(p_stage: Era4Stage, p_kind: String) -> void:
		stage = p_stage
		kind = p_kind
		name = "stage_" + p_kind
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		stage.draw_layer(self, kind)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cfg = EraManager.stage_config().duplicate(true)
	cfg["colors"] = EraManager.stage_colors(EraManager.current_region)
	era = EraManager.active_era()
	look = Era45Look.era_look(era)
	var own: Dictionary = look.get("slabs", {})
	var slabs: Dictionary = cfg.get("slabs", {})
	for side: String in slabs:
		(slabs[side] as Dictionary).merge(own.get(side, {}), true)
	_use_scene(Era45Look.scene_for("field", Era45Look.current_biome()))
	_anim = Layer.new(self, "anim")
	_knolls = Layer.new(self, "knolls")
	for l: Layer in [_anim, _knolls]:
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(l)
	if float(look.get("vignette", 0.0)) > 0.0 or bool(look.get("sun", false)):
		_light = Layer.new(self, "light")
		_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The light belongs to whoever added it; one that never got a parent goes with the stage.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _light != null and is_instance_valid(_light) and _light.get_parent() == null:
		_light.free()

func _use_scene(n: String) -> void:
	scene_name = n
	pal = Era45Look.palette(n, era)
	_redraw_all()

func _redraw_all() -> void:
	queue_redraw()
	for l: Layer in [_anim, _knolls, _light]:
		if l != null and is_instance_valid(l):
			l.queue_redraw()

## The light overlay (Era V), or null. It lies over the sprites and art effects, so the battle
## scene adds it to the field after them.
func light_layer() -> Control:
	return _light

## Formation battles: each slab spreads under the whole rank of [param foe] / [param player]
## (field rects), so four or three Spirlings all stand on the turf.
func fit_formation(foe: Rect2, player: Rect2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var slabs: Dictionary = (cfg.get("slabs", {}) as Dictionary).duplicate(true)
	var hy: float = depth_y(cfg, 0.0, size.y)
	for pair: Array in [["foe", foe], ["player", player]]:
		var r: Rect2 = pair[1]
		if r.size.x <= 0.0:
			continue
		var s: Dictionary = slabs.get(pair[0], {})
		var d: float = clampf((r.end.y - hy) / maxf(size.y - hy, 1.0), 0.05, 0.95)
		s["depth"] = d
		s["x"] = r.get_center().x / size.x
		s["width"] = (r.size.x + 16.0) / size.x / depth_scale(cfg, d)
		slabs[pair[0]] = s
	cfg["slabs"] = slabs
	_redraw_all()

## Picks the scene for the place the battle started (lake, ridge, ember, voice) in the current
## map's biome (cave, town ...), and tints the old stage colours to match.
func set_terrain(terrain: String) -> void:
	cfg["colors"] = EraManager.stage_colors(EraManager.current_region, terrain)
	_use_scene(Era45Look.scene_for(terrain, Era45Look.current_biome()))

func _process(delta: float) -> void:
	if not Era45Look.animates(era, Juice.reduced()):
		return
	_time += delta
	_anim.queue_redraw()
	if _light != null and is_instance_valid(_light):
		_light.queue_redraw()

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

## Single battles in Era IV/V: the rect of a Spirling whose art is [param art_px] wide, drawn at
## a whole multiple of its art (Era45Look.sprite_px), feet on [param side]'s slab.
func fit_sprite(side: String, sz: Vector2, art_px: float) -> Rect2:
	var q: PackedVector2Array = slab_quad(cfg, side, sz)
	var foot: Vector2 = Vector2((q[0].x + q[1].x) / 2.0, lerpf(q[0].y, q[3].y, 0.6))
	var s: float = Era45Look.sprite_px(era, side, art_px)
	return Rect2(Vector2(roundf(foot.x - s / 2.0), roundf(foot.y - s)), Vector2(s, s))

# --- Drawing ---------------------------------------------------------------------------

func _c(key: String) -> Color:
	return pal.get(key, Color.MAGENTA)

## +1 when the light comes from the left (Era IV), -1 from the low sun on the right (Era V).
func _light_dir() -> float:
	var sh: Array = look.get("shadow", [5, 3])
	return 1.0 if float(sh[0]) >= 0.0 else -1.0

func _outdoor() -> bool:
	return bool(Era45Look.scene(scene_name).get("outdoor", true))

func _kind(key: String) -> String:
	return str(Era45Look.scene(scene_name).get(key, ""))

func _sun_pos(w: float, hy: float) -> Vector2:
	return Vector2(roundf(w * 0.8), roundf(hy * 0.7))

func _draw() -> void:
	if cfg.is_empty() or pal.is_empty():
		return
	var w: float = size.x
	var h: float = size.y
	var hy: float = roundf(depth_y(cfg, 0.0, h))
	_draw_sky(self, w, hy)
	_draw_far(self, w, h, hy)
	_draw_mid(self, w, h, hy)
	_draw_ground(self, w, h, hy)

func draw_layer(ci: CanvasItem, kind: String) -> void:
	if cfg.is_empty() or pal.is_empty() or size.x <= 0.0:
		return
	var hy: float = roundf(depth_y(cfg, 0.0, size.y))
	match kind:
		"anim":
			_draw_clouds(ci, size.x, hy)
			_draw_tufts(ci, size.x, size.y, hy)
		"knolls":
			for side: String in ["foe", "player"]:
				_draw_knoll(ci, side, size)
		"light":
			_draw_light(ci, size.x, size.y, hy)

## A filled pixel disc (sun, puffs, crowns) of radius [param r] at [param c].
static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var ri: int = maxi(int(r), 1)
	for dy: int in range(-ri, ri + 1):
		var half: float = floorf(sqrt(maxf(r * r - dy * dy, 0.0)))
		ci.draw_rect(Rect2(roundf(c.x - half), roundf(c.y) + dy, half * 2.0 + 1.0, 1), col)

## Banded vertical gradient with dithered rows at the band edges, like a painted pixel sky.
static func bands(ci: CanvasItem, x: float, y0: float, y1: float, w: float, top: Color, low: Color, n: int) -> void:
	var hgt: float = maxf(y1 - y0, 1.0)
	for y: int in range(int(y0), int(y1)):
		var f: float = (y - y0) / hgt * n
		var b: float = floorf(f)
		if f - b > 0.6 and y % 2 == 0:
			b += 1.0
		ci.draw_rect(Rect2(x, y, w, 1), top.lerp(low, clampf(b / n, 0.0, 1.0)))

func _draw_sky(ci: CanvasItem, w: float, hy: float) -> void:
	bands(ci, 0, 0, hy, w, _c("sky_top"), _c("sky_low"), 9)
	if scene_name == "voice" or (scene_name != "cave" and not _outdoor()):
		for i: int in 46:
			var a: float = 0.4 + 0.6 * Era45Look.hash01(i, 31)
			ci.draw_rect(Rect2(roundf(Era45Look.hash01(i, 32) * w), roundf(Era45Look.hash01(i, 33) * hy * 0.8), 1, 1), Color(_c("accent"), a))
	if bool(look.get("sun", false)) and _outdoor():
		var sp: Vector2 = _sun_pos(w, hy)
		for k: int in 3:
			disc(ci, sp, 30.0 - k * 7.0, Color(_c("sun"), 0.1 + k * 0.07))
		disc(ci, sp, 9.0, _c("sun"))

## A range of hills as 3 px columns; returns the top y of each column. Slopes that face the
## light get a 1 px rim, peaks above [param cap_at] (share of the height) a cap of [param cap].
func _ridge(ci: CanvasItem, w: float, base_y: float, height: float, col: Color, rim: Color, salt: float, peaky: bool, cap: Color = Color.TRANSPARENT) -> PackedFloat32Array:
	var step: float = 3.0
	var tops := PackedFloat32Array()
	var x: float = 0.0
	while x < w:
		var n: float = 0.5 + 0.28 * sin(x * 0.021 + salt) + 0.18 * sin(x * 0.053 + salt * 2.1) + 0.08 * sin(x * 0.13 + salt * 0.7)
		if peaky:
			n = clampf(pow(clampf(n, 0.0, 1.0), 1.7) * 1.35, 0.0, 1.0)
		var y: float = roundf(base_y - height * clampf(n, 0.06, 1.0))
		ci.draw_rect(Rect2(x, y, step, base_y - y + 1.0), col)
		tops.append(y)
		x += step
	for i: int in range(1, tops.size()):
		var lit: bool = tops[i] < tops[i - 1] if _light_dir() > 0.0 else tops[i] > tops[i - 1]
		if lit:
			ci.draw_rect(Rect2(i * step, tops[i], step, 1), rim)
		if cap.a > 0.0:
			var line: float = base_y - height * 0.6
			if tops[i] < line:
				var depth: float = line - tops[i] + roundf(Era45Look.hash01(i, int(salt * 10.0)) * 3.0)
				ci.draw_rect(Rect2(i * step, tops[i], step, depth), cap)
	return tops

## Stepped triangle (roof, pine tier, stalactite): apex at [param apex], [param hgt] rows
## (negative grows upward), [param half] the half width at the base.
static func spike(ci: CanvasItem, apex: Vector2, hgt: int, half: float, col: Color) -> void:
	var n: int = absi(hgt)
	var dir: int = 1 if hgt > 0 else -1
	for r: int in n:
		var hw: float = roundf(half * float(r + 1) / float(n))
		ci.draw_rect(Rect2(apex.x - hw, apex.y + r * dir, hw * 2.0 + 1.0, 1), col)

func _draw_far(ci: CanvasItem, w: float, h: float, hy: float) -> void:
	var dist: Color = _c("distant")
	var far: Color = _c("far")
	var rim: Color = _c("far_rim")
	var dist_rim: Color = dist.lerp(_c("sky_low"), 0.5)
	match _kind("far_kind"):
		"peaks":
			_ridge(ci, w, hy, h * 0.27, dist, dist_rim, 1.3, true, dist.lerp(Color.WHITE, 0.7))
			_ridge(ci, w, hy, h * 0.17, far, rim, 4.1, true, rim)
		"roofs":
			_ridge(ci, w, hy, h * 0.10, dist, dist_rim, 2.0, false)
			var x: float = -4.0
			var i: int = 0
			while x < w:
				var bw: float = roundf(10.0 + Era45Look.hash01(i, 41) * 16.0)
				var bh: float = roundf(h * (0.04 + Era45Look.hash01(i, 42) * 0.06))
				var top: float = hy - bh
				ci.draw_rect(Rect2(x, top, bw, bh + 1.0), far)
				spike(ci, Vector2(x + roundf(bw / 2.0), top - roundf(bw * 0.35)), int(roundf(bw * 0.35)), bw / 2.0, far.darkened(0.12))
				for wy: int in range(int(top) + 3, int(hy) - 2, 5):
					for wx: int in range(int(x) + 2, int(x + bw) - 2, 4):
						var lit: bool = Era45Look.hash01(wx * 7 + wy, 43) > 0.55
						ci.draw_rect(Rect2(wx, wy, 1, 2), Color(_c("accent"), 0.85) if lit else far.darkened(0.25))
				x += bw + 1.0
				i += 1
		"cave":
			_ridge(ci, w, hy, h * 0.22, far, rim, 0.7, false)
			for i: int in 16:
				var sx: float = roundf(Era45Look.hash01(i, 51) * w)
				var ln: int = int(8.0 + Era45Look.hash01(i, 52) * hy * 0.35)
				spike(ci, Vector2(sx, 0), ln, 2.0 + Era45Look.hash01(i, 53) * 4.0, _c("mid_dark"))
				ci.draw_rect(Rect2(sx - 1.0, 0, 1, ln * 0.6), rim)
			for i: int in 7:
				var cp := Vector2(roundf(Era45Look.hash01(i, 54) * w), roundf(hy - Era45Look.hash01(i, 55) * h * 0.12))
				disc(ci, cp, 5.0, Color(_c("accent"), 0.16))
				spike(ci, cp, -4, 1.5, _c("accent"))
		"volcano":
			_ridge(ci, w, hy, h * 0.15, dist, dist_rim, 2.4, false)
			var cx: float = roundf(w * 0.34)
			var ch: int = int(h * 0.24)
			for r: int in ch:
				var hw: float = roundf(8.0 + r * 1.5)
				ci.draw_rect(Rect2(cx - hw, hy - ch + r, hw * 2.0, 1), far)
				ci.draw_rect(Rect2(cx - hw, hy - ch + r, 1, 1), rim)
			disc(ci, Vector2(cx, hy - ch), 10.0, Color(_c("accent"), 0.25))
			ci.draw_rect(Rect2(cx - 7.0, hy - ch, 14, 2), _c("accent"))
			var lx: float = cx + 2.0
			for r: int in range(2, ch, 2):
				lx += -1.0 if Era45Look.hash01(r, 56) < 0.5 else 1.0
				ci.draw_rect(Rect2(lx, hy - ch + r, 1, 2), _c("accent2"))
		"night":
			_ridge(ci, w, hy, h * 0.16, dist, dist_rim, 1.1, false)
			_ridge(ci, w, hy, h * 0.09, far, rim, 3.3, false)
			for i: int in 4:
				var lx: float = roundf(w * (0.15 + i * 0.23))
				ci.draw_rect(Rect2(lx - 3.0, 0, 7, hy), Color(_c("accent"), 0.07))
				ci.draw_rect(Rect2(lx, 0, 1, hy), Color(_c("accent"), 0.2))
		_:
			_ridge(ci, w, hy, h * 0.2, dist, dist_rim, 1.0, false)
			_ridge(ci, w, hy, h * 0.12, far, rim, 2.6, false)

func _draw_mid(ci: CanvasItem, w: float, h: float, hy: float) -> void:
	var mid: Color = _c("mid")
	var dark: Color = _c("mid_dark")
	var rim: Color = _c("mid_rim")
	var ld: float = _light_dir()
	match _kind("mid_kind"):
		"trees":
			ci.draw_rect(Rect2(0, hy - 3.0, w, 4), dark)
			var x: float = -6.0
			var i: int = 0
			while x < w + 8.0:
				var r: float = 4.0 + Era45Look.hash01(i, 61) * 6.0
				var cy: float = roundf(hy - r * 0.6 - Era45Look.hash01(i, 62) * 3.0)
				disc(ci, Vector2(x, cy), r, dark)
				disc(ci, Vector2(x - ld, cy - 1.0), r - 1.0, mid)
				disc(ci, Vector2(x - ld * r * 0.35, cy - r * 0.35), maxf(r * 0.4, 1.0), rim)
				x += r * 1.3 + Era45Look.hash01(i, 63) * 4.0
				i += 1
		"shore":
			ci.draw_rect(Rect2(0, hy - 3.0, w, 4), mid)
			ci.draw_rect(Rect2(0, hy, w, 1), dark)
			for i: int in 60:
				var rx: float = roundf(Era45Look.hash01(i, 64) * w)
				var rh: float = 2.0 + roundf(Era45Look.hash01(i, 65) * 5.0)
				ci.draw_rect(Rect2(rx, hy - 3.0 - rh, 1, rh), dark if i % 3 else rim)
			for i: int in 6:
				disc(ci, Vector2(roundf(Era45Look.hash01(i, 66) * w), hy - 4.0), 3.0 + Era45Look.hash01(i, 67) * 3.0, mid)
		"houses":
			var x: float = -3.0
			var i: int = 0
			while x < w:
				var hw: float = roundf(16.0 + Era45Look.hash01(i, 71) * 12.0)
				var wh: float = roundf(9.0 + Era45Look.hash01(i, 72) * 6.0)
				var top: float = hy - wh
				ci.draw_rect(Rect2(x, top, hw, wh + 1.0), mid)
				ci.draw_rect(Rect2(x + (hw - 1.0 if ld < 0.0 else 0.0), top, 1, wh), rim)
				spike(ci, Vector2(x + roundf(hw / 2.0), top - 6.0), 6, hw / 2.0 + 1.0, dark)
				ci.draw_rect(Rect2(x + roundf(hw / 2.0) - 1.0, hy - 5.0, 3, 5), dark.darkened(0.4))
				for wx: float in [x + 3.0, x + hw - 5.0]:
					ci.draw_rect(Rect2(wx, top + 3.0, 2, 3), _c("accent2"))
					ci.draw_rect(Rect2(wx, top + 3.0, 2, 1), Color(_c("accent"), 0.9))
				x += hw + 2.0 + roundf(Era45Look.hash01(i, 73) * 4.0)
				i += 1
			ci.draw_rect(Rect2(0, hy, w, 1), dark.darkened(0.3))
		"pines":
			var x: float = -4.0
			var i: int = 0
			while x < w + 6.0:
				var th: float = 16.0 + Era45Look.hash01(i, 74) * 14.0
				var base: float = hy + 1.0
				ci.draw_rect(Rect2(roundf(x), base - 3.0, 1, 3), dark)
				for t: int in 3:
					var tier_h: int = int(th * 0.42)
					var apex := Vector2(roundf(x), roundf(base - 2.0 - th + t * th * 0.27))
					spike(ci, apex, tier_h, 3.0 + t * 2.5, mid)
					spike(ci, apex, int(tier_h * 0.4), (3.0 + t * 2.5) * 0.4, rim)
				x += 9.0 + Era45Look.hash01(i, 75) * 9.0
				i += 1
		"stalagmites":
			for i: int in 14:
				var sx: float = roundf(Era45Look.hash01(i, 76) * w)
				var sh: int = int(6.0 + Era45Look.hash01(i, 77) * 18.0)
				spike(ci, Vector2(sx, hy - sh), sh, 2.0 + sh * 0.25, mid)
				ci.draw_rect(Rect2(sx - ld, hy - sh + 1.0, 1, sh - 1), rim)
		"spires":
			for i: int in 11:
				var sx: float = roundf(Era45Look.hash01(i, 78) * w)
				var sw: float = 3.0 + roundf(Era45Look.hash01(i, 79) * 4.0)
				var sh: float = 8.0 + roundf(Era45Look.hash01(i, 80) * 22.0)
				ci.draw_rect(Rect2(sx, hy - sh, sw, sh + 1.0), mid)
				ci.draw_rect(Rect2(sx + 1.0, hy - sh + 3.0, 1, sh * 0.6), Color(rim, 0.8))
		"reeds":
			ci.draw_rect(Rect2(0, hy - 2.0, w, 3), dark)
			for i: int in 70:
				var rx: float = roundf(Era45Look.hash01(i, 81) * w)
				var rh: float = 2.0 + roundf(Era45Look.hash01(i, 82) * 7.0)
				ci.draw_rect(Rect2(rx, hy - 2.0 - rh, 1, rh), mid if i % 4 else rim)

func _draw_ground(ci: CanvasItem, w: float, h: float, hy: float) -> void:
	bands(ci, 0, hy + 1.0, h + 1.0, w, _c("ground_far"), _c("ground_near"), 8)
	var gk: String = _kind("ground_kind")
	if gk == "water":
		# Bright streaks on the open water, longer toward the viewer.
		for i: int in 40:
			var d: float = pow(Era45Look.hash01(i, 91), 0.8)
			var y: float = roundf(depth_y(cfg, d, h))
			ci.draw_rect(Rect2(roundf(Era45Look.hash01(i, 92) * w), y, roundf(4.0 + d * 18.0), 1), Color(_c("ground_far").lightened(0.15), 0.8))
	elif gk == "cobbles":
		# Loose cobbles scattered over the square, bigger toward the viewer.
		for i: int in 110:
			var d: float = pow(Era45Look.hash01(i, 99), 0.7)
			var y: float = roundf(depth_y(cfg, d, h))
			var x: float = roundf(Era45Look.hash01(i, 100) * (w + 10.0) - 5.0)
			var sw: float = roundf(2.0 + d * 7.0 + Era45Look.hash01(i, 101) * 2.0)
			var sh: float = maxf(roundf(1.0 + d * 2.5), 1.0)
			ci.draw_rect(Rect2(x, y - sh, sw, sh), _c("tuft_light"))
			ci.draw_rect(Rect2(x, y, sw, 1), _c("tuft"))
			ci.draw_rect(Rect2(x + sw, y - sh + 1.0, 1, sh), _c("tuft"))
	elif gk == "snow":
		for i: int in 30:
			var d: float = pow(Era45Look.hash01(i, 93), 0.8)
			var y: float = roundf(depth_y(cfg, d, h))
			ci.draw_rect(Rect2(roundf(Era45Look.hash01(i, 94) * w), y, roundf(6.0 + d * 26.0), 1), _c("tuft"))
	elif gk == "pebbles" or gk == "ash":
		for i: int in 70:
			var d: float = pow(Era45Look.hash01(i, 95), 0.8)
			var y: float = roundf(depth_y(cfg, d, h))
			var x: float = roundf(Era45Look.hash01(i, 96) * w)
			var s: float = 1.0 + roundf(d * 2.0)
			ci.draw_rect(Rect2(x, y, s + 1.0, s), _c("tuft"))
			ci.draw_rect(Rect2(x, y - 1.0, s, 1), _c("tuft_light") if gk == "pebbles" else Color(_c("accent2"), 0.7))
	# Large foreground grass in the near corners gives the floor its depth.
	if gk == "grass":
		for side: float in [0.0, 1.0]:
			for i: int in 7:
				var bx: float = roundf(absf(side * w - (2.0 + i * 4.0 + Era45Look.hash01(i, 97) * 3.0)))
				var bh: float = 6.0 + roundf(Era45Look.hash01(i, 98) * 8.0)
				ci.draw_rect(Rect2(bx, h - bh, 2, bh), _c("tuft"))
				ci.draw_rect(Rect2(bx, h - bh, 2, 1), _c("tuft_light"))

func _draw_clouds(ci: CanvasItem, w: float, hy: float) -> void:
	if not _outdoor() or scene_name == "voice":
		return
	var n: int = int(look.get("clouds", 0))
	var speed: float = float(look.get("cloud_speed", 0.0))
	for i: int in n:
		var cw: float = roundf(22.0 + Era45Look.hash01(i, 11) * 30.0)
		var y: float = roundf(6.0 + Era45Look.hash01(i, 12) * hy * 0.3)
		var x: float = fposmod(Era45Look.hash01(i, 13) * (w + cw * 2.0) + _time * speed * (0.6 + 0.8 * Era45Look.hash01(i, 14)), w + cw * 2.0) - cw
		x = roundf(x)
		var col: Color = _c("cloud")
		disc(ci, Vector2(x + cw * 0.3, y + 5.0), cw * 0.2, col)
		disc(ci, Vector2(x + cw * 0.55, y + 3.0), cw * 0.26, col)
		disc(ci, Vector2(x + cw * 0.8, y + 6.0), cw * 0.16, col)
		ci.draw_rect(Rect2(x + roundf(cw * 0.12), y + 6.0, roundf(cw * 0.8), 3), col)
		ci.draw_rect(Rect2(x + roundf(cw * 0.12), y + 9.0, roundf(cw * 0.8), 1), _c("cloud_shade"))

## Grass that sways (meadow), glints that shimmer and drift (water), sparkles (snow, cave),
## embers that rise (ember). Era IV draws them still.
func _draw_tufts(ci: CanvasItem, w: float, h: float, hy: float) -> void:
	var n: int = int(look.get("tufts", 120))
	var sway: float = float(look.get("sway", 0.0))
	var sp: float = float(look.get("sway_speed", 0.0))
	var t: float = _time
	match _kind("ground_kind"):
		"grass":
			for i: int in n:
				var d: float = pow(Era45Look.hash01(i, 21), 0.75)
				var y: float = roundf(depth_y(cfg, d, h))
				var x: float = roundf(Era45Look.hash01(i, 22) * (w + 8.0) - 4.0)
				var bh: int = int(2.0 + d * 5.0 + Era45Look.hash01(i, 23) * 2.0)
				var bw: float = 2.0 if d > 0.6 else 1.0
				var off: float = roundf(sway * sin(t * sp + x * 0.07) * (0.5 + d))
				for b: int in [-1, 0, 1]:
					var bx: float = x + b * (bw + 1.0)
					var lean: float = off + b
					ci.draw_rect(Rect2(bx, y - bh / 2.0, bw, bh / 2.0 + 1.0), _c("tuft"))
					ci.draw_rect(Rect2(bx + lean, y - bh, bw, bh - bh / 2.0), _c("tuft"))
					ci.draw_rect(Rect2(bx + lean, y - bh, bw, 1), _c("tuft_light"))
				if i % 11 == 0 and d > 0.3:
					ci.draw_rect(Rect2(x + off, y - bh - 1.0, 2, 2), _c("accent") if i % 2 else _c("accent2"))
		"water":
			var shimmer: bool = bool(look.get("shimmer", false))
			for i: int in n / 2:
				var d: float = pow(Era45Look.hash01(i, 24), 0.8)
				var y: float = roundf(depth_y(cfg, d, h))
				var ln: float = roundf(2.0 + d * 7.0)
				var x: float = roundf(fposmod(Era45Look.hash01(i, 25) * w + t * (2.0 + d * 5.0) * (1.0 if i % 2 else -1.0), w))
				ci.draw_rect(Rect2(x, y, ln, 1), _c("tuft"))
				var on: bool = sin(t * 3.0 + i * 1.9) > 0.2 if shimmer else i % 3 == 0
				if on:
					ci.draw_rect(Rect2(x + 1.0, y - 1.0, maxf(ln - 2.0, 1.0), 1), _c("tuft_light"))
		"snow", "pebbles":
			for i: int in n / 3:
				var d: float = pow(Era45Look.hash01(i, 26), 0.8)
				if sin(t * 2.0 + i * 1.7) > 0.2 or (t == 0.0 and i % 2 == 0):
					ci.draw_rect(Rect2(roundf(Era45Look.hash01(i, 27) * w), roundf(depth_y(cfg, d, h)) - 1.0, 1, 1), _c("tuft_light") if scene_name == "snow" else _c("accent"))
		"ash":
			for i: int in n / 5:
				var x: float = roundf(Era45Look.hash01(i, 28) * w + sin(t + i) * 2.0)
				var y: float = roundf(fposmod(Era45Look.hash01(i, 29) * h - t * (8.0 + 6.0 * Era45Look.hash01(i, 30)), h))
				ci.draw_rect(Rect2(x, y, 1, 1), _c("tuft_light"))

## Lower edge of a convex outline [param o] at column [param x] (where the wall hangs from).
static func lower_y(o: PackedVector2Array, x: float) -> float:
	var best: float = -INF
	for i: int in o.size():
		var a: Vector2 = o[i]
		var b: Vector2 = o[(i + 1) % o.size()]
		if x < minf(a.x, b.x) or x > maxf(a.x, b.x) or is_equal_approx(a.x, b.x):
			continue
		best = maxf(best, lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return best

## The slab top as an octagon: the trapezoid of slab_quad with its corners cut, so it reads as
## a cut turf block, never an oval.
static func knoll_outline(q: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in 4:
		var a: Vector2 = q[(i + 3) % 4]
		var b: Vector2 = q[i]
		var c: Vector2 = q[(i + 1) % 4]
		var r: float = minf(7.0, minf(a.distance_to(b), b.distance_to(c)) * 0.2)
		out.append((b + (a - b).normalized() * r).round())
		out.append((b + (c - b).normalized() * r).round())
	return out

func _draw_knoll(ci: CanvasItem, side: String, sz: Vector2) -> void:
	var q: PackedVector2Array = slab_quad(cfg, side, sz)
	var o: PackedVector2Array = knoll_outline(q)
	var d: float = float(cfg["slabs"][side]["depth"])
	var t: float = roundf(float(look.get("thickness", 12)) * depth_scale(cfg, d))
	var kk: String = _kind("knoll_kind")
	var salt: int = 0 if side == "foe" else 500
	var sh: Array = look.get("shadow", [5, 3])
	var ld: float = _light_dir()
	# Soft shadow: the block three times, each a little further away from the light.
	if kk != "isle":
		for k: int in 3:
			var off := Vector2(float(sh[0]) * (0.5 + k * 0.35), t + float(sh[1]) * (0.4 + k * 0.4)).round()
			var so := PackedVector2Array()
			for p: Vector2 in o:
				so.append(p + off)
			ci.draw_colored_polygon(so, Color(_c("shadow"), 0.16))
	# Side wall, column by column: earth with a darker lower band, strata and a ragged foot.
	var x0: int = int(minf(o[7].x, o[6].x))
	var x1: int = int(maxf(o[4].x, o[5].x))
	for x: int in range(x0, x1 + 1):
		var top: float = lower_y(o, x + 0.5)
		if top == -INF:
			continue
		var col_h: float = t + floorf(Era45Look.hash01(x / 2 + salt, 101) * 3.0)
		ci.draw_rect(Rect2(x, top, 1, roundf(col_h * 0.55)), _c("side"))
		ci.draw_rect(Rect2(x, top + roundf(col_h * 0.55), 1, col_h - roundf(col_h * 0.55)), _c("side_dark"))
		if Era45Look.hash01(x / 3 + salt, 102) > 0.55:
			ci.draw_rect(Rect2(x, top + roundf(t * 0.35), 1, 1), _c("side_dark"))
		if Era45Look.hash01(x + salt, 103) > 0.93:
			ci.draw_rect(Rect2(x, top + roundf(t * 0.7), 1, 1), _c("top_light") if kk != "basalt" else _c("accent"))
		if kk == "basalt" and Era45Look.hash01(x / 4 + salt, 104) > 0.8:
			ci.draw_rect(Rect2(x, top + 2.0, 1, col_h - 3.0), Color(_c("accent"), 0.7))
		if (x == x0 and ld > 0.0) or (x == x1 and ld < 0.0) or (x == x1 and ld > 0.0):
			ci.draw_rect(Rect2(x, top, 1, col_h), _c("side_dark") if (x == x1) == (ld > 0.0) else _c("side"))
	if kk == "isle":
		# Water laps at the foot of the island stone.
		for k: int in 2:
			var y: float = roundf(q[3].y + t + 1.0 + k * 2.0)
			var ext: float = 6.0 + k * 4.0
			for x: float in range(roundf(o[6].x - ext), roundf(o[5].x + ext), 5):
				ci.draw_rect(Rect2(x, y, 3, 1), Color(_c("tuft_light"), 0.75 - k * 0.25))
	# Top face, its far edge in shade and its near lip catching the light.
	ci.draw_colored_polygon(o, _c("top"))
	ci.draw_line(o[1] + Vector2(0, 0.5), o[2] + Vector2(0, 0.5), _c("top_dark"))
	ci.draw_line(o[6] + Vector2(0, -0.5), o[5] + Vector2(0, -0.5), _c("top_light"))
	var lit_a: Vector2 = o[7] if ld > 0.0 else o[3]
	var lit_b: Vector2 = o[0] if ld > 0.0 else o[4]
	var rim: String = str(look.get("rim", ""))
	ci.draw_line(lit_a, lit_b, Color(rim) if not rim.is_empty() else _c("top_light"))
	if not rim.is_empty():
		ci.draw_line(o[4] + Vector2(0, -0.5), o[5] + Vector2(0, -0.5), Color(rim))
		ci.draw_line(o[2], o[3], Color(rim))
	# Texture on the top: blades, stones, moss or snow glitter.
	var area: float = absf((q[1].x - q[0].x + q[2].x - q[3].x) / 2.0 * (q[3].y - q[0].y))
	var count: int = clampi(int(area / 30.0), 8, 160)
	for i: int in count:
		var u: float = 0.06 + 0.88 * Era45Look.hash01(i + salt, 111)
		var v: float = 0.12 + 0.8 * Era45Look.hash01(i + salt, 112)
		var p: Vector2 = q[0].lerp(q[1], u).lerp(q[3].lerp(q[2], u), v).round()
		match kk:
			"turf", "drift":
				ci.draw_rect(Rect2(p.x, p.y - 1.0, 1, 2), _c("top_dark"))
				ci.draw_rect(Rect2(p.x + ld, p.y - 2.0, 1, 1), _c("top_light"))
			"rock", "basalt":
				ci.draw_rect(Rect2(p.x, p.y, 2, 1), _c("top_dark"))
				ci.draw_rect(Rect2(p.x, p.y - 1.0, 1, 1), _c("top_light"))
			"isle":
				ci.draw_rect(Rect2(p.x, p.y, 2, 1), _c("top_light") if i % 2 else _c("top_dark"))
			"paving":
				if i % 2 == 0:
					ci.draw_rect(Rect2(p.x, p.y, roundf(3.0 + v * 6.0), 1), _c("top_dark"))
		if kk == "turf" and i % 9 == 0:
			ci.draw_rect(Rect2(p.x, p.y - 1.0, 2, 2), _c("accent") if i % 2 else _c("accent2"))
	# Turf and snow hang over the near edge in small tufts.
	if kk == "turf" or kk == "drift":
		var x: float = o[6].x + 2.0
		var j: int = 0
		while x < o[5].x - 2.0:
			var y: float = lower_y(o, x + 0.5)
			var hang: float = 1.0 + floorf(Era45Look.hash01(j + salt, 121) * 3.0)
			ci.draw_rect(Rect2(x, y, 2, hang), _c("top"))
			ci.draw_rect(Rect2(x, y + hang, 1, 1), _c("top_dark"))
			x += 3.0 + floorf(Era45Look.hash01(j + salt, 122) * 4.0)
			j += 1

## Era V light over the whole field (sprites included): a warm wash, slow sun rays from the low
## sun and a soft darkening at the edges. Rays hold still under reduced motion.
func _draw_light(ci: CanvasItem, w: float, h: float, hy: float) -> void:
	var g: Dictionary = look.get("grade", {})
	var warm := Color(str(g.get("colour", "ffffff")))
	var amt: float = float(g.get("amount", 0.0))
	if amt > 0.0:
		for y: int in range(0, int(h), 4):
			ci.draw_rect(Rect2(0, y, w, 4), Color(warm, lerpf(amt * 0.7, amt * 0.25, y / h)))
	var rays: int = int(look.get("rays", 0))
	if bool(look.get("sun", false)) and _outdoor() and rays > 0:
		var sp: Vector2 = _sun_pos(w, hy)
		var a0: float = float(look.get("ray_alpha", 0.0))
		for i: int in rays:
			var pulse: float = 0.7 + 0.3 * sin(_time * 0.8 + i * 1.7)
			var bx: float = w * (-0.25 + i * 0.28)
			var tri := PackedVector2Array([sp, Vector2(bx, h), Vector2(bx + w * 0.1, h)])
			ci.draw_colored_polygon(tri, Color(_c("sun"), a0 * pulse))
	var v: float = float(look.get("vignette", 0.0))
	if v > 0.0:
		var dark := Color(_c("shadow"), 1.0)
		for k: int in 6:
			var a: float = v * (1.0 - k / 6.0) * 0.4
			var c := Color(dark, a)
			ci.draw_rect(Rect2(k * 2, 0, 2, h), c)
			ci.draw_rect(Rect2(w - k * 2 - 2, 0, 2, h), c)
			ci.draw_rect(Rect2(0, k * 2, w, 2), c)
