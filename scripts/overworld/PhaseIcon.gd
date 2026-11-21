class_name PhaseIcon
extends Control
## A tiny time-of-day symbol (area 3 item 1169): a sun at day, a half sun at dawn and dusk,
## a crescent moon at night. Drawn with UITheme colours.

var phase: int = DayCycle.Phase.DAY

func _ready() -> void:
	name = "phase_icon"
	position = Vector2(4, 3)
	custom_minimum_size = Vector2(7, 7)
	size = Vector2(7, 7)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c := Vector2(3.5, 3.5)
	match phase:
		DayCycle.Phase.NIGHT:
			draw_circle(c, 3.0, UITheme.ACCENT)
			draw_circle(c + Vector2(1.5, -1.0), 2.6, UITheme.BG)
		DayCycle.Phase.DAWN, DayCycle.Phase.DUSK:
			draw_circle(c + Vector2(0, 1), 3.0, UITheme.ACCENT)
			draw_rect(Rect2(0, 4.5, 7, 3), UITheme.BG)
			draw_line(Vector2(0, 4.5), Vector2(7, 4.5), UITheme.INK)
		_:
			draw_circle(c, 2.5, UITheme.ACCENT)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * 3.0, c + d * 3.6, UITheme.INK)
