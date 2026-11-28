class_name TapMarker
extends Node2D
## Short mark on a tapped cell: a blinking frame where the Wayfarer walks to (item 1812), or a
## small X on a cell no way leads to (item 1813). Frees itself after [member life] seconds.

const BLINK: float = 0.1
var cross: bool = false
var life: float = 0.4
var _t: float = 0.0

func _ready() -> void:
	z_index = 50

func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	var on: bool = GameState.reduce_motion or int(_t / BLINK) % 2 == 0
	if visible != on:
		visible = on

func _draw() -> void:
	var t: float = float(GridWalker.TILE)
	if cross:
		var a := Vector2(5, 5)
		var b := Vector2(t - 5, t - 5)
		draw_line(a, b, UITheme.INK, 1.0)
		draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), UITheme.INK, 1.0)
	else:
		draw_rect(Rect2(Vector2(0.5, 0.5), Vector2(t - 1, t - 1)), UITheme.INK, false, 1.0)
