class_name MiniStrip
extends Control
## Compact status tag under one Spirling in the formation layout (battles with several
## Spirlings per side): HP bar, Energy ticks and, on the player side, the HP numbers.
## The full InfoStrip at the top shows the details of whichever Spirling is in focus.

const WIDTH: int = 30
const BAR_HEIGHT: int = 3
const PIP: int = 2
const TWEEN_TIME: float = 0.4

## Show the current HP under the bar (player side; 30 px has no room for "hp/max").
var show_numbers: bool = false
## True for a Spirling of the ally Tamer: a small flag marks it.
var ally: bool = false
var display_hp: float = 1.0
var max_hp: int = 1
var energy: int = 0
var status: String = ""
var speed_scale: float = 1.0
var spirling_name: String = ""

## Height the strip needs for its options.
func needed_height() -> int:
	return BAR_HEIGHT + 2 + PIP + 1 + (get_theme_default_font_size() if show_numbers else 0)

func set_spirling(s: Spirling) -> void:
	spirling_name = s.display_name()
	max_hp = s.max_hp()
	display_hp = s.hp
	energy = s.energy
	status = s.status
	queue_redraw()

func animate_hp(hp: int, new_max: int = -1) -> void:
	if new_max > 0:
		max_hp = new_max
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void:
		display_hp = v
		queue_redraw(), display_hp, float(hp), TWEEN_TIME / speed_scale)
	await tw.finished

func set_energy(value: int) -> void:
	energy = value
	queue_redraw()

func set_status(value: String) -> void:
	status = value
	queue_redraw()

## What a screen reader says for this tag (item 77).
func screen_reader_text() -> String:
	return Loc.t("%s, HP %d of %d, Energy %d" % [spirling_name, int(round(display_hp)), max_hp, energy])

func _draw() -> void:
	accessibility_name = screen_reader_text()
	var w: float = size.x
	draw_rect(Rect2(-1, -1, w + 2, needed_height() + 2), UITheme.BG)
	var frac: float = clampf(display_hp / float(maxi(max_hp, 1)), 0.0, 1.0)
	var col: Color = InfoStrip.HP_HIGH if frac > 0.5 else (InfoStrip.HP_MID if frac > 0.2 else InfoStrip.HP_LOW)
	# A dashed frame instead of a solid one tells a status apart without colour.
	draw_rect(Rect2(0, 0, w, BAR_HEIGHT + 2), UITheme.INK, false, 1.0)
	if not status.is_empty():
		for x: int in range(1, int(w) - 1, 3):
			draw_rect(Rect2(x, 0, 1, 1), UITheme.BG)
	draw_rect(Rect2(1, 1, floorf((w - 2) * frac), BAR_HEIGHT), col)
	var y: float = BAR_HEIGHT + 3
	for i: int in Spirling.MAX_ENERGY:
		var r := Rect2(i * (PIP + 1), y, PIP, PIP)
		if i < energy:
			draw_rect(r, InfoStrip.ENERGY_ON)
		else:
			draw_rect(r, UITheme.MID)
	if ally:
		draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(-1, 2), Vector2(-4, 4)]), UITheme.INK)
	if show_numbers:
		var font: Font = get_theme_default_font()
		var fs: int = get_theme_default_font_size()
		draw_string(font, Vector2(0, y + PIP + fs), str(int(round(display_hp))), HORIZONTAL_ALIGNMENT_CENTER, w, fs, UITheme.INK)
