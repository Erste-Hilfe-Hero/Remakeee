class_name RuleBanner
extends Control
## The Warden rule banner (item 679): a paper strip across the field with the rule's name and a
## small seal drawn with primitives. A plain rule shows a hollow diamond; the turning point shows
## a split diamond (half inked, half accent) so it reads as the rule changing sides.
## A rule variant (item 796) shows its own seal instead (BattleRules.VARIANT_SYMBOLS).

const HEIGHT: float = 14.0
const SEAL: float = 7.0

var turning: bool = false
## The variant seal to draw, "" for the Warden diamond.
var symbol: String = ""
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
## [param seal] is a variant's symbol, "" for a Warden rule.
func show_rule(title: String, is_turning: bool, width: float, y: float, seal: String = "") -> void:
	turning = is_turning
	symbol = seal if seal in BattleRules.VARIANT_SYMBOLS else ""
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
	if not symbol.is_empty():
		_draw_variant_seal(c, r)
		return
	var top := c + Vector2(0, -r)
	var right := c + Vector2(r, 0)
	var bottom := c + Vector2(0, r)
	var left := c + Vector2(-r, 0)
	if turning:
		draw_colored_polygon(PackedVector2Array([top, bottom, left]), UITheme.INK)
		draw_colored_polygon(PackedVector2Array([top, right, bottom]), UITheme.ACCENT)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), UITheme.INK, 1.0)

## The seal of variant [member symbol] around centre [param c], drawn with primitives only.
func _draw_variant_seal(c: Vector2, r: float) -> void:
	var ink: Color = UITheme.INK
	var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	match symbol:
		"spark":
			draw_polyline(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r * 0.3, -r * 0.1),
				c + Vector2(-r * 0.3, r * 0.1), c + Vector2(r, r)]), ink, 1.0)
		"full":
			draw_circle(c, r, ink)
		"toll":
			draw_rect(box, ink, false, 1.0)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), UITheme.ACCENT)
		"glass":
			draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r), c + Vector2(-r, r), c + Vector2(0, -r)]), ink, 1.0)
		"block":
			draw_rect(box, ink)
		"ring":
			draw_arc(c, r, 0.0, TAU, 12, ink, 1.0)
		"bars":
			draw_rect(Rect2(c + Vector2(-r, -r), Vector2(2, r * 2.0)), ink)
			draw_rect(Rect2(c + Vector2(r - 2.0, -r), Vector2(2, r * 2.0)), ink)
		"cross":
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), ink, 1.0)
			draw_line(c + Vector2(r, -r), c + Vector2(-r, r), ink, 1.0)
		"hourglass":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c]), ink)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(r, r), c + Vector2(-r, r)]), UITheme.ACCENT)
		"line":
			draw_rect(Rect2(c + Vector2(-r, -1), Vector2(r * 2.0, 2)), ink)
		"swirl":
			draw_arc(c, r, 0.0, TAU * 0.75, 10, ink, 1.0)
			draw_arc(c, r * 0.45, PI, TAU * 1.25, 6, UITheme.ACCENT, 1.0)
		"wedge":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, 0), c + Vector2(-r, r)]), ink)
		"drop":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, r * 0.2), c + Vector2(0, r),
				c + Vector2(-r * 0.7, r * 0.2)]), ink)
			draw_rect(Rect2(c + Vector2(-1, 0), Vector2(1, 1)), UITheme.ACCENT)
