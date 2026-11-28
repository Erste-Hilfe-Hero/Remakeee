extends Node
## Autoload "Juice": every game-feel helper in one place (plan area 6, items 2225 to 2259).
##   Juice.tween(node, "position", to, "move")   named curve, pixel-snapped, battle speed aware
##   Juice.pop(node)                              1.0 -> 1.15 -> 1.0 confirm bounce
##   Juice.add_trauma(Juice.TRAUMA_HIT)           screen shake on the registered ShakeRoot
##   await Juice.hitstop(0.4)                     short freeze after a hit (share of HP lost)
##   Juice.enter(panel, Vector2(0, 4))            arrives: fades in over the last few pixels
##   Juice.leave(panel)                           fades out without making anyone wait
## Every helper respects reduced motion through Juice.reduced(), the only place that reads it.
## Eras I and II move in steps (Juice.stepped()): fades in four hard levels, slides in 2 px.

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

## Eras up to this one show motion in steps, like their look (docs/FLOW.md).
const STEPPED_ERA_MAX: int = 2
## A stepped fade has this many levels above zero: 1/3, 2/3, full.
const STEP_LEVELS: int = 3
## A stepped slide moves this many pixels at a time.
const STEP_PX: int = 2
## Press squash (docs/FLOW.md): a held button is this much smaller, reached in SQUASH_TIME.
const SQUASH_SCALE: Vector2 = Vector2(0.97, 0.9)
const SQUASH_TIME: float = 0.05

## Pop: scale up in POP_UP_TIME, then settle back (item 2228).
const POP_SCALE: float = 1.15
const POP_UP_TIME: float = 0.06

## Screen shake as trauma (items 2253 to 2256): offset = trauma^2 * max, decays per second.
const TRAUMA_DECAY: float = 1.8
const SHAKE_MAX: Vector2i = Vector2i(3, 2)
## Shake values from this share of a pixel upward show as a whole pixel.
const SHAKE_PX_FROM: float = 0.15
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
var _shake_prop: String = "position"
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

## True while the active era shows motion in steps (Eras I and II) instead of smooth easing.
func stepped() -> bool:
	return EraManager.active_era() <= STEPPED_ERA_MAX

## [param a] on the nearest of the four fade levels of a stepped era.
static func step_alpha(a: float) -> float:
	return roundf(clampf(a, 0.0, 1.0) * STEP_LEVELS) / STEP_LEVELS

## [param v] on the 2 px grid of a stepped era.
static func step_px(v: Vector2) -> Vector2:
	return (v / STEP_PX).round() * STEP_PX

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
	if value is float and prop.ends_with(":a") and stepped():
		# Eras I and II fade in four hard levels; the last step lands on the exact value.
		tw.tween_method(func(v: float) -> void: node.set_indexed(prop, step_alpha(v)), from, value, dur) \
			.set_trans(c.trans).set_ease(c.ease)
		tw.tween_callback(func() -> void: node.set_indexed(prop, value))
	elif value is Vector2 and (prop.begins_with("position") or prop == "offset"):
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

## Lets [param node] arrive (docs/FLOW.md): it fades in from [param from_alpha] and, with
## [param from], slides the last pixels to where it stands now. Fire and forget: the node takes
## input from the first frame and nothing waits for the tween. Returns null under reduced
## motion or outside the tree, where the node is simply there. A second call, [method leave]
## or [method finish] ends a running arrival first.
func enter(node: CanvasItem, from: Vector2 = Vector2.ZERO, curve: String = "open", from_alpha: float = 0.0) -> Tween:
	if node == null:
		return null
	finish(node)
	node.modulate.a = 1.0
	if reduced() or not node.is_inside_tree():
		return null
	var slides: bool = from != Vector2.ZERO and not node.get_parent() is Container
	var hard: bool = stepped()
	var step := func(k: float) -> void:
		var a: float = lerpf(from_alpha, 1.0, clampf(k, 0.0, 1.0))
		node.modulate.a = step_alpha(a) if hard else a
		if slides:
			var off: Vector2 = from * (1.0 - k)
			_shift(node, step_px(off) if hard else off.round())
	step.call(0.0)
	return _flow(node, step, curve, {"hide": false, "free": false})

## Lets [param node] go: it fades out with "close" (sliding by [param to] if given), then is
## hidden, or freed with [param free]. Nobody waits for it; the node should already ignore
## input. Under reduced motion it is hidden or freed at once.
func leave(node: CanvasItem, to: Vector2 = Vector2.ZERO, free: bool = false) -> Tween:
	if node == null:
		return null
	finish(node)
	var end: Dictionary = {"hide": true, "free": free}
	if reduced() or not node.is_inside_tree() or not node.visible:
		_flow_end(node, end)
		return null
	var slides: bool = to != Vector2.ZERO and not node.get_parent() is Container
	var hard: bool = stepped()
	var a0: float = node.modulate.a
	var step := func(k: float) -> void:
		var a: float = a0 * (1.0 - k)
		node.modulate.a = step_alpha(a) if hard else a
		if slides:
			_shift(node, step_px(to * k) if hard else (to * k).round())
	return _flow(node, step, "close", end)

## Ends a running [method enter] or [method leave] of [param node] at once, in its end state
## (a press during a transition finishes it). Safe to call at any time.
func finish(node: CanvasItem) -> void:
	if node == null or not node.has_meta("flow_tween"):
		return
	var tw: Variant = node.get_meta("flow_tween")
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	_flow_done(node)

## How far [param node] stands from its place right now while it slides (zero at rest), for
## code that sets its offsets absolutely in the meantime.
func shift_of(node: CanvasItem) -> Vector2:
	return node.get_meta("flow_shift", Vector2.ZERO) if node != null else Vector2.ZERO

## True while [param node] is arriving or leaving.
func flowing(node: CanvasItem) -> bool:
	return node != null and node.has_meta("flow_tween")

func _flow(node: CanvasItem, step: Callable, curve: String, end: Dictionary) -> Tween:
	var c: Dictionary = CURVES.get(curve, CURVES["open"])
	var tw: Tween = node.create_tween()
	tw.tween_method(step, 0.0, 1.0, duration(curve)).set_trans(c.trans).set_ease(c.ease)
	tw.tween_callback(func() -> void: _flow_done(node))
	node.set_meta("flow_tween", tw)
	node.set_meta("flow_end", end)
	return tw

## Moves [param node] so that it stands [param off] pixels from its place, whatever it was
## shifted by before. A Control is moved through its four offsets, so its size and anchors
## stay as the layout set them; anything else through its position.
func _shift(node: CanvasItem, off: Vector2) -> void:
	var d: Vector2 = off - (node.get_meta("flow_shift", Vector2.ZERO) as Vector2)
	if d == Vector2.ZERO:
		return
	node.set_meta("flow_shift", off)
	if node is Control:
		var c: Control = node
		c.offset_left += d.x
		c.offset_right += d.x
		c.offset_top += d.y
		c.offset_bottom += d.y
	else:
		node.set("position", (node.get("position") as Vector2) + d)

func _flow_done(node: CanvasItem) -> void:
	if not is_instance_valid(node) or not node.has_meta("flow_end"):
		return
	var end: Dictionary = node.get_meta("flow_end")
	node.remove_meta("flow_tween")
	node.remove_meta("flow_end")
	_flow_end(node, end)

func _flow_end(node: CanvasItem, end: Dictionary) -> void:
	_shift(node, Vector2.ZERO)
	node.remove_meta("flow_shift")
	if bool(end.free):
		node.queue_free()
		return
	if bool(end.hide):
		node.visible = false
	node.modulate.a = 1.0

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

## Buttons squash a little while held and pop when released (item 2415, docs/FLOW.md); the
## 1 px sink while held comes from the theme's "pressed" style (UITheme). Eras I and II keep
## the sink alone while held, their buttons do not bend. Safe to call more than once.
func press_feedback(b: Control) -> void:
	if b == null or not b is BaseButton or b.has_meta("juice_press"):
		return
	b.set_meta("juice_press", true)
	(b as BaseButton).button_down.connect(func() -> void: squash(b))
	# A button hidden while held gets no release; it must not stay squashed.
	b.hidden.connect(func() -> void: b.scale = Vector2.ONE)
	(b as BaseButton).button_up.connect(func() -> void: pop(b))

## The held half of the press: [param node] shrinks to SQUASH_SCALE in 0.05 s. [method pop]
## springs it back. Nothing under reduced motion or in a stepped era.
func squash(node: Control) -> void:
	if node == null or reduced() or stepped():
		return
	node.pivot_offset = node.size / 2.0
	tween(node, "scale", SQUASH_SCALE, "impact", SQUASH_TIME)

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
		if stepped():
			last.tween_method(func(v: float) -> void: n.modulate.a = step_alpha(v), 0.0, 1.0, STAGGER_FADE / speed())
		else:
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

## Registers the node that shakes (never the UI layer). Pass null to clear it. [param prop]
## is the Vector2 property that moves: "position" for a battle field, "offset" for a camera.
func set_shake_root(node: CanvasItem, prop: String = "position") -> void:
	_reset_shake()
	_shake_root = node
	_shake_prop = prop
	_shake_base = node.get(prop) if node != null else Vector2.ZERO
	trauma = 0.0

## The node that shakes now, or null.
func shake_root() -> CanvasItem:
	return _shake_root if is_instance_valid(_shake_root) else null

## Stops any shake at once and puts the shaking node back (photo mode, item 2269).
func calm() -> void:
	trauma = 0.0
	shake_element = -1
	_reset_shake()

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
	return Vector2(_whole_px(SHAKE_MAX.x * k * shape.x * nx), _whole_px(SHAKE_MAX.y * k * shape.y * ny))

## Whole pixels for a shake value: rounded, except that anything from 0.15 px up to one pixel
## counts as one, so small trauma (a strong hit at 0.4, a Rift at 0.35) still shows a 1 px
## shake instead of rounding away.
static func _whole_px(v: float) -> float:
	var a: float = absf(v)
	if a < SHAKE_PX_FROM:
		return 0.0
	return signf(v) * maxf(1.0, roundf(a))

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
		_shake_root.set(_shake_prop, _shake_base + shake_offset(trauma))

func _reset_shake() -> void:
	if is_instance_valid(_shake_root):
		_shake_root.set(_shake_prop, _shake_base)

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
