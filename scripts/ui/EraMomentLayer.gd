class_name EraMomentLayer
extends CanvasLayer
## Base of the full-screen era moments (EraBoot, EraChangeScene, EraFinaleCard): a clock, one
## stage that the moment paints into, and one way to press on: a tap, click or the confirm or
## cancel button. Nothing here tweens; every picture is a function of the clock, so tests and
## frame strips can set any second and look at it.

signal finished

## Below the Era I ink filter (EraManager.FILTER_LAYER), above every menu.
const LAYER: int = 99
## Two presses closer together than this count as one (a held button repeats).
const PRESS_GAP_MS: int = 180

var t: float = 0.0
var reduced: bool = false
## Tests and frame strips drive the clock by hand.
var manual: bool = false
var stage: Control
var _last_press: int = -PRESS_GAP_MS
var _closed: bool = false

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	reduced = reduced or Juice.reduced()
	stage = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.theme = UITheme.get_theme()
	stage.draw.connect(func() -> void: paint(stage))
	add_child(stage)
	build()

func _process(delta: float) -> void:
	if not manual:
		advance(delta)

## Moves the clock on by [param delta] seconds and redraws.
func advance(delta: float) -> void:
	if _closed:
		return
	t += delta
	step()
	stage.queue_redraw()

func _input(event: InputEvent) -> void:
	if not (TapInput.is_press(event) or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	var now: int = Time.get_ticks_msec()
	if now - _last_press < PRESS_GAP_MS:
		return
	_last_press = now
	press()

## Ends the moment: emits finished once and frees the layer.
func close() -> void:
	if _closed:
		return
	_closed = true
	finished.emit()
	queue_free()

func is_closed() -> bool:
	return _closed

## 2 on the wide screens of Era IV and V, else 1: text and frames keep their share of the screen.
static func ui_scale(width: float) -> int:
	return 2 if width >= 250.0 else 1

## Children are built here (the stage exists).
func build() -> void:
	pass

## Called after the clock moved.
func step() -> void:
	pass

## Draws the moment at second t into [param ci].
func paint(_ci: Control) -> void:
	pass

## A press: skip ahead or close.
func press() -> void:
	close()
