class_name TargetPin
extends Control
## A small cartographer's map pin that marks a Spirling in the formation layout: the one whose
## turn it is (hollow pin) or the foe being aimed at (filled pin). Drawn with primitives.
## A filled pin carries the aimed Spirling's element symbols beside it (KAMPF_PLAN_1000 item 91).

const SIZE: Vector2 = Vector2(7, 9)
## Width of one outlined element symbol (ElementIcons.outlined) plus a gap.
const ICON_STEP: int = ElementIcons.SIZE + 3

## Filled pin = aimed target; hollow pin = the Spirling choosing its action.
var filled: bool = true:
	set(v):
		filled = v
		_resize()
		queue_redraw()

## Elements of the Spirling the pin points at; shown only on a filled pin.
var elements: Array[int] = []:
	set(v):
		elements = v
		_resize()
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	visible = false

## The element symbols drawn beside the pin right now (none on a hollow pin).
func shown_elements() -> Array[int]:
	return elements if filled else ([] as Array[int])

func _resize() -> void:
	var n: int = shown_elements().size()
	size = Vector2(SIZE.x + n * ICON_STEP, maxf(SIZE.y, ElementIcons.SIZE + 2)) if n > 0 else SIZE

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
	# The aimed Spirling's element symbols, ink on a paper rim, right of the pin head.
	var x: float = SIZE.x + 1
	for e: int in shown_elements():
		draw_texture(ElementIcons.outlined(e), Vector2(x, -2))
		x += ICON_STEP
