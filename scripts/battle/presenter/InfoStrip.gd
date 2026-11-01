class_name InfoStrip
extends Control
## Slim edge-anchored status strip: name, level, status tag, HP bar and Energy pips.
## Drawn with primitives (no boxed "battle panel").

const BAR_HEIGHT: int = 3
const PIP_SIZE: int = 3
const PIP_GAP: int = 1
const HP_HIGH: Color = Color("5aa65a")
const HP_MID: Color = Color("d9b13b")
const HP_LOW: Color = Color("c8513a")
const ENERGY_ON: Color = Color("3b6fd9")
const TWEEN_TIME: float = 0.4
const TICK_STEP: int = 8
## Paper tag drawn behind the strip so it stays readable on any backdrop.
const PLATE_PAD: Vector2 = Vector2(3, 2)

## Show the numeric HP (player side only).
@export var show_numbers: bool = false

var display_hp: float = 1.0
var max_hp: int = 1
var energy: int = 0
var spirling_name: String = ""
var level: int = 1
var status: String = ""
var speed_scale: float = 1.0

func set_spirling(s: Spirling) -> void:
	spirling_name = s.display_name()
	level = s.level
	max_hp = s.max_hp()
	display_hp = s.hp
	energy = s.energy
	status = s.status
	queue_redraw()

## Tweens the bar to [param hp]. Awaitable.
func animate_hp(hp: int, new_max: int = -1) -> void:
	if new_max > 0:
		max_hp = new_max
	var tw: Tween = create_tween()
	tw.tween_method(_set_display_hp, display_hp, float(hp), TWEEN_TIME / speed_scale)
	await tw.finished

func set_energy(value: int) -> void:
	energy = value
	queue_redraw()

func set_status(value: String) -> void:
	status = value
	queue_redraw()

func set_level(value: int) -> void:
	level = value
	queue_redraw()

func _set_display_hp(v: float) -> void:
	display_hp = v
	queue_redraw()

func _draw() -> void:
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var w: float = size.x
	var y_text: float = float(fs)
	_draw_plate()
	draw_string(font, Vector2(0, y_text), spirling_name, HORIZONTAL_ALIGNMENT_LEFT, w * 0.6, fs, UITheme.INK)
	var right: String = "Lv%d" % level
	if not status.is_empty():
		right = StatusRules.label(status).substr(0, 3).to_upper() + " " + right
	draw_string(font, Vector2(0, y_text), right, HORIZONTAL_ALIGNMENT_RIGHT, w, fs, UITheme.INK)
	var bar_y: float = y_text + 3.0
	var frac: float = clampf(display_hp / float(maxi(max_hp, 1)), 0.0, 1.0)
	var col: Color = HP_HIGH if frac > 0.5 else (HP_MID if frac > 0.2 else HP_LOW)
	draw_rect(Rect2(0, bar_y, w, BAR_HEIGHT + 2), UITheme.INK)
	draw_rect(Rect2(1, bar_y + 1, w - 2, BAR_HEIGHT), UITheme.BG)
	draw_rect(Rect2(1, bar_y + 1, floorf((w - 2) * frac), BAR_HEIGHT), col)
	# Notches every few pixels make the bar read as a measured scale, like a map ruler.
	for x: int in range(TICK_STEP, int(w) - 1, TICK_STEP):
		draw_rect(Rect2(x, bar_y + 1, 1, 1), UITheme.INK)
	var pip_y: float = bar_y + BAR_HEIGHT + 4.0
	for i: int in Spirling.MAX_ENERGY:
		var r := Rect2(i * (PIP_SIZE + PIP_GAP), pip_y, PIP_SIZE, PIP_SIZE)
		if i < energy:
			draw_rect(r, ENERGY_ON)
		else:
			draw_rect(r, UITheme.MID, false, 1.0)
	if show_numbers:
		draw_string(font, Vector2(0, pip_y + PIP_SIZE + fs - 1), "%d/%d" % [int(round(display_hp)), max_hp], HORIZONTAL_ALIGNMENT_RIGHT, w, fs, UITheme.INK)

func _draw_plate() -> void:
	var r := Rect2(-PLATE_PAD, size + PLATE_PAD * 2.0)
	draw_rect(r, UITheme.BG)
	draw_rect(r, UITheme.INK, false, 1.0)
	# Notched corners, same language as the map-sheet frames.
	for c: Vector2 in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2.ONE]:
		draw_rect(Rect2(c, Vector2.ONE), UITheme.BG)
