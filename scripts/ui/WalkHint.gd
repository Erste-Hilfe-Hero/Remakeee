class_name WalkHint
extends Control
## "Walk: D-pad or tap a tile" with an arrow down to the D-pad, for the first free steps after
## the prologue (plan item 1982). The overworld removes it after [constant STEPS] steps.

const STEPS: int = 3
const ARROW: int = 5

var text: String = ""
var _label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.text = text
	_label.add_theme_stylebox_override("normal", UITheme.panel_style())
	_label.accessibility_live = AccessibilityServer.LIVE_POLITE
	add_child(_label)
	_place.call_deferred()

func _place() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var w: float = _label.get_combined_minimum_size().x
	var pad: Rect2 = VirtualPad.dpad_rect() if VirtualPad.top_y() >= 0.0 else Rect2()
	if pad.has_area():
		# Above the D-pad, kept on screen.
		var x: float = clampf(pad.get_center().x - w / 2.0, 4.0, vp.x - 4.0 - w)
		_label.position = Vector2(x, pad.position.y - ARROW - 2 - _label.get_combined_minimum_size().y)
	else:
		_label.position = Vector2((vp.x - w) / 2.0, vp.y * 0.6)
	queue_redraw()

## Where the arrow points (viewport pixels), or NAN when no pad shows.
func arrow_tip() -> Vector2:
	if VirtualPad.top_y() < 0.0:
		return Vector2(NAN, NAN)
	var pad: Rect2 = VirtualPad.dpad_rect()
	return Vector2(pad.get_center().x, pad.position.y - 1)

func _draw() -> void:
	var tip: Vector2 = arrow_tip()
	if is_nan(tip.x):
		return
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-ARROW, -ARROW), tip + Vector2(ARROW, -ARROW)]), UITheme.INK)
