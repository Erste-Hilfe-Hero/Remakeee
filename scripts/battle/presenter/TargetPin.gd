class_name TargetPin
extends Control
## A small cartographer's map pin that marks a Spirling in the formation layout: the one whose
## turn it is (hollow pin) or the foe being aimed at (filled pin). Drawn with primitives.

const SIZE: Vector2 = Vector2(7, 9)

## Filled pin = aimed target; hollow pin = the Spirling choosing its action.
var filled: bool = true:
	set(v):
		filled = v
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	visible = false

## Places the pin centred above [param target] (a rect in the parent's coordinates).
func point_at(target: Rect2) -> void:
	position = Vector2(roundf(target.position.x + (target.size.x - SIZE.x) / 2.0), target.position.y - SIZE.y - 1)
	visible = true

func _draw() -> void:
	var head := Rect2(0, 0, SIZE.x, 5)
	draw_rect(head, UITheme.INK)
	if not filled:
		draw_rect(Rect2(1, 1, SIZE.x - 2, 3), UITheme.BG)
	else:
		draw_rect(Rect2(2, 1, SIZE.x - 4, 2), UITheme.ACCENT)
	# The needle.
	draw_rect(Rect2(3, 5, 1, 4), UITheme.INK)
