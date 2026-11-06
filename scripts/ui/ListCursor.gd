class_name ListCursor
extends Node2D
## The small marker ListPicker slides along the focused row's right end: a left-pointing
## 3-step wedge in paper colour, readable on the inverted (ink) focus row.

func _draw() -> void:
	draw_rect(Rect2(0, 2, 1, 1), UITheme.BG)
	draw_rect(Rect2(1, 1, 1, 3), UITheme.BG)
	draw_rect(Rect2(2, 0, 2, 5), UITheme.BG)
