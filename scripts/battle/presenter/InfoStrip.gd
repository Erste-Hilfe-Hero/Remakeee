class_name InfoStrip
extends Control
## Slim edge-anchored status strip: name, level, status tag, HP bar and Energy pips.
## Drawn with primitives (no boxed "battle panel").

const BAR_HEIGHT: int = 3
const PIP_SIZE: int = 3
const PIP_GAP: int = 1
const ENERGY_ON: Color = Color("3b6fd9")
const TWEEN_TIME: float = 0.4
const TICK_STEP: int = 8
## Paper tag drawn behind the strip so it stays readable on any backdrop.
const PLATE_PAD: Vector2 = Vector2(3, 2)

## Show the numeric HP (player side only).
@export var show_numbers: bool = false
## Show the growth (EXP) bar towards the next ring (player side only).
@export var show_xp: bool = false
const XP_ON: Color = Color("c9a227")
const XP_LABEL: String = "EXP"

## Share of the way from this ring to the next, 0 to 1 (1 at the top ring).
var xp_frac: float = 0.0
## Growth still needed for the next ring.
var xp_left: int = 0

var display_hp: float = 1.0
## Era whose HP bar look is drawn (HpBarStyle); set from EraManager on set_spirling.
var era: int = 1
## Era V: where the soft trail behind the bar sits (lags display_hp on damage).
var trail_hp: float = 1.0
var _time: float = 0.0
var max_hp: int = 1
var energy: int = 0
var spirling_name: String = ""
## Element symbols drawn after the name (shape, not colour, tells them apart).
var elements: Array[int] = []
var level: int = 1
var status: String = ""
var speed_scale: float = 1.0
## Stat stages shown as small up/down arrows after the Energy pips.
var stages: Dictionary[String, int] = {}
## Turns left on an Energy tax, drawn as a coin with the number at the right end of the pips.
var tax: int = 0
const TAX_COIN: Color = Color("b8862b")

func set_spirling(s: Spirling) -> void:
	spirling_name = s.display_name()
	elements = s.elements()
	level = s.level
	max_hp = s.max_hp()
	display_hp = s.hp
	trail_hp = s.hp
	era = EraManager.active_era()
	energy = s.energy
	status = s.status
	stages = s.stages.duplicate()
	tax = s.energy_tax
	set_xp(s)

## Share of the way [param s] has grown from its ring to the next, 0 to 1.
static func xp_fraction(s: Spirling) -> float:
	if s.level >= Spirling.MAX_LEVEL:
		return 1.0
	var lo: int = Spirling.xp_for_level(s.level)
	var hi: int = Spirling.xp_for_level(s.level + 1)
	return clampf(float(s.xp - lo) / float(maxi(hi - lo, 1)), 0.0, 1.0)

func set_xp(s: Spirling) -> void:
	xp_frac = xp_fraction(s)
	xp_left = s.xp_to_next()
	queue_redraw()

func set_tax(turns: int) -> void:
	tax = maxi(turns, 0)
	queue_redraw()

func set_stages(value: Dictionary[String, int]) -> void:
	stages = value.duplicate()
	queue_redraw()

## Tweens the bar to [param hp]. Awaitable.
func animate_hp(hp: int, new_max: int = -1) -> void:
	if new_max > 0:
		max_hp = new_max
	var tw: Tween = create_tween()
	tw.tween_method(_set_display_hp, display_hp, float(hp), TWEEN_TIME / speed_scale)
	if bool(HpBarStyle.for_era(era).get("trail", false)) and float(hp) < trail_hp:
		var c: Dictionary = HpBarStyle.cfg()
		var tt: Tween = create_tween()
		tt.tween_interval(float(c.get("trail_delay", 0.35)) / speed_scale)
		tt.tween_method(_set_trail_hp, trail_hp, float(hp), float(c.get("trail_time", 0.5)) / speed_scale)
	else:
		trail_hp = float(hp)
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

func _set_trail_hp(v: float) -> void:
	trail_hp = v
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if bool(HpBarStyle.for_era(era).get("blink_low", false)):
		queue_redraw()

func _set_display_hp(v: float) -> void:
	display_hp = v
	queue_redraw()

## What a screen reader says for this strip (item 77): the strip itself is drawn by hand.
func screen_reader_text() -> String:
	var t: String = Loc.t("%s ring %d, Vigor %d of %d, Energy %d" % [spirling_name, level, int(round(display_hp)), max_hp, energy])
	if not status.is_empty():
		t += ", " + Loc.t(StatusRules.label(status))
	if tax > 0:
		t += ", " + Loc.t("Energy tax %d" % tax)
	if show_xp:
		t += ", " + Loc.t("Growth to next ring %d" % xp_left)
	return t

func _draw() -> void:
	accessibility_name = screen_reader_text()
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var w: float = size.x
	var y_text: float = float(fs)
	_draw_plate()
	draw_string(font, Vector2(0, y_text), spirling_name, HORIZONTAL_ALIGNMENT_LEFT, w * 0.6, fs, UITheme.INK)
	var name_w: float = minf(font.get_string_size(spirling_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, w * 0.6)
	ElementIcons.draw_row(self, elements, Vector2(name_w + 2.0, y_text - ElementIcons.SIZE), UITheme.INK)
	var right: String = "R%d" % level
	if not status.is_empty():
		right = StatusRules.label(status).substr(0, 3).to_upper() + " " + right
	draw_string(font, Vector2(0, y_text), right, HORIZONTAL_ALIGNMENT_RIGHT, w, fs, UITheme.INK)
	var bar_y: float = y_text + 3.0
	var frac: float = clampf(display_hp / float(maxi(max_hp, 1)), 0.0, 1.0)
	_draw_hp_bar(bar_y, w, frac)
	# Notches every few pixels make the bar read as a measured scale, like a map ruler.
	for x: int in range(TICK_STEP, int(w) - 1, TICK_STEP):
		draw_rect(Rect2(x, bar_y + 1, 1, 1), UITheme.INK)
	var pip_y: float = bar_y + BAR_HEIGHT + 4.0
	for i: int in maxi(Spirling.MAX_ENERGY, energy):
		var r := Rect2(i * (PIP_SIZE + PIP_GAP), pip_y, PIP_SIZE, PIP_SIZE)
		if i < energy:
			draw_rect(r, ENERGY_ON)
		else:
			draw_rect(r, UITheme.MID, false, 1.0)
	_draw_stages(Vector2(maxi(Spirling.MAX_ENERGY, energy) * (PIP_SIZE + PIP_GAP) + 3, pip_y - 1))
	if tax > 0:
		_draw_tax(Vector2(w, pip_y - 1))
	if show_xp:
		_draw_xp(pip_y + PIP_SIZE + fs - 1, w)
	if show_numbers:
		draw_string(font, Vector2(0, pip_y + PIP_SIZE + fs - 1), "%d/%d" % [int(round(display_hp)), max_hp], HORIZONTAL_ALIGNMENT_RIGHT, w, fs, UITheme.INK)

## HP bar in the active era's look (HpBarStyle): pattern (I), traffic colours and blink (II),
## frame and gradient (III), slant (IV), soft trail (V).
func _draw_hp_bar(bar_y: float, w: float, frac: float) -> void:
	var st: Dictionary = HpBarStyle.for_era(era)
	var slant: float = float(st.get("slant", 0))
	var inner_w: float = w - 2.0
	var fill_w: float = floorf(inner_w * frac)
	draw_rect(Rect2(0, bar_y, w, BAR_HEIGHT + 2), UITheme.INK)
	draw_rect(Rect2(1, bar_y + 1, inner_w, BAR_HEIGHT), UITheme.BG)
	if bool(st.get("trail", false)) and trail_hp > display_hp:
		var tw_frac: float = clampf(trail_hp / float(maxi(max_hp, 1)), 0.0, 1.0)
		draw_rect(Rect2(1 + fill_w, bar_y + 1, floorf(inner_w * tw_frac) - fill_w, BAR_HEIGHT), Color(String(HpBarStyle.cfg().get("trail_color", "f2e3c2"))))
	if not HpBarStyle.blink_hidden(era, frac, _time):
		var col: Color = HpBarStyle.color(era, frac)
		if bool(st.get("pattern", false)):
			var state: int = HpBarStyle.state(frac)
			for y: int in BAR_HEIGHT:
				for x: int in int(fill_w):
					if HpBarStyle.pattern_ink(state, x, y):
						draw_rect(Rect2(1 + x, bar_y + 1 + y, 1, 1), col)
		else:
			draw_rect(Rect2(1, bar_y + 1, fill_w, BAR_HEIGHT), col)
			if bool(st.get("gradient", false)) and fill_w > 0:
				draw_rect(Rect2(1, bar_y + 1, fill_w, 1), col.lightened(0.35))
				draw_rect(Rect2(1, bar_y + BAR_HEIGHT, fill_w, 1), col.darkened(0.3))
	if bool(st.get("frame", false)):
		draw_rect(Rect2(-1, bar_y - 1, w + 2, BAR_HEIGHT + 4), UITheme.MID, false, 1.0)
	if slant > 0.0:
		# Cut both ends at an angle so the bar reads as leaning into the stage.
		for i: int in int(slant):
			draw_rect(Rect2(0, bar_y + BAR_HEIGHT + 1 - i, slant - i, 1), UITheme.BG)
			draw_rect(Rect2(w - 1 - i, bar_y + i, i + 1, 1), UITheme.BG)

## "EXP" and a thin gold bar on the bottom line, left half, clear of the HP numbers on the right.
func _draw_xp(baseline: float, w: float) -> void:
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	draw_string(font, Vector2(0, baseline), XP_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
	var x0: float = font.get_string_size(XP_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
	var bw: float = maxf(w * 0.55 - x0, 8.0)
	var y: float = baseline - 4.0
	draw_rect(Rect2(x0, y, bw, 4), UITheme.INK)
	draw_rect(Rect2(x0 + 1, y + 1, bw - 2, 2), UITheme.BG)
	draw_rect(Rect2(x0 + 1, y + 1, floorf((bw - 2) * xp_frac), 2), XP_ON)

## One letter plus an arrow per changed stat ("A" with up triangles for +ATK), left to right.
func _draw_stages(at: Vector2) -> void:
	var x: float = at.x
	for stat: String in BattleRules.STAGE_STATS:
		var st: int = int(stages.get(stat, 0))
		if st == 0:
			continue
		var letter: String = stat.substr(0, 1).to_upper()
		var fs: int = get_theme_default_font_size()
		var font: Font = get_theme_default_font()
		draw_string(font, Vector2(x, at.y + PIP_SIZE + 2), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		for i: int in absi(st):
			var top: float = at.y
			var tri: PackedVector2Array = [Vector2(x, top + 4), Vector2(x + 4, top + 4), Vector2(x + 2, top)] if st > 0 \
				else [Vector2(x, top), Vector2(x + 4, top), Vector2(x + 2, top + 4)]
			draw_colored_polygon(tri, UITheme.INK)
			x += 4
		x += 2

## Energy tax: a small coin and the turns left, right-aligned on the pip row.
func _draw_tax(right_top: Vector2) -> void:
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var num: String = str(tax)
	var num_w: float = font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x: float = right_top.x - num_w
	draw_string(font, Vector2(x, right_top.y + PIP_SIZE + 2), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
	var c: Vector2 = Vector2(x - 4.0, right_top.y + 2.5)
	draw_circle(c, 2.5, UITheme.INK)
	draw_circle(c, 1.5, TAX_COIN)

func _draw_plate() -> void:
	var r := Rect2(-PLATE_PAD, size + PLATE_PAD * 2.0)
	draw_rect(r, UITheme.BG)
	draw_rect(r, UITheme.INK, false, 1.0)
	# Notched corners, same language as the map-sheet frames.
	for c: Vector2 in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2.ONE]:
		draw_rect(Rect2(c, Vector2.ONE), UITheme.BG)
