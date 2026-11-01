class_name BondMinigame
extends Control
## Bond minigame "Echo call": the wild Spirling calls a short sequence on three marks
## (diamond, square, triangle), then the player taps the same marks in the same order.
## run() is awaitable and returns a score 0..1. No odds or grades are shown while it runs
## (LEGAL.md: show the bond result only afterwards). Rules live in BondEcho.

signal finished(score: float)

enum Phase { IDLE, CALL, ECHO }

const MARK_SIZE: float = 26.0
const FLASH_TIME: float = 0.18
const TARGET_SIZE: float = 40.0

## The wild Spirling being reached out to, drawn above the marks.
var target: Texture2D
## Set for reproducible calls (tests, screenshots); otherwise randomized per run.
var rng: RandomNumberGenerator

var _phase: Phase = Phase.IDLE
var _time: float = 0.0
var _sequence: Array[int] = []
var _taps: Array[int] = []
var _flash_mark: int = -1
var _flash_left: float = 0.0
var _hint: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 4
	add_child(_hint)
	visible = false

func run() -> float:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_sequence = BondEcho.make_sequence(rng)
	_taps.clear()
	_flash_mark = -1
	_time = 0.0
	_phase = Phase.CALL
	_hint.text = "Listen to the call..."
	visible = true
	var result: float = await finished
	visible = false
	return result

func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_time += delta
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _phase == Phase.CALL and _time >= BondEcho.call_duration() + BondEcho.GAP_TIME:
		_phase = Phase.ECHO
		_time = 0.0
		_hint.text = "Now echo it back!"
	elif _phase == Phase.ECHO and _time >= BondEcho.ECHO_TIME:
		_finish()
	queue_redraw()

func _tap(mark: int) -> void:
	if _phase != Phase.ECHO or mark < 0:
		return
	_taps.append(mark)
	_flash_mark = mark
	_flash_left = FLASH_TIME
	if not BondEcho.is_on_track(_sequence, _taps) or _taps.size() >= _sequence.size():
		_finish()

func _finish() -> void:
	if _phase == Phase.IDLE:
		return
	_phase = Phase.IDLE
	finished.emit(BondEcho.score(_sequence, _taps))

## Centre of mark [param i] (three marks in a row, lower half of the screen).
func _mark_center(i: int) -> Vector2:
	var step: float = size.x / float(BondEcho.MARKS + 1)
	return Vector2(step * (i + 1), size.y * 0.62)

func _mark_at_point(p: Vector2) -> int:
	for i: int in BondEcho.MARKS:
		if p.distance_to(_mark_center(i)) <= MARK_SIZE * 0.75:
			return i
	return -1

func _gui_input(event: InputEvent) -> void:
	var pos: Variant = null
	if event is InputEventScreenTouch and event.pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	if pos != null:
		_tap(_mark_at_point(pos))
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.ECHO:
		return
	var mark: int = -1
	if event.is_action_pressed("ui_left"):
		mark = 0
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_up"):
		mark = 1
	elif event.is_action_pressed("ui_right"):
		mark = 2
	if mark >= 0:
		_tap(mark)
		get_viewport().set_input_as_handled()

func _lit_mark() -> int:
	if _phase == Phase.CALL:
		return BondEcho.mark_at(_sequence, _time)
	if _flash_left > 0.0:
		return _flash_mark
	return -1

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UITheme.BG, 0.9))
	if target != null:
		var half := Vector2(TARGET_SIZE, TARGET_SIZE) / 2.0
		var at := Vector2(size.x / 2.0, size.y * 0.3)
		draw_texture_rect(target, Rect2((at - half).round(), half * 2.0), false)
	var lit: int = _lit_mark()
	for i: int in BondEcho.MARKS:
		_draw_mark(i, _mark_center(i).round(), i == lit)
	# Progress pips for the echo (how many taps so far), never odds.
	if _phase == Phase.ECHO:
		var y: float = size.y * 0.62 + MARK_SIZE
		var x0: float = size.x / 2.0 - (BondEcho.SEQUENCE_LENGTH * 6) / 2.0
		for i: int in BondEcho.SEQUENCE_LENGTH:
			var filled: bool = i < _taps.size()
			draw_rect(Rect2(x0 + i * 6, y, 4, 4), UITheme.INK if filled else UITheme.DISABLED, filled)

func _draw_mark(i: int, c: Vector2, lit: bool) -> void:
	var r: float = MARK_SIZE / 2.0
	var fill: Color = UITheme.INK if lit else UITheme.ACCENT
	var pts := PackedVector2Array()
	match i:
		0:  # diamond
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		1:  # square
			var s: float = r * 0.8
			pts = PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, s), c + Vector2(-s, s)])
		_:  # triangle
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)])
	draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, UITheme.INK, 1.0)
