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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()

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
	if value is Vector2 and prop.begins_with("position"):
		tw.tween_method(func(v: Vector2) -> void: node.set_indexed(prop, v.round()), from, value, dur) \
			.set_trans(c.trans).set_ease(c.ease)
	else:
		tw.tween_property(node, prop, value, dur).set_trans(c.trans).set_ease(c.ease)
	return tw

## Confirm bounce: scale 1.0 -> 1.15 in 0.06 s, then back with "settle". Awaitable.
func pop(node: Control) -> void:
	if node == null or reduced():
		return
	node.pivot_offset = node.size / 2.0
	await tween(node, "scale", Vector2.ONE * POP_SCALE, "impact", POP_UP_TIME).finished
	if is_instance_valid(node):
		await tween(node, "scale", Vector2.ONE, "settle").finished

# --- Screen shake ------------------------------------------------------------

## Registers the node that shakes (never the UI layer). Pass null to clear it.
func set_shake_root(node: CanvasItem) -> void:
	_reset_shake()
	_shake_root = node
	_shake_base = node.get("position") if node != null else Vector2.ZERO
	trauma = 0.0

## Adds trauma (capped at 1). Ignored while shake is off or motion is reduced.
func add_trauma(amount: float) -> void:
	if shake_scale() <= 0.0:
		return
	if in_battle and speed() >= 4.0:
		amount *= 0.6
	trauma = clampf(trauma + amount, 0.0, 1.0)

## Current whole-pixel shake offset for [param t] trauma.
func shake_offset(t: float) -> Vector2:
	var k: float = t * t * shake_scale()
	var x: int = roundi(SHAKE_MAX.x * k * _rng.randf_range(-1.0, 1.0))
	var y: int = roundi(SHAKE_MAX.y * k * _rng.randf_range(-1.0, 1.0))
	return Vector2(x, y)

func _process(delta: float) -> void:
	if trauma <= 0.0:
		return
	# Decay in real time, so a hit-stop does not freeze the shake.
	var real: float = delta / maxf(Engine.time_scale, 0.0001)
	trauma = maxf(trauma - TRAUMA_DECAY * real, 0.0)
	if not is_instance_valid(_shake_root):
		_shake_root = null
		return
	if trauma <= 0.0:
		_reset_shake()
	else:
		_shake_root.set("position", _shake_base + shake_offset(trauma))

func _reset_shake() -> void:
	if is_instance_valid(_shake_root):
		_shake_root.set("position", _shake_base)

# --- Hit-stop ----------------------------------------------------------------

## Freeze length for a hit that took [param hp_share] (0..1) of the target's HP.
func hitstop_time(hp_share: float) -> float:
	var t: float = minf(HITSTOP_BASE + HITSTOP_PER_HP * clampf(hp_share, 0.0, 1.0), HITSTOP_MAX)
	if in_battle and speed() >= 4.0:
		t = minf(t, 0.04)
	return t

## Briefly slows the game to 5 % (item 2257). Does nothing under reduced motion. Awaitable.
func hitstop(hp_share: float) -> void:
	if reduced() or not is_inside_tree():
		return
	var t: float = hitstop_time(hp_share)
	_hitstops += 1
	Engine.time_scale = HITSTOP_TIME_SCALE
	await get_tree().create_timer(t, true, false, true).timeout
	_hitstops -= 1
	if _hitstops <= 0:
		_hitstops = 0
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
