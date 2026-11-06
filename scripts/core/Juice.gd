extends Node
## Autoload "Juice": every game-feel helper in one place (plan area 6, items 2225 to 2259).
##   Juice.tween(node, "position", to, "move")   named curve, pixel-snapped, battle speed aware
##   Juice.pop(node)                              1.0 -> 1.15 -> 1.0 confirm bounce
##   Juice.add_trauma(Juice.TRAUMA_HIT)           screen shake on the registered ShakeRoot
##   await Juice.hitstop(0.4)                     short freeze after a hit (share of HP lost)
## Every helper respects reduced motion through Juice.reduced(), the only place that reads it.

## Fixed curves: transition, easing and duration in seconds (item 2226).
const CURVES: Dictionary = {
	"open": {"trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT, "time": 0.18},
	"close": {"trans": Tween.TRANS_QUAD, "ease": Tween.EASE_IN, "time": 0.12},
	"move": {"trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_IN_OUT, "time": 0.22},
	"impact": {"trans": Tween.TRANS_EXPO, "ease": Tween.EASE_OUT, "time": 0.10},
	"settle": {"trans": Tween.TRANS_ELASTIC, "ease": Tween.EASE_OUT, "time": 0.35},
	# Brightening after a map change: no overshoot (item 2233).
	"fade": {"trans": Tween.TRANS_SINE, "ease": Tween.EASE_OUT, "time": 0.11},
}
## Under reduced motion no movement tween runs longer than this (item 2655).
const REDUCED_MAX_TIME: float = 0.15

## Pop: scale up in POP_UP_TIME, then settle back (item 2228).
const POP_SCALE: float = 1.15
const POP_UP_TIME: float = 0.06

## Screen shake as trauma (items 2253 to 2256): offset = trauma^2 * max, decays per second.
const TRAUMA_DECAY: float = 1.8
const SHAKE_MAX: Vector2i = Vector2i(3, 2)
const TRAUMA_HIT: float = 0.20
const TRAUMA_HIT_STRONG: float = 0.40
const TRAUMA_FAINT: float = 0.30
const TRAUMA_WARDEN: float = 0.55
## Shake follows smooth noise, sampled 30 times a second and stepping a short way along the
## noise each time, so it rolls instead of flickering (item 2261).
const SHAKE_NOISE_HZ: float = 30.0
const SHAKE_NOISE_STEP: float = 0.3

## Nudge: a 1 to 3 px push that springs back, 0.1 s in all (item 2235).
const NUDGE_OUT_TIME: float = 0.03
const NUDGE_BACK_TIME: float = 0.07
## Stagger: list entries fade in one after another (item 2237).
const STAGGER_GAP: float = 0.03
const STAGGER_FADE: float = 0.12
## Safe blink: brightness swings 100 % -> 60 % -> 100 %, at most 3 times a second (item 2238).
const BLINK_LOW: float = 0.6
const BLINK_PERIOD: float = 0.5
const BLINK_MIN_PERIOD: float = 1.0 / 3.0
## Wobble: at most 4 degrees either way (item 2239).
const WOBBLE_MAX_DEG: float = 4.0
## Settings levels for screen shake and vibration: Off, Weak (50 %), Full.
const LEVEL_NAMES: Array[String] = ["Off", "Weak", "Full"]
const LEVEL_SCALES: Array[float] = [0.0, 0.5, 1.0]

## Hit-stop (item 2257): 40 ms plus 60 ms times the share of HP lost, at most 100 ms.
const HITSTOP_BASE: float = 0.04
const HITSTOP_PER_HP: float = 0.06
const HITSTOP_MAX: float = 0.10
const HITSTOP_TIME_SCALE: float = 0.05

## True while a battle is on screen, so durations follow the 1x / 2x / 4x battle speed.
var in_battle: bool = false
var trauma: float = 0.0
var _shake_root: CanvasItem
var _shake_base: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _running: Dictionary = {}
var _hitstops: int = 0
## Element of the last hit that shook the screen, or -1 (item 2260).
var shake_element: int = -1
var _shake_time: float = 0.0
var _noise := FastNoiseLite.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = _rng.randi()

# --- Queries -----------------------------------------------------------------

## The only check for the reduce-motion setting (item 2231).
func reduced() -> bool:
	return GameState.reduce_motion

## Playback speed: the battle speed inside a battle, 1 everywhere else (item 2230).
func speed() -> float:
	return GameState.battle_speed_scale() if in_battle else 1.0

## Duration of [param curve] in seconds at the current speed, capped under reduced motion.
func duration(curve: String) -> float:
	var t: float = float((CURVES.get(curve, CURVES["move"]) as Dictionary).time) / speed()
	return minf(t, REDUCED_MAX_TIME) if reduced() else t

## Screen-shake strength from the settings (0, 0.5 or 1), 0 under reduced motion.
func shake_scale() -> float:
	if reduced():
		return 0.0
	return LEVEL_SCALES[clampi(GameState.screen_shake, 0, LEVEL_SCALES.size() - 1)]

# --- Tweens ------------------------------------------------------------------

## Tweens [param prop] of [param node] to [param value] along a named curve. Vector2 values are
## positions are rounded to whole pixels on every step (item 2229). A running tween on the same node and
## property is stopped first. [param time] overrides the curve's duration (still speed-scaled).
func tween(node: Node, prop: String, value: Variant, curve: String = "move", time: float = -1.0) -> Tween:
	var c: Dictionary = CURVES.get(curve, CURVES["move"])
	var dur: float = duration(curve) if time < 0.0 else time / speed()
	if reduced():
		dur = minf(dur, REDUCED_MAX_TIME)
	var key: String = "%d:%s" % [node.get_instance_id(), prop]
	var old: Variant = _running.get(key)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw: Tween = node.create_tween()
	_running[key] = tw
	tw.finished.connect(func() -> void: _running.erase(key))
	var from: Variant = node.get_indexed(prop)
	if value is Vector2 and (prop.begins_with("position") or prop == "offset"):
		tw.tween_method(func(v: Vector2) -> void: node.set_indexed(prop, v.round()), from, value, dur) \
			.set_trans(c.trans).set_ease(c.ease)
	else:
		tw.tween_property(node, prop, value, dur).set_trans(c.trans).set_ease(c.ease)
	return tw

## Gives a property or method tweener a named curve's transition and easing, keeping its own
## duration (item 2245): for tweens Juice.tween cannot build, such as fades on other nodes.
func shaped(tweener: Variant, curve: String = "move") -> Variant:
	var c: Dictionary = CURVES.get(curve, CURVES["move"])
	return tweener.set_trans(c.trans).set_ease(c.ease)

## Confirm bounce: scale 1.0 -> 1.15 in 0.06 s, then back with "settle". Awaitable.
func pop(node: Control) -> void:
	if node == null or reduced():
		return
	node.pivot_offset = node.size / 2.0
	await tween(node, "scale", Vector2.ONE * POP_SCALE, "impact", POP_UP_TIME).finished
	if is_instance_valid(node):
		await tween(node, "scale", Vector2.ONE, "settle").finished

## Counts a label's number from [param from] to [param to] (coins, growth), with a soft tick
## every tenth step (item 2236). [param fmt] gets the number through %d. Awaitable.
func count_to(label: Label, from: int, to: int, time: float = 0.5, fmt: String = "%d") -> void:
	if label == null:
		return
	if reduced() or from == to:
		label.text = fmt % to
		return
	var last: Array[int] = [from]
	var tw: Tween = label.create_tween()
	tw.tween_method(func(v: float) -> void:
		var n: int = roundi(v)
		if n != last[0]:
			if absi(n - from) % 10 == 0:
				Sound.sfx("tick")
			last[0] = n
		label.text = fmt % n, float(from), float(to), time / speed()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished

## Buttons pop when released (item 2415); the 1 px sink while held comes from the theme's
## "pressed" style (UITheme). Safe to call more than once.
func press_feedback(b: Control) -> void:
	if b == null or not b is BaseButton or b.has_meta("juice_press"):
		return
	b.set_meta("juice_press", true)
	(b as BaseButton).button_up.connect(func() -> void: pop(b))

## Short push of [param px] (1 to 3) pixels towards [param dir], springing back in 0.1 s
## (item 2235). Does nothing under reduced motion. Awaitable.
func nudge(node: CanvasItem, dir: Vector2, px: int = 2) -> void:
	if node == null or reduced() or dir == Vector2.ZERO:
		return
	var key: String = "nudge_home"
	if not node.has_meta(key):
		node.set_meta(key, node.get("position"))
	var home: Vector2 = node.get_meta(key)
	var to: Vector2 = home + (dir.normalized() * clampi(px, 1, 3)).round()
	await tween(node, "position", to, "impact", NUDGE_OUT_TIME).finished
	if is_instance_valid(node):
		await tween(node, "position", home, "settle", NUDGE_BACK_TIME).finished
	if is_instance_valid(node):
		node.remove_meta(key)

## Fades [param nodes] in one after another, [param gap] seconds apart (item 2237). Under
## reduced motion they all appear at once. Awaitable; returns when the last one is in.
func stagger(nodes: Array, gap: float = STAGGER_GAP) -> void:
	var last: Tween = null
	for i: int in nodes.size():
		var n: CanvasItem = nodes[i] as CanvasItem
		if n == null:
			continue
		if reduced():
			n.modulate.a = 1.0
			continue
		n.modulate.a = 0.0
		last = n.create_tween()
		last.tween_interval(i * gap / speed())
		last.tween_property(n, "modulate:a", 1.0, STAGGER_FADE / speed()) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if last != null:
		await last.finished

## Swings [param node]'s brightness between 100 % and 60 % instead of a hard on/off blink
## (item 2238), never faster than 3 times a second. Loops until [method stop_blink].
func blink_safe(node: CanvasItem, period: float = BLINK_PERIOD) -> Tween:
	if node == null:
		return null
	stop_blink(node)
	var half: float = maxf(period, BLINK_MIN_PERIOD) / 2.0
	var tw: Tween = node.create_tween().set_loops()
	tw.tween_property(node, "modulate", Color(BLINK_LOW, BLINK_LOW, BLINK_LOW, node.modulate.a), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "modulate", Color(1, 1, 1, node.modulate.a), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	node.set_meta("juice_blink", tw)
	return tw

## Stops a [method blink_safe] loop and restores full brightness.
func stop_blink(node: CanvasItem) -> void:
	if node == null or not node.has_meta("juice_blink"):
		return
	var tw: Variant = node.get_meta("juice_blink")
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	node.remove_meta("juice_blink")
	node.modulate = Color(1, 1, 1, node.modulate.a)

## Rocks [param node] by up to [param deg] degrees (at most 4) and back to rest in
## [param time] seconds, for hints such as a new gift (item 2239). Awaitable.
func wobble(node: CanvasItem, deg: float = WOBBLE_MAX_DEG, time: float = 0.5) -> void:
	if node == null or reduced():
		return
	var a: float = deg_to_rad(clampf(deg, 0.0, WOBBLE_MAX_DEG))
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size / 2.0
	var tw: Tween = node.create_tween()
	var step: float = time / speed() / 4.0
	for r: float in [a, -a, a * 0.5, 0.0]:
		tw.tween_property(node, "rotation", r, step).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

# --- Screen shake ------------------------------------------------------------

## Registers the node that shakes (never the UI layer). Pass null to clear it.
func set_shake_root(node: CanvasItem) -> void:
	_reset_shake()
	_shake_root = node
	_shake_base = node.get("position") if node != null else Vector2.ZERO
	trauma = 0.0

## Adds trauma (capped at 1). Ignored while shake is off or motion is reduced. [param element]
## (an Elements.E value) picks the shake direction (item 2260); -1 keeps both axes.
func add_trauma(amount: float, element: int = -1) -> void:
	if shake_scale() <= 0.0:
		return
	shake_element = element
	if in_battle and speed() >= 4.0:
		amount *= 0.6
	trauma = clampf(trauma + amount, 0.0, 1.0)

## Shake axes and speed for an element (item 2260): Stone only up and down, Gale only side to
## side, Volt twice as fast at half the reach, every other element on both axes.
## Returns [x weight, y weight, frequency factor].
static func shake_shape(element: int) -> Vector3:
	match element:
		Elements.E.STONE: return Vector3(0.0, 1.0, 1.0)
		Elements.E.GALE: return Vector3(1.0, 0.0, 1.0)
		Elements.E.VOLT: return Vector3(0.5, 0.5, 2.0)
	return Vector3(1.0, 1.0, 1.0)

## Current whole-pixel shake offset for [param t] trauma, read from smooth noise at
## [param at] seconds (defaults to the running shake clock).
func shake_offset(t: float, at: float = -1.0) -> Vector2:
	var k: float = t * t * shake_scale()
	var shape: Vector3 = shake_shape(shake_element)
	var p: float = floorf((_shake_time if at < 0.0 else at) * SHAKE_NOISE_HZ) * SHAKE_NOISE_STEP * shape.z
	var nx: float = clampf(_noise.get_noise_2d(p, 0.0) * 1.6, -1.0, 1.0)
	var ny: float = clampf(_noise.get_noise_2d(p, 57.0) * 1.6, -1.0, 1.0)
	return Vector2(roundi(SHAKE_MAX.x * k * shape.x * nx), roundi(SHAKE_MAX.y * k * shape.y * ny))

func _process(delta: float) -> void:
	if trauma <= 0.0:
		return
	# Decay in real time, so a hit-stop does not freeze the shake.
	var real: float = delta / maxf(Engine.time_scale, 0.0001)
	trauma = maxf(trauma - TRAUMA_DECAY * real, 0.0)
	_shake_time += real
	if not is_instance_valid(_shake_root):
		_shake_root = null
		return
	if trauma <= 0.0:
		_reset_shake()
		shake_element = -1
	else:
		_shake_root.set("position", _shake_base + shake_offset(trauma))

func _reset_shake() -> void:
	if is_instance_valid(_shake_root):
		_shake_root.set("position", _shake_base)

# --- Hit-stop ----------------------------------------------------------------

## Freeze length for a hit that took [param hp_share] (0..1) of the target's HP.
func hitstop_time(hp_share: float, fixed_time: float = -1.0) -> float:
	var t: float = minf(HITSTOP_BASE + HITSTOP_PER_HP * clampf(hp_share, 0.0, 1.0), HITSTOP_MAX)
	if fixed_time >= 0.0:
		t = fixed_time
	if in_battle and speed() >= 4.0:
		t = minf(t, 0.04)
	return t

## Briefly slows the game to 5 % (item 2257); [param fixed_time] overrides the length (item
## 2265). Does nothing under reduced motion. Awaitable.
func hitstop(hp_share: float, fixed_time: float = -1.0) -> void:
	if reduced() or not is_inside_tree():
		return
	var t: float = hitstop_time(hp_share, fixed_time)
	_hitstops += 1
	Engine.time_scale = HITSTOP_TIME_SCALE
	await get_tree().create_timer(t, true, false, true).timeout
	_hitstops -= 1
	if _hitstops <= 0:
		_hitstops = 0
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
