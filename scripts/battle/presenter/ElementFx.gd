class_name ElementFx
extends Control
## Element effects for battle arts (items 2357 to 2366). One drawing routine per element and
## phase: charge at the user, travel to the target (skipped for physical arts) and impact.
##   await fx.play(Elements.E.EMBER, MoveData.Kind.FOCUS, user_rect, target_rect)
## Shapes are the 8x8 Era I images from tools/art/gen_fx.py; everything snaps to whole pixels.
## No screen flashes: the brightest effect (Lumen) stays at 60 % and fades in 0.2 s.

enum Phase { NONE, CHARGE, TRAVEL, IMPACT, AFTER }

## Seconds per phase at 1x (item 2358); divided by the battle speed.
const CHARGE_TIME: float = 0.15
const TRAVEL_TIME: float = 0.2
const IMPACT_TIME: float = 0.25
## Under reduced motion only a short impact plays.
const REDUCED_IMPACT_TIME: float = 0.12
const LUMEN_MAX_ALPHA: float = 0.6
const FX_REL: String = "fx/%s_%d.png"
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
## Particle count factor from the art's power (item 2368): 1, 1.5 or 2.
var amount: float = 1.0
## What follows the hit (items 2370 to 2374): "" none, "heal" rising motes at the user
## instead of an impact, "drain" four motes back to the user, "energy_drain" three
## diamonds pulled off the target, "recoil" a half-size impact at the user, "field" a wave
## across the whole battle field.
var after: String = ""
const AFTER_TIME: float = 0.2
const AFTERS: Array[String] = ["heal", "drain", "energy_drain", "recoil", "field"]
## Status arts show what they do instead of an impact (item 2369): "up" a raised stat,
## "down" a lowered one, "ring" any other effect. "" for arts that hit.
var symbol: String = ""
## The user's second element, or -1: a hit mixes in two of its particles (item 2367).
var second_element: int = -1

## The 8x8 shape that stands for each element (heal motes, drain motes, field wave).
const ELEMENT_SHAPES: Array[String] = ["spark", "drop", "leaf", "zag", "rock", "streak", "glint", "shade", "shade", "glint"]
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
		var path: String = EraManager.art_path(FX_REL % [name, shade])
		_tex[key] = load(path) if not path.is_empty() else null
	return _tex[key]

static func clear_cache() -> void:
	_tex.clear()

## Phases an art of [param kind] plays (physical arts have no travel phase). A miss has no
## impact: a ranged art flies on past the target instead. [param p_after] adds the AFTER
## phase; a heal shows it in place of travel and impact.
static func phases_for(kind: int, reduced: bool, miss: bool = false, p_after: String = "") -> Array[Phase]:
	var out: Array[Phase] = []
	if p_after == "heal":
		out.assign([Phase.AFTER] if reduced else [Phase.CHARGE, Phase.AFTER])
		return out
	if reduced:
		if not miss:
			out.append(Phase.IMPACT)
		return out
	out.append(Phase.CHARGE)
	if kind != MoveData.Kind.PHYSICAL:
		out.append(Phase.TRAVEL)
	if not miss:
		out.append(Phase.IMPACT)
		if not p_after.is_empty():
			out.append(Phase.AFTER)
	return out

## The symbol a status art shows over its target (item 2369), and whether that target is
## the foe: {"symbol": "up" | "down" | "ring" | "", "on_foe": bool}.
static func status_symbol(mv: MoveData) -> Dictionary:
	if mv == null or mv.kind != MoveData.Kind.STATUS or mv.has_effect(&"heal_self"):
		return {"symbol": "", "on_foe": false}
	for fx: Dictionary in mv.effects:
		if StringName(fx.get("id", "")) == &"stat_change":
			var raise: bool = int(fx.get("amount", 0)) > 0
			return {"symbol": "up" if raise else "down", "on_foe": not bool(fx.get("self", true))}
	var on_foe: bool = mv.has_effect(&"inflict_status") or mv.has_effect(&"energy_drain") \
		or mv.has_effect(&"energy_burn") or mv.has_effect(&"heal_block") or mv.has_effect(&"cure_target")
	return {"symbol": "ring", "on_foe": on_foe}

## The second element of a user with [param elements], other than the art's own, or -1.
static func second_for(elements: Array, art_element: int) -> int:
	for e: Variant in elements:
		if int(e) != art_element:
			return int(e)
	return -1

## What an art shows after its hit, from its effects (items 2370 to 2374).
static func after_for(mv: MoveData) -> String:
	if mv == null:
		return ""
	for pair: Array in [[&"set_field", "field"], [&"heal_self", "heal"], [&"drain", "drain"],
			[&"energy_drain", "energy_drain"], [&"recoil", "recoil"]]:
		if mv.has_effect(pair[0]):
			return pair[1]
	return ""

## Particle factor for an art of [param power]: up to 50 normal, up to 90 half again, above
## that twice as many (item 2368).
static func particles_for_power(power: int) -> float:
	if power > 90:
		return 2.0
	if power > 50:
		return 1.5
	return 1.0

## [param base] particles scaled by [member amount], at least one.
func _n(base: int) -> int:
	return maxi(1, roundi(base * amount))

## Offset of particle [param i] of [param n] around the middle, [param gap] pixels apart.
static func _spread(i: int, n: int, gap: float) -> float:
	return (i - (n - 1) / 2.0) * gap

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
		Phase.AFTER: return AFTER_TIME
	return IMPACT_TIME

## Plays the effect from [param from] (user) to [param to] (target), both in this node's space.
func play(p_element: int, kind: int, from: Rect2, to: Rect2, miss: bool = false, p_impact_size: float = 1.0, p_amount: float = 1.0, p_after: String = "", p_symbol: String = "", p_second: int = -1) -> void:
	element = p_element
	symbol = p_symbol
	second_element = p_second
	amount = p_amount
	after = "" if miss and p_after != "heal" else p_after
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
	for p: Phase in phases_for(kind, reduced, miss, after):
		played.append(p)
		phase = p
		t = 0.0
		if p == Phase.IMPACT and element == Elements.E.STONE and symbol.is_empty():
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
	if phase == Phase.AFTER:
		_draw_after()
		return
	if phase == Phase.IMPACT and not symbol.is_empty():
		_draw_symbol()
		return
	if phase == Phase.IMPACT and impact_size != 1.0:
		# Scale the whole impact around the target's centre.
		draw_set_transform(_to * (1.0 - impact_size), 0.0, Vector2.ONE * impact_size)
	_draw_element()
	if phase == Phase.IMPACT and second_element >= 0 and second_element != element:
		# Two particles of the user's second element join the impact.
		var s2: String = ELEMENT_SHAPES[clampi(second_element, 0, ELEMENT_SHAPES.size() - 1)]
		for side: int in [-1, 1]:
			_shape(s2, _to + Vector2(side * (6.0 + t * 6.0), -4.0 - t * 6.0), 1, 1.0 - t * 0.5)

## A status art's symbol over its target, drawn as a column of pixels topped by the
## element's own shape (item 2369): rising arrow, sinking arrow or a ring.
func _draw_symbol() -> void:
	var s: String = _element_shape()
	var top: Vector2 = _to + Vector2(0, -14.0)
	match symbol:
		"up", "down":
			var dir: float = -1.0 if symbol == "up" else 1.0
			var shift: float = roundf(dir * t * 4.0)
			for i: int in 7:
				_px(top + Vector2(0, shift + (i - 3) * 1.0), 2)
			var tip: Vector2 = top + Vector2(0, shift + dir * 4.0)
			for i: int in range(1, 4):
				_px(tip + Vector2(-i, -dir * i), 2)
				_px(tip + Vector2(i, -dir * i), 2)
			_shape(s, tip + Vector2(0, dir * 5.0), 2, 1.0 - t * 0.4)
		_:
			var r: float = 6.0 + t * 2.0
			for i: int in 12:
				var ang: float = i * TAU / 12.0
				_px(top + Vector2(cos(ang), sin(ang)) * r, 2)
			_shape(s, top, 2, 1.0 - t * 0.4)

func _draw_element() -> void:
	match element:
		Elements.E.EMBER: _draw_ember()
		Elements.E.TIDE: _draw_tide()
		Elements.E.BLOOM: _draw_bloom()
		Elements.E.VOLT: _draw_volt()
		Elements.E.STONE: _draw_stone()
		Elements.E.GALE: _draw_gale()
		Elements.E.LUMEN: _draw_lumen()
		Elements.E.UMBRA: _draw_umbra()
		# Era II elements borrow the closest Era I look until they get their own effects.
		Elements.E.INK: _draw_umbra()
		Elements.E.ECHO: _draw_lumen()

func _element_shape() -> String:
	return ELEMENT_SHAPES[clampi(element, 0, ELEMENT_SHAPES.size() - 1)]

## The AFTER phase (items 2370 to 2374).
func _draw_after() -> void:
	var s: String = _element_shape()
	match after:
		"heal":
			# Motes in the element's shape rise from the user's feet; no impact.
			var motes: int = _n(4)
			for i: int in motes:
				var rise: float = t * (14.0 + (i % 2) * 6.0)
				_shape(s, _ground_from + Vector2(_spread(i, motes, 6.0), -4.0 - rise), 2, 1.0 - t * 0.6)
		"drain":
			# Four motes wander from the target back to the user.
			for i: int in 4:
				var k: float = clampf(t * 1.3 - i * 0.1, 0.0, 1.0)
				_shape(s, _to.lerp(_from, k) + Vector2(0, -6.0 * sin(k * PI) + (i - 1.5) * 3.0), 1)
		"energy_drain":
			# Three small diamonds are pulled up off the target and dissolve.
			for i: int in 3:
				var c: Vector2 = _to + Vector2((i - 1) * 7.0, -6.0 - t * 12.0)
				var r: int = maxi(0, 3 - int(t * 4.0))
				for d: int in r + 1:
					for p: Vector2 in [Vector2(d - r, -d), Vector2(r - d, -d), Vector2(d - r, d), Vector2(r - d, d)]:
						_px(c + p, 2, 1.0 - t * 0.7)
		"recoil":
			# A half-size impact of the same element at the user.
			var keep_to: Vector2 = _to
			var keep_phase: Phase = phase
			_to = _from
			phase = Phase.IMPACT
			draw_set_transform(_from * 0.5, 0.0, Vector2.ONE * 0.5)
			_draw_element()
			draw_set_transform(Vector2.ZERO)
			_to = keep_to
			phase = keep_phase
		"field":
			# A wave of the element's shape runs once from left to right over the field.
			var x: float = lerpf(-8.0, size.x + 8.0, t)
			var rows: int = maxi(3, int(size.y / 12.0))
			for i: int in rows:
				var y: float = (i + 0.5) * size.y / rows
				_shape(s, Vector2(x + roundf(3.0 * sin(i * 1.7)), y), 1, 0.8)

## Ember: three sparks circle the user; a spark hops in a flat arc; five embers rise.
func _draw_ember() -> void:
	match phase:
		Phase.CHARGE:
			var sparks: int = _n(3)
			for i: int in sparks:
				var ang: float = t * TAU + i * TAU / sparks
				_shape("spark", _from + Vector2(cos(ang) * 12.0, sin(ang) * 6.0), 2)
		Phase.TRAVEL:
			_shape("spark", _along(t, 10.0), 2)
		Phase.IMPACT:
			var embers: int = _n(5)
			for i: int in embers:
				var x: float = _spread(i, embers, 4.0)
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
			var drops: int = _n(6)
			for i: int in drops:
				var x: float = _spread(i, drops, 5.0)
				_shape("drop", _to + Vector2(x, -8.0 + t * (14.0 + (i % 3) * 3.0)), 1, 1.0 - t * 0.4)

## Bloom: four leaves rise from the ground; a leaf whirl flies straight; vines wrap the target.
func _draw_bloom() -> void:
	match phase:
		Phase.CHARGE:
			var leaves: int = _n(4)
			for i: int in leaves:
				_shape("leaf", _ground_from + Vector2(_spread(i, leaves, 7.0), -t * (8.0 + i * 3.0)), 1)
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
			var splinters: int = _n(6)
			for i: int in splinters:
				var ang: float = i * TAU / splinters
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
			var streaks: int = _n(3)
			for i: int in streaks:
				var x: float = lerpf(-20.0, 20.0, t) + i * 4.0
				_shape("streak", _to + Vector2(x, _spread(i, streaks, 5.0)), 2, 1.0 - t * 0.3)

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
