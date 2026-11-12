class_name TripScene
extends Control
## The short trip between two stops (area 3 items 1188, 1189): a rowing boat on the lake or a
## coach on the valley road slides across a paper-coloured strip while the world is faded out.
## The player sits inside; nothing carries them. Drawn with UITheme colours only (area 6 brings
## the real look). With "Less motion" on the picture stands still and the trip is shorter.

const SECONDS: float = 1.6
const STILL_SECONDS: float = 0.8
const STRIP_H: float = 64.0

var kind: String = "boat"
var text: String = ""
## 0 = start of the trip, 1 = arrived. Drives the drawing.
var progress: float = 0.0
var _label: Label

func _init(k: String = "boat", line: String = "") -> void:
	kind = k
	text = line

func _ready() -> void:
	name = "trip"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", UITheme.BG)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_left = -140.0
	_label.offset_right = 140.0
	_label.offset_top = -44.0
	_label.offset_bottom = -12.0
	add_child(_label)

## Plays the trip and returns when it is over.
func run() -> void:
	if GameState.reduce_motion:
		progress = 0.5
		queue_redraw()
		await get_tree().create_timer(STILL_SECONDS).timeout
		return
	var tw: Tween = create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, SECONDS)
	await tw.finished

func _set_progress(p: float) -> void:
	progress = p
	queue_redraw()

## Left edge of the vehicle for the current progress.
func vehicle_x() -> float:
	return lerpf(-60.0, size.x + 10.0, progress)

func _draw() -> void:
	var mid: float = size.y * 0.5
	var top: float = mid - STRIP_H * 0.5
	draw_rect(Rect2(0, 0, size.x, size.y), UITheme.INK)
	draw_rect(Rect2(0, top, size.x, STRIP_H), UITheme.BG)
	var x: float = vehicle_x()
	if kind == "coach" or kind == "rail" or kind == "rope":
		_draw_coach(x, top + STRIP_H - 14.0)
	else:
		_draw_boat(x, top + STRIP_H - 22.0)

## A rowing boat on wavy water, a seated figure and an oar.
func _draw_boat(x: float, water: float) -> void:
	for i: int in int(size.x / 12.0) + 1:
		var wx: float = fmod(i * 12.0 + progress * 24.0, size.x + 12.0) - 6.0
		draw_line(Vector2(wx, water + 6.0), Vector2(wx + 6.0, water + 4.0), UITheme.MID, 1.0)
	var hull := PackedVector2Array([Vector2(x, water - 6.0), Vector2(x + 48.0, water - 6.0),
		Vector2(x + 40.0, water + 2.0), Vector2(x + 8.0, water + 2.0)])
	draw_colored_polygon(hull, UITheme.MID)
	# The player sitting in the boat, and the rower in front.
	draw_rect(Rect2(x + 14.0, water - 16.0, 6.0, 10.0), UITheme.INK)
	draw_circle(Vector2(x + 17.0, water - 19.0), 3.0, UITheme.INK)
	draw_rect(Rect2(x + 30.0, water - 16.0, 6.0, 10.0), UITheme.INK)
	draw_circle(Vector2(x + 33.0, water - 19.0), 3.0, UITheme.INK)
	var sway: float = sin(progress * TAU * 3.0) * 4.0
	draw_line(Vector2(x + 34.0, water - 10.0), Vector2(x + 50.0 + sway, water + 6.0), UITheme.INK, 2.0)

## A box coach on two wheels with the driver up front, on a road.
func _draw_coach(x: float, road: float) -> void:
	draw_line(Vector2(0, road + 8.0), Vector2(size.x, road + 8.0), UITheme.MID, 2.0)
	draw_rect(Rect2(x, road - 24.0, 40.0, 20.0), UITheme.MID)
	draw_rect(Rect2(x + 6.0, road - 20.0, 10.0, 8.0), UITheme.ACCENT)
	draw_rect(Rect2(x + 22.0, road - 20.0, 10.0, 8.0), UITheme.ACCENT)
	# The player looks out of the back window.
	draw_circle(Vector2(x + 11.0, road - 15.0), 2.5, UITheme.INK)
	var turn: float = progress * TAU * 4.0
	for wx: float in [x + 8.0, x + 32.0]:
		draw_circle(Vector2(wx, road), 5.0, UITheme.INK)
		draw_line(Vector2(wx, road), Vector2(wx + cos(turn) * 4.0, road + sin(turn) * 4.0), UITheme.BG, 1.0)
	# Driver on the box seat.
	draw_rect(Rect2(x + 42.0, road - 30.0, 6.0, 10.0), UITheme.INK)
	draw_circle(Vector2(x + 45.0, road - 33.0), 3.0, UITheme.INK)
