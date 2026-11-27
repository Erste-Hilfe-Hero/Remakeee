class_name FirstArtArrow
extends Control
## The very first battle only (200 list item 11): when the player taps nothing for IDLE_SECONDS
## while the orders are open, an arrow points at the first art button. Any tap or key hides it
## and starts the wait again. No timer is shown (no countdown pressure).

const IDLE_SECONDS: float = 5.0
## Arrow size (length of the head, width) and how far it bobs.
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

## Where the arrow's tip sits: just after the art's name on [param b], halfway down the row.
static func tip_for(b: Control, rect: Rect2) -> Vector2:
	var x: float = rect.size.x * 0.5
	var btn := b as Button
	if btn != null:
		var font: Font = btn.get_theme_font("font")
		var fs: int = btn.get_theme_font_size("font_size")
		var sb: StyleBox = btn.get_theme_stylebox("normal")
		var left: float = sb.content_margin_left if sb != null else 0.0
		var icon_w: float = float(btn.icon.get_width()) + 2.0 if btn.icon != null else 0.0
		var line: String = btn.text.get_slice("\n", 0)
		x = left + icon_w + font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 3.0
	return Vector2(rect.position.x + minf(x, rect.size.x * 0.6), rect.position.y + rect.size.y * 0.5)

func _draw() -> void:
	if target == null:
		return
	var r: Rect2 = Rect2(target.global_position - global_position, target.size)
	var bob: float = 0.0 if GameState.reduce_motion else roundf(sin(_t * TAU) * BOB)
	var tip: Vector2 = tip_for(target, r) + Vector2(bob, 0)
	var w: float = SIZE.x
	var h: float = SIZE.y
	# Pointing left at the art's name: head, then the shaft to the right.
	var pts := PackedVector2Array([tip, tip + Vector2(h, -w * 0.5), tip + Vector2(h, -w * 0.2),
		tip + Vector2(h * 2.2, -w * 0.2), tip + Vector2(h * 2.2, w * 0.2), tip + Vector2(h, w * 0.2), tip + Vector2(h, w * 0.5)])
	draw_colored_polygon(pts, UITheme.INK)
	pts.append(tip)
	draw_polyline(pts, UITheme.ACCENT, 1.0)
