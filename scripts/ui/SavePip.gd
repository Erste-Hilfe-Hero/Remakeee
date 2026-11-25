class_name SavePip
extends Control
## A small save mark in the lower right corner (200 list item 15): each quiet save
## (SaveManager.saved) shows it for a moment, so the player sees the game kept their progress.

const SIZE: int = 7
const SHOW_S: float = 1.2
const FADE_S: float = 0.3

var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -SIZE - 2
	offset_top = -SIZE - 2
	offset_right = -2
	offset_bottom = -2
	modulate.a = 0.0
	SaveManager.saved.connect(flash)

func flash() -> void:
	if _tween != null:
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(SHOW_S)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func is_showing() -> bool:
	return modulate.a > 0.0

func _draw() -> void:
	var ink: Color = UITheme.INK
	var paper: Color = UITheme.BG
	draw_rect(Rect2(0, 0, SIZE, SIZE), ink)
	draw_rect(Rect2(2, 0, 3, 2), paper)
	draw_rect(Rect2(1, 4, 5, 3), paper)
	draw_rect(Rect2(2, 5, 3, 1), ink)
