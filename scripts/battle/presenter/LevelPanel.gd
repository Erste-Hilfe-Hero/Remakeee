class_name LevelPanel
extends Control
## Ring-rise panel: the five stats of a Spirling that grew a ring. Era I a plain list of the
## new values and the gain, Era II the gain in colour, from Era III a small bar per stat with
## the gain as a lighter end, from Era IV the numbers count up and the bars grow (not under
## reduced motion). Rules live nowhere here: the rows come from EraBattleHud.stat_rows.

const PAD: int = EraBattleHud.FRAME_PAD
const BAR_W: int = 30
const COUNT_TIME: float = 0.5

var era: int = 1
var rows: Array[Dictionary] = []
var spirling_name: String = ""
var from_level: int = 1
var to_level: int = 2
## The panel never grows wider than this (the command panel it stands in).
var max_width: float = 1000.0
## 0..1: how far the numbers have counted up.
var progress: float = 1.0
var _tween: Tween

## Shows the panel for [param s] growing from ring [param p_from] to [param p_to].
func show_rise(s: Spirling, p_from: int, p_to: int) -> void:
	era = EraManager.active_era()
	rows = EraBattleHud.stat_rows(s, p_from, p_to)
	spirling_name = s.display_name()
	from_level = p_from
	to_level = p_to
	size = needed_size()
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	progress = 1.0
	if counts(era, Juice.reduced()) and is_inside_tree():
		progress = 0.0
		_tween = create_tween()
		Juice.shaped(_tween.tween_method(_set_progress, 0.0, 1.0, COUNT_TIME / Juice.speed()), "move")
	queue_redraw()

static func counts(p_era: int, reduced: bool) -> bool:
	return not reduced and EraBattleHud.flag(p_era, "level_count")

func _set_progress(v: float) -> void:
	progress = v
	queue_redraw()

func _font() -> Font:
	return EraBattleHud.font(era)

func _text_w(t: String) -> float:
	return _font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x

func _label_w() -> float:
	var w: float = 0.0
	for r: Dictionary in rows:
		w = maxf(w, _text_w(Loc.t(str(r.label))))
	return w

func bars() -> bool:
	return EraBattleHud.text(era, "level_panel", "list") == "bars"

func title() -> String:
	return "%s R%d > R%d" % [spirling_name, from_level, to_level]

## Size the panel needs for its rows in the era's font.
func needed_size() -> Vector2:
	var lh: int = EraBattleHud.line_h(era) + 1
	var w: float = _label_w() + 4.0 + _value_w() + 3.0 + _text_w("+00") + (BAR_W + 4.0 if bars() else 0.0)
	return Vector2(minf(maxf(w, _text_w(title())) + PAD * 2, max_width), (rows.size() + 1) * lh + 2 + PAD * 2).ceil()

## Width of the widest value.
func _value_w() -> float:
	var w: float = _text_w("00")
	for r: Dictionary in rows:
		w = maxf(w, _text_w(str(int(r["new"]))))
	return w

## What a screen reader says: every stat with its new value and gain.
func screen_reader_text() -> String:
	var parts: PackedStringArray = [title()]
	for r: Dictionary in rows:
		parts.append("%s %d (+%d)" % [Loc.t(str(r.label)), int(r["new"]), int(r.gain)])
	return ", ".join(parts)

func _draw() -> void:
	accessibility_name = screen_reader_text()
	var font: Font = _font()
	var fs: int = UITheme.FONT_SIZE
	var c: Dictionary = EraBattleHud.colours(era)
	var lh: int = EraBattleHud.line_h(era) + 1
	var asc: int = EraBattleHud.ascent(era)
	draw_style_box(EraBattleHud.frame_style(era), Rect2(Vector2.ZERO, size))
	var x0: float = PAD
	var y: float = PAD
	draw_string(font, Vector2(x0, y + asc), title(), HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2, fs, UITheme.INK)
	y += lh
	draw_rect(Rect2(x0, y, size.x - PAD * 2, 1), c.accent)
	y += 2
	var label_w: float = _label_w()
	var val_right: float = x0 + label_w + 4.0 + _value_w()
	var gain_col: Color = Color(str(EraBattleHud.cfg().get("gain_colour", "2e7d32"))) if EraBattleHud.rank(era, "level_panel") >= 1 else UITheme.INK
	var top: float = 1.0
	for r: Dictionary in rows:
		top = maxf(top, float(r["new"]))
	for r: Dictionary in rows:
		var shown: int = int(r.old) + roundi(int(r.gain) * progress)
		draw_string(font, Vector2(x0, y + asc), Loc.t(str(r.label)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		var v: String = str(shown)
		draw_string(font, Vector2(val_right - _text_w(v), y + asc), v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		var gx: float = val_right + 3.0
		draw_string(font, Vector2(gx, y + asc), "+%d" % int(r.gain), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gain_col)
		if bars():
			var bx: float = gx + _text_w("+00") + 4.0
			var by: float = y + floorf((asc - 4) / 2.0) + 1.0
			draw_rect(Rect2(bx, by, BAR_W, 4), UITheme.INK)
			draw_rect(Rect2(bx + 1, by + 1, BAR_W - 2, 2), UITheme.BG)
			var old_w: float = floorf((BAR_W - 2) * float(r.old) / top)
			var new_w: float = floorf((BAR_W - 2) * (float(r.old) + float(r.gain) * progress) / top)
			draw_rect(Rect2(bx + 1, by + 1, old_w, 2), c.accent)
			draw_rect(Rect2(bx + 1 + old_w, by + 1, maxf(new_w - old_w, 0.0), 2), gain_col)
		y += lh
