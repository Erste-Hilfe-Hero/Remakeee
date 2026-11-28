class_name OfflineMark
extends CanvasLayer
## The small "offline" mark while playing without a connection (docs/OFFLINE.md). Chimora plays
## on offline: this never pauses or dims the game and takes no taps. It sits at the top centre
## under the safe area (in a corner it covered every list's Back button, Chimora 100 item 56),
## shows after SHOW_AFTER seconds without connection, so a short drop does not flicker it, and
## fades out once Online is back.

## Seconds without connection before the mark shows.
const SHOW_AFTER: float = 3.0
## The mark fades in and out in 0.2 s (item 2291).
const FADE_TIME: float = 0.2
## Size of the mark in view pixels: three signal bars with a stroke through them.
const MARK_SIZE: Vector2 = Vector2(13, 9)
## How strongly the mark shows; it should not pull the eye from the game.
const MARK_ALPHA: float = 0.85

var mark: Control
var _closing: bool = false

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mark = Control.new()
	mark.name = "offline_mark"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mark.offset_left = -MARK_SIZE.x / 2.0
	mark.offset_right = MARK_SIZE.x / 2.0
	mark.offset_bottom = MARK_SIZE.y
	mark.custom_minimum_size = MARK_SIZE
	mark.accessibility_name = "Offline. Your journey is saved on this phone."
	mark.draw.connect(_draw_mark)
	mark.modulate.a = 0.0
	add_child(mark)

## Paper box, three bars rising from left to right, a stroke from top left to bottom right.
func _draw_mark() -> void:
	var r := Rect2(Vector2.ZERO, MARK_SIZE)
	mark.draw_rect(r, UITheme.BG)
	mark.draw_rect(r.grow(-0.5), UITheme.INK, false, 1.0)
	for i: int in 3:
		var h: float = 2.0 + 2.0 * i
		mark.draw_rect(Rect2(3.0 + 3.0 * i, MARK_SIZE.y - 2.0 - h, 2.0, h), Color(UITheme.INK, 0.45))
	mark.draw_line(Vector2(2, 2), Vector2(MARK_SIZE.x - 2, MARK_SIZE.y - 2), UITheme.INK, 1.0)

## Called by Online every frame without a connection while playing.
func update_view(offline_for: float) -> void:
	if offline_for < SHOW_AFTER:
		return
	if mark.is_inside_tree():
		mark.offset_top = SafeArea.rect(mark.get_viewport().get_visible_rect().size).position.y
		mark.offset_bottom = mark.offset_top + MARK_SIZE.y
	if visible and not _closing:
		return
	_closing = false
	visible = true
	mark.modulate.a = 0.0
	Juice.tween(mark, "modulate:a", MARK_ALPHA, "fade", FADE_TIME)

func is_shown() -> bool:
	return visible and not _closing

func hide_mark() -> void:
	# Online calls this every frame while connected; one fade-out at a time.
	if not visible or _closing:
		return
	_closing = true
	await Juice.tween(mark, "modulate:a", 0.0, "fade", FADE_TIME).finished
	# Lost again while fading out: the mark stays.
	if not _closing:
		return
	_closing = false
	visible = false
