class_name ElementFx
extends Control
## Element effects for battle arts (items 2357 to 2366). One drawing routine per element and
## phase: charge at the user, travel to the target (skipped for physical arts) and impact.
##   await fx.play(Elements.E.EMBER, MoveData.Kind.FOCUS, user_rect, target_rect)
## Shapes are the 8x8 Era I images from tools/art/gen_fx.py; everything snaps to whole pixels.
## No screen flashes: the brightest effect (Lumen) stays at 60 % and fades in 0.2 s.

enum Phase { NONE, CHARGE, TRAVEL, IMPACT }

## Seconds per phase at 1x (item 2358); divided by the battle speed.
const CHARGE_TIME: float = 0.15
const TRAVEL_TIME: float = 0.2
const IMPACT_TIME: float = 0.25
## Under reduced motion only a short impact plays.
const REDUCED_IMPACT_TIME: float = 0.12
const LUMEN_MAX_ALPHA: float = 0.6
const FX_PATH: String = "res://art/era1/fx/%s_%d.png"
## Impact size for a very effective hit and for a weak one (item 2376), no extra text.
const IMPACT_SCALE_STRONG: float = 1.5
const IMPACT_SCALE_WEAK: float = 0.5

var phase: Phase = Phase.NONE
## Progress through the current phase, 0..1.
var t: float = 0.0
var element: int = 0
var user_sprite: Control
var _from: Vector2
var _to: Vector2
var _ground_from: Vector2
var _ground_to: Vector2
## Size of the impact drawing around the target (1, 1.5 or 0.5).
var impact_size: float = 1.0
## True while a missed art flies past its target (item 2375).
var missed: bool = false
var _rng := RandomNumberGenerator.new()
static var _tex: Dictionary[String, Texture2D] = {}
## Phases played by the last play() call (tests).
var played: Array[Phase] = []
signal _phase_done

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 2357
	set_process(false)

static func shape(name: String, shade: int) -> Texture2D:
	var key: String = "%s_%d" % [name, shade]
	if not _tex.has(key):
		var path: String = FX_PATH % [name, shade]
		_tex[key] = load(path) if ResourceLoader.exists(path) else null
	return _tex[key]

## Phases an art of [param kind] plays (physical arts have no travel phase). A miss has no
## impact: a ranged art flies on past the target instead.
static func phases_for(kind: int, reduced: bool, miss: bool = false) -> Array[Phase]:
	if reduced:
		return [] as Array[Phase] if miss else [Phase.IMPACT] as Array[Phase]
	if kind == MoveData.Kind.PHYSICAL:
		return [Phase.CHARGE] as Array[Phase] if miss else [Phase.CHARGE, Phase.IMPACT] as Array[Phase]
	if miss:
		return [Phase.CHARGE, Phase.TRAVEL]
	return [Phase.CHARGE, Phase.TRAVEL, Phase.IMPACT]

## Impact size for a hit of effectiveness [param eff].
static func impact_scale(eff: float) -> float:
	if eff > 1.0:
		return IMPACT_SCALE_STRONG
	if eff < 1.0:
		return IMPACT_SCALE_WEAK
	return 1.0

static func phase_time(p: Phase, reduced: bool) -> float:
	if reduced:
		return REDUCED_IMPACT_TIME
	match p:
		Phase.CHARGE: return CHARGE_TIME
		Phase.TRAVEL: return TRAVEL_TIME
	return IMPACT_TIME

## Plays the effect from [param from] (user) to [param to] (target), both in this node's space.
func play(p_element: int, kind: int, from: Rect2, to: Rect2, miss: bool = false, p_impact_size: float = 1.0) -> void:
	element = p_element
	missed = miss
	impact_size = p_impact_size
	_from = from.get_center().round()
	_to = to.get_center().round()
	if miss and _to != _from:
		# Fly on past the target until well outside the battle field.
		var reach: float = maxf(size.x, size.y) + 32.0 if size != Vector2.ZERO else 400.0
		_to = (_from + (_to - _from).normalized() * reach).round()
	_ground_from = Vector2(_from.x, from.end.y - 2).round()
	_ground_to = Vector2(_to.x, to.end.y - 2).round()
	played.clear()
	var reduced: bool = Juice.reduced()
	var home: Vector2 = user_sprite.position if user_sprite != null else Vector2.ZERO
	for p: Phase in phases_for(kind, reduced, miss):
		played.append(p)
		phase = p
		t = 0.0
		if p == Phase.IMPACT and element == Elements.E.STONE:
			Juice.add_trauma(0.12, Elements.E.STONE)
		await _run_phase(phase_time(p, reduced) / Juice.speed())
		if user_sprite != null:
			user_sprite.position = home
	phase = Phase.NONE
	queue_redraw()

func _run_phase(time: float) -> void:
	if not is_inside_tree() or time <= 0.0:
		return
	var elapsed: float = 0.0
	while elapsed < time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		t = clampf(elapsed / time, 0.0, 1.0)
		if element == Elements.E.VOLT and phase == Phase.CHARGE and user_sprite != null:
			# Volt: the user trembles 1 px while charging.
			user_sprite.position += Vector2(1 if Engine.get_process_frames() % 2 == 0 else -1, 0)
		queue_redraw()

# --- Drawing ------------------------------------------------------------------

func _ink(k: int, a: float = 1.0) -> Color:
	var c: Color = EraManager.INK_PALETTE[clampi(k, 0, 3)]
	c.a = a
	return c

func _px(p: Vector2, k: int, a: float = 1.0, s: int = 1) -> void:
	draw_rect(Rect2(p.round(), Vector2(s, s)), _ink(k, a))

func _shape(name: String, at: Vector2, k: int, a: float = 1.0) -> void:
	var tex: Texture2D = shape(name, k)
	if tex != null:
		draw_texture(tex, (at - Vector2(4, 4)).round(), Color(1, 1, 1, a))
	else:
		_px(at, k, a, 2)

## Point along the user-to-target path at [param k], lifted by [param arc] at the midpoint.
func _along(k: float, arc: float = 0.0) -> Vector2:
	return (_from.lerp(_to, k) + Vector2(0, -arc * 4.0 * k * (1.0 - k))).round()

func _line(a: Vector2, b: Vector2, k: int, alpha: float = 1.0) -> void:
	var n: int = int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i: int in n + 1:
		_px(a.lerp(b, float(i) / maxf(n, 1)), k, alpha)

func _draw() -> void:
	if phase == Phase.NONE:
		return
	if phase == Phase.IMPACT and impact_size != 1.0:
		# Scale the whole impact around the target's centre.
		draw_set_transform(_to * (1.0 - impact_size), 0.0, Vector2.ONE * impact_size)
	match element:
		Elements.E.EMBER: _draw_ember()
		Elements.E.TIDE: _draw_tide()
		Elements.E.BLOOM: _draw_bloom()
		Elements.E.VOLT: _draw_volt()
		Elements.E.STONE: _draw_stone()
		Elements.E.GALE: _draw_gale()
		Elements.E.LUMEN: _draw_lumen()
		Elements.E.UMBRA: _draw_umbra()

## Ember: three sparks circle the user; a spark hops in a flat arc; five embers rise.
func _draw_ember() -> void:
	match phase:
		Phase.CHARGE:
			for i: int in 3:
				var ang: float = t * TAU + i * TAU / 3.0
				_shape("spark", _from + Vector2(cos(ang) * 12.0, sin(ang) * 6.0), 2)
		Phase.TRAVEL:
			_shape("spark", _along(t, 10.0), 2)
		Phase.IMPACT:
			for i: int in 5:
				var x: float = (i - 2) * 4.0
				_px(_to + Vector2(x, 4.0 - t * (10.0 + i * 2.0)), 2 if i % 2 == 0 else 3, 1.0 - t * 0.5, 2)

## Tide: a ring spreads under the user; a wavy line with 3 px swing; six drops fall.
func _draw_tide() -> void:
	match phase:
		Phase.CHARGE:
			var r: float = 3.0 + t * 12.0
			for i: int in 16:
				var ang: float = i * TAU / 16.0
				_px(_ground_from + Vector2(cos(ang) * r, sin(ang) * r * 0.35), 1)
		Phase.TRAVEL:
			for i: int in 12:
				var k: float = clampf(t - i * 0.03, 0.0, 1.0)
				var p: Vector2 = _along(k)
				var n: Vector2 = (_to - _from).normalized().orthogonal()
				_px(p + n * roundf(3.0 * sin(k * TAU * 2.0)), 1)
		Phase.IMPACT:
			for i: int in 6:
				var x: float = (i - 2.5) * 5.0
				_shape("drop", _to + Vector2(x, -8.0 + t * (14.0 + (i % 3) * 3.0)), 1, 1.0 - t * 0.4)

## Bloom: four leaves rise from the ground; a leaf whirl flies straight; vines wrap the target.
func _draw_bloom() -> void:
	match phase:
		Phase.CHARGE:
			for i: int in 4:
				_shape("leaf", _ground_from + Vector2((i - 1.5) * 7.0, -t * (8.0 + i * 3.0)), 1)
		Phase.TRAVEL:
			for i: int in 3:
				var ang: float = t * TAU * 2.0 + i * TAU / 3.0
				_shape("leaf", _along(t) + Vector2(cos(ang), sin(ang)) * 4.0, 1 + i % 2)
		Phase.IMPACT:
			# Two frames of growth: half the vine, then all of it.
			var reach: float = 0.5 if t < 0.5 else 1.0
			for side: int in [-1, 1]:
				var base: Vector2 = _ground_to + Vector2(side * 8.0, 0)
				_line(base, base + Vector2(-side * 4.0, -16.0 * reach), 1)

## Volt: the user trembles; a zigzag redrawn every frame; a four-ray star.
func _draw_volt() -> void:
	match phase:
		Phase.CHARGE:
			_shape("zag", _from + Vector2(0, -12), 2)
		Phase.TRAVEL:
			var a: Vector2 = _from
			var steps: int = 6
			for i: int in steps:
				var k: float = float(i + 1) / steps * t
				var b: Vector2 = _along(k) + Vector2(0, _rng.randi_range(-3, 3))
				_line(a, b, 0)
				a = b
		Phase.IMPACT:
			var ray: float = 4.0 + 6.0 * (1.0 - absf(t * 2.0 - 1.0))
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				_line(_to, _to + d * ray, 0)

## Stone: rocks push up under the user; a rock in a high arc with a shadow; six splinters.
func _draw_stone() -> void:
	match phase:
		Phase.CHARGE:
			for i: int in 3:
				_shape("rock", _ground_from + Vector2((i - 1) * 8.0, 4.0 - t * 6.0), 1)
		Phase.TRAVEL:
			_px(Vector2(_from.x, _ground_from.y).lerp(Vector2(_to.x, _ground_to.y), t) - Vector2(2, 0), 0, 0.6, 4)
			_shape("rock", _along(t, 28.0), 1)
		Phase.IMPACT:
			for i: int in 6:
				var ang: float = i * TAU / 6.0
				_px(_to + Vector2(cos(ang), sin(ang)) * (2.0 + t * 12.0), 1, 1.0 - t * 0.5, 2)

## Gale: streaks drawn in toward the user; a vortex of three arcs; streaks sweep past the target.
func _draw_gale() -> void:
	match phase:
		Phase.CHARGE:
			for i: int in 3:
				var y: float = (i - 1) * 6.0
				var x: float = 24.0 * (1.0 - t)
				_line(_from + Vector2(-x - 6, y), _from + Vector2(-x, y), 2)
				_line(_from + Vector2(x, y + 3), _from + Vector2(x + 6, y + 3), 2)
		Phase.TRAVEL:
			for i: int in 3:
				var c: Vector2 = _along(t)
				var r: float = 3.0 + i * 3.0
				for j: int in 6:
					var ang: float = t * TAU * 3.0 + i * 1.3 + j * 0.35
					_px(c + Vector2(cos(ang), sin(ang)) * r, 2)
		Phase.IMPACT:
			for i: int in 3:
				var x: float = lerpf(-20.0, 20.0, t) + i * 4.0
				_shape("streak", _to + Vector2(x, (i - 1) * 5.0), 2, 1.0 - t * 0.3)

## Lumen: a light point above the user grows 1 to 5 px; a straight beam; a cross glint that
## fades in 0.2 s, never brighter than 60 % (no flash).
func _draw_lumen() -> void:
	match phase:
		Phase.CHARGE:
			var s: int = 1 + int(round(t * 4.0))
			_px(_from + Vector2(-s / 2.0, -14.0), 2, LUMEN_MAX_ALPHA, s)
		Phase.TRAVEL:
			_line(_from, _along(t), 2, LUMEN_MAX_ALPHA)
		Phase.IMPACT:
			var a: float = LUMEN_MAX_ALPHA * clampf(1.0 - t * IMPACT_TIME / 0.2, 0.0, 1.0)
			_shape("glint", _to, 2, a)

## Umbra: a shadow peels away from the user, crawls along the ground, closes round the target.
func _draw_umbra() -> void:
	match phase:
		Phase.CHARGE:
			_shape("shade", _ground_from + Vector2(t * 6.0, 0), 0, 0.8)
		Phase.TRAVEL:
			_shape("shade", _ground_from.lerp(_ground_to, t), 0, 0.8)
		Phase.IMPACT:
			var up: float = 1.0 - absf(t * 2.0 - 1.0)
			for side: int in [-1, 1]:
				_line(_ground_to + Vector2(side * 9.0, 0), _ground_to + Vector2(side * 9.0, -14.0 * up), 0, 0.8)
			_shape("shade", _ground_to, 0, 0.8)
