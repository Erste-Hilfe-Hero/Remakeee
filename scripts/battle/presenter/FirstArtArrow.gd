class_name FirstArtArrow
extends Control
## The very first battle only (200 list item 11): when the player taps nothing for IDLE_SECONDS
## while the orders are open, an arrow points at the first art button. Any tap or key hides it
## and starts the wait again. No timer is shown (no countdown pressure).

const IDLE_SECONDS: float = 5.0
## Arrow size at UI scale 1 and how far it bobs.
const SIZE: Vector2 = Vector2(10, 8)
const BOB: float = 2.0

## The button the arrow points at (set by the battle each time the orders open).
var target: Control
var _idle: float = 0.0
var _waiting: bool = false
var _t: float = 0.0

## True when no Spirling of [param spirlog] has travelled a battle yet: the very first battle.
static func is_first_battle(spirlog: Dictionary) -> bool:
	for e: Variant in spirlog.values():
		if e is Dictionary and GameState.as_int((e as Dictionary).get("battles", 0)) > 0:
			return false
	return true

func _ready() -> void:
	name = "first_art_arrow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

## Starts waiting for the player to choose; the arrow shows after IDLE_SECONDS without input.
func wait_for(button: Control) -> void:
	target = button
	_waiting = button != null
	_idle = 0.0
	visible = false

## The orders were given: no arrow until the next wait.
func stop() -> void:
	_waiting = false
	visible = false

## Seconds without input so far (for tests).
func idle_time() -> float:
	return _idle

## Advances the wait by [param delta] seconds; shows the arrow once IDLE_SECONDS have passed.
func tick(delta: float) -> void:
	if not _waiting:
		return
	_idle += delta
	_t += delta
	visible = _idle >= IDLE_SECONDS and target != null and target.is_visible_in_tree()
	if visible:
		queue_redraw()

func _process(delta: float) -> void:
	tick(delta)

func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_idle = 0.0
		visible = false

func _draw() -> void:
	if target == null:
		return
	var k: float = maxf(1.0, target.get_global_transform().get_scale().x)
	var r: Rect2 = Rect2(target.global_position - global_position, target.size * k)
	var bob: float = 0.0 if GameState.reduce_motion else roundf(sin(_t * TAU) * BOB) * k
	var tip: Vector2 = Vector2(r.position.x + minf(r.size.x * 0.5, 40.0 * k), r.position.y - 1.0 * k + bob)
	var w: float = SIZE.x * k
	var h: float = SIZE.y * k
	var pts := PackedVector2Array([tip, tip + Vector2(-w * 0.5, -h), tip + Vector2(-w * 0.2, -h),
		tip + Vector2(-w * 0.2, -h * 1.8), tip + Vector2(w * 0.2, -h * 1.8), tip + Vector2(w * 0.2, -h), tip + Vector2(w * 0.5, -h)])
	draw_colored_polygon(pts, UITheme.ACCENT)
	pts.append(tip)
	draw_polyline(pts, UITheme.INK, maxf(1.0, k))
