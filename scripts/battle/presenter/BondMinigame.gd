class_name BondMinigame
extends Control
## Bond rhythm minigame: rings pulse inward and the player taps on the beat.
## run() is awaitable and returns a timing score 0..1. No odds or grades are shown while it
## runs (LEGAL.md: show the bond result only afterwards).

signal finished(score: float)

const RING_COLOR: Color = Color("20241c")
const TARGET_COLOR: Color = Color("7d8a6a")
const POP_TIME: float = 0.15

var _time: float = 0.0
var _running: bool = false
var _pending: Array[float] = []
## Active rings: spawn time.
var _rings: Array[float] = []
var _pops: Array[Vector2] = []  # (radius, age)
var _hits: Array[float] = []
var _strays: int = 0
var _pulse_count: int = 0
var _hint: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hint = Label.new()
	_hint.text = "Tap when the pulse meets the ring"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 4
	add_child(_hint)
	visible = false

func run() -> float:
	_time = 0.0
	_pending = BondTiming.pulse_times()
	_pulse_count = _pending.size()
	_rings.clear()
	_pops.clear()
	_hits.clear()
	_strays = 0
	_running = true
	visible = true
	var score: float = await finished
	visible = false
	return score

func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	while not _pending.is_empty() and _pending[0] <= _time:
		_rings.append(_pending.pop_front())
	# Rings that shrank past usefulness count as misses (score 0, already in the denominator).
	var keep: Array[float] = []
	for spawn: float in _rings:
		if BondTiming.radius_at(_time - spawn) > BondTiming.TARGET_RADIUS - BondTiming.TOLERANCE:
			keep.append(spawn)
	_rings = keep
	var pops: Array[Vector2] = []
	for p: Vector2 in _pops:
		if p.y + delta < POP_TIME:
			pops.append(Vector2(p.x, p.y + delta))
	_pops = pops
	queue_redraw()
	if _time >= BondTiming.DURATION and _rings.is_empty():
		_running = false
		finished.emit(BondTiming.final_score(_hits, _pulse_count, _strays))

func _tap() -> void:
	if not _running:
		return
	var best: int = -1
	var best_err: float = INF
	for i: int in _rings.size():
		var err: float = absf(BondTiming.radius_at(_time - _rings[i]) - BondTiming.TARGET_RADIUS)
		if err < best_err:
			best_err = err
			best = i
	if best >= 0 and best_err <= BondTiming.TOLERANCE:
		var r: float = BondTiming.radius_at(_time - _rings[best])
		_hits.append(BondTiming.tap_score(r))
		_pops.append(Vector2(r, 0.0))
		_rings.remove_at(best)
	else:
		_strays += 1

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		_tap()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if _running and event.is_action_pressed("ui_accept"):
		_tap()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var c: Vector2 = size / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(UITheme.BG, 0.85))
	draw_arc(c, BondTiming.TARGET_RADIUS, 0.0, TAU, 32, TARGET_COLOR, 2.0)
	for spawn: float in _rings:
		draw_arc(c, maxf(BondTiming.radius_at(_time - spawn), 1.0), 0.0, TAU, 40, RING_COLOR, 1.0)
	for p: Vector2 in _pops:
		draw_arc(c, p.x + p.y * 40.0, 0.0, TAU, 40, Color(RING_COLOR, 1.0 - p.y / POP_TIME), 1.0)
