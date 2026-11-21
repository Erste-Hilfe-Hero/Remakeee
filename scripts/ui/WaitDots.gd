class_name WaitDots
extends CanvasLayer
## Three dots that hop one after another in the bottom right corner while a server call takes
## longer than 200 ms (item 2290), so a slow answer never looks like a frozen picture.
## Under reduced motion the dots stand still.

## Seconds a call may take before the dots show.
const SHOW_AFTER: float = 0.2
## One round of the three hops.
const PERIOD: float = 0.6
const DOT: int = 2
const GAP: int = 2
const HOP_PX: int = 2

## Server calls still waiting for an answer.
var pending: int = 0
var _waited: float = 0.0
var _time: float = 0.0
var _dots: Control

func _ready() -> void:
	layer = 119
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dots = Control.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dots.size = Vector2(3 * DOT + 2 * GAP + 4, DOT + HOP_PX + 4)
	_dots.position = Vector2(-_dots.size.x - 2, -_dots.size.y - 2)
	_dots.draw.connect(_draw_dots)
	_dots.visible = false
	_dots.accessibility_name = "Waiting for the server"
	add_child(_dots)

func begin() -> void:
	pending += 1

func end() -> void:
	pending = maxi(pending - 1, 0)
	if pending == 0:
		_waited = 0.0
		_dots.visible = false

func is_showing() -> bool:
	return _dots.visible

## How high dot [param i] hops at [param t] seconds: each dot hops for a third of the period.
static func hop(i: int, t: float, reduced: bool) -> int:
	if reduced:
		return 0
	return HOP_PX if int(fmod(t, PERIOD) / (PERIOD / 3.0)) == i else 0

func _process(delta: float) -> void:
	if pending <= 0:
		return
	_waited += delta
	_time += delta
	if _waited >= SHOW_AFTER and not _dots.visible:
		_dots.visible = true
	if _dots.visible:
		_dots.queue_redraw()

func _draw_dots() -> void:
	var reduced: bool = Juice.reduced()
	for i: int in 3:
		var y: float = 2 + HOP_PX - hop(i, _time, reduced)
		var r := Rect2(2 + i * (DOT + GAP), y, DOT, DOT)
		_dots.draw_rect(r.grow(1), UITheme.BG)
		_dots.draw_rect(r, UITheme.INK)
