class_name ValueChart
extends Control
## The Values tab picture (KAMPF_PLAN_1000 items 209, 230): a five-point radar of the values
## and one bar per Spark value under it. Drawn in whole pixels and palette colours, Chimora's
## own; screen readers get the numbers as text (accessibility_description).
## Each value is measured against the most a kind could have at the same ring (base
## DataValidator.BASE_MAX, full Spark, no temperament), so the shape compares kinds fairly.

const RADIUS: int = 22
const BAR_W: int = 48
const ROW_H: int = 7

var spirling: Spirling

static func make(s: Spirling) -> ValueChart:
	var c := ValueChart.new()
	c.spirling = s
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(RADIUS * 2 + 8 + 2 + BAR_W + 24, maxf(RADIUS * 2 + 8, Spirling.STAT_KEYS.size() * ROW_H + 2))
	c.accessibility_description = describe(s)
	return c

## Share (0..1) of the top a kind could reach at this ring, per value in Spirling.STAT_KEYS order.
static func shares(s: Spirling) -> Array[float]:
	var out: Array[float] = []
	for key: String in Spirling.STAT_KEYS:
		var top: int = BattleGuide.calc(key, DataValidator.BASE_MAX, s.level, Spirling.SPARK_MAX)
		out.append(clampf(float(BattleGuide.value(s, key)) / float(maxi(top, 1)), 0.0, 1.0))
	return out

## Spark value as a share of the top (12), per value.
static func spark_shares(s: Spirling) -> Array[float]:
	var out: Array[float] = []
	for key: String in Spirling.STAT_KEYS:
		out.append(clampf(float(s.spark.get(key, 0)) / float(Spirling.SPARK_MAX), 0.0, 1.0))
	return out

## Corner points of the radar for [param values] (0..1 each) around [param center]: the first
## points straight up, the rest follow clockwise. Rounded to whole pixels.
static func radar_points(values: Array[float], center: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = values.size()
	for i: int in n:
		var a: float = -PI / 2.0 + TAU * float(i) / float(maxi(n, 1))
		out.append((center + Vector2(cos(a), sin(a)) * radius * values[i]).round())
	return out

## "Might 52, Spark 7 of 12" per value, for screen readers.
static func describe(s: Spirling) -> String:
	var parts: PackedStringArray = []
	for key: String in Spirling.STAT_KEYS:
		parts.append(Loc.t("%s %d, Spark %d of %d") % [Loc.t(BattleGuide.stat_label(key)), BattleGuide.value(s, key), int(s.spark.get(key, 0)), Spirling.SPARK_MAX])
	return ", ".join(parts)

func _draw() -> void:
	if spirling == null or spirling.data == null:
		return
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var c := Vector2(RADIUS + 4, RADIUS + 4)
	var full: Array[float] = []
	full.resize(Spirling.STAT_KEYS.size())
	full.fill(1.0)
	var rim: PackedVector2Array = radar_points(full, c, RADIUS)
	for i: int in rim.size():
		draw_line(c, rim[i], UITheme.MID, 1.0)
		draw_line(rim[i], rim[(i + 1) % rim.size()], UITheme.MID, 1.0)
	var shape: PackedVector2Array = radar_points(shares(spirling), c, RADIUS)
	var fill: Color = UITheme.ACCENT
	fill.a = 0.45
	if shape.size() >= 3 and not UITheme.high_contrast:
		draw_colored_polygon(shape, fill)
	for i: int in shape.size():
		draw_line(shape[i], shape[(i + 1) % shape.size()], UITheme.INK, 1.0)
	# Spark bars to the right: the short name, then a bar of 12 steps.
	var x0: float = RADIUS * 2 + 10
	var sp: Array[float] = spark_shares(spirling)
	for i: int in Spirling.STAT_KEYS.size():
		var y: float = 1.0 + i * ROW_H
		var key: String = Spirling.STAT_KEYS[i]
		draw_string(font, Vector2(x0, y + minf(font.get_ascent(fs), ROW_H - 1)), Loc.t(BattleGuide.SHORT[key]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		var bar := Rect2(x0 + 20, y + 1, BAR_W, ROW_H - 3)
		draw_rect(bar, UITheme.INK, false, 1.0)
		draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2(roundf((BAR_W - 2) * sp[i]), bar.size.y - 2)), UITheme.INK if UITheme.high_contrast else UITheme.ACCENT)
