class_name RuleBanner
extends Control
## The Warden rule banner (item 679): a paper strip across the field with the rule's name and a
## small seal drawn with primitives. A plain rule shows a hollow diamond; the turning point shows
## a split diamond (half inked, half accent) so it reads as the rule changing sides.

const HEIGHT: float = 14.0
const SEAL: float = 7.0

var turning: bool = false
var _label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE)
	_label.add_theme_color_override("font_color", UITheme.INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

## Shows [param title] across [param width] at height [param y] of the parent.
func show_rule(title: String, is_turning: bool, width: float, y: float) -> void:
	turning = is_turning
	_label.text = title
	size = Vector2(width, HEIGHT)
	position = Vector2(0, roundf(y))
	_label.position = Vector2(SEAL + 6, 0)
	_label.size = Vector2(width - (SEAL + 6) * 2, HEIGHT)
	visible = true
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.BG)
	draw_rect(Rect2(0, 0, size.x, 1), UITheme.INK)
	draw_rect(Rect2(0, size.y - 1, size.x, 1), UITheme.INK)
	for x: float in [4.0, size.x - 4.0 - SEAL]:
		_draw_seal(Vector2(x, (size.y - SEAL) / 2.0))

func _draw_seal(at: Vector2) -> void:
	var c: Vector2 = at + Vector2(SEAL, SEAL) / 2.0
	var r: float = SEAL / 2.0
	var top := c + Vector2(0, -r)
	var right := c + Vector2(r, 0)
	var bottom := c + Vector2(0, r)
	var left := c + Vector2(-r, 0)
	if turning:
		draw_colored_polygon(PackedVector2Array([top, bottom, left]), UITheme.INK)
		draw_colored_polygon(PackedVector2Array([top, right, bottom]), UITheme.ACCENT)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), UITheme.INK, 1.0)
