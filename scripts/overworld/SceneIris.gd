class_name SceneIris
extends Control
## The iris of the cut-scenes (ScenePlayer step "iris"): black everywhere outside a circle around
## a point on screen. [member open] 1 shows everything, 0 is all black. Era I closes in four hard
## steps; with reduced motion the iris is a plain fade instead (the circle stays fully open and
## the black fades in), so nothing on screen shrinks or moves.

const ERA1_STEPS: float = 4.0

var center: Vector2 = Vector2.ZERO
var open: float = 1.0:
	set(v):
		open = clampf(v, 0.0, 1.0)
		queue_redraw()
var era: int = 1
var plain_fade: bool = false
var color: Color = UITheme.INK

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plain_fade = Juice.reduced()

## The drawn share of the opening: Era I in whole steps.
func shown_open() -> float:
	return floorf(open * ERA1_STEPS) / ERA1_STEPS if era <= 1 else open

## Radius of the hole in pixels.
func radius() -> float:
	var far: float = maxf(center.length(), (size - center).length())
	far = maxf(far, maxf(Vector2(size.x - center.x, center.y).length(), Vector2(center.x, size.y - center.y).length()))
	return far * shown_open()

func _draw() -> void:
	if plain_fade:
		if open < 1.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(color, 1.0 - open))
		return
	var o: float = shown_open()
	if o >= 1.0:
		return
	if o <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), color)
		return
	var rad: float = radius()
	var w: float = size.length() * 2.0
	draw_arc(center, rad + w / 2.0, 0.0, TAU, 64, color, w)
