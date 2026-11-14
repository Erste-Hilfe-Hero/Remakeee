class_name InfoStrip
extends Control
## Name plate of one Spirling: name, ring, status tag, Vigor bar, Energy pips and, on the
## player's own plate, the Growth bar and the Vigor numbers. Drawn with primitives in the look
## of the era on screen (EraBattleHud, docs/ERA_FEEL_HUD.md): a plain ink box (I), a washed box
## with marks (II), a slanted plate with a name band (III), with a shadow and the large font
## (IV), and a plate that glides in, leans after the camera and rolls its numbers (V).
## Rows never share pixels: what does not fit a narrow plate is left out, never drawn over.

const BAR_HEIGHT: int = 3
const PIP_SIZE: int = 3
const PIP_GAP: int = 1
const ENERGY_ON: Color = Color("3b6fd9")
const TWEEN_TIME: float = 0.4
const TICK_STEP: int = 8
## A plate at least this wide shows the element symbols beside the name; a narrower one moves
## them to the right end of the Energy row so the name keeps its room.
const WIDE: int = 96
## Pixels a rolling digit travels (Era V numbers).
const ROLL_PX: float = 4.0

## Show the numeric HP (player side only).
@export var show_numbers: bool = false
## Show the growth (EXP) bar towards the next ring (player side only).
@export var show_xp: bool = false
const XP_ON: Color = Color("c9a227")
const XP_LABEL: String = "EXP"

## Share of the way from this ring to the next, 0 to 1 (1 at the top ring).
var xp_frac: float = 0.0
## The share the Growth bar shows right now (runs after xp_frac in the eras that animate it).
var xp_shown: float = 0.0
## Growth still needed for the next ring.
var xp_left: int = 0
var _xp_tween: Tween

var display_hp: float = 1.0
## Era whose HP bar look is drawn (HpBarStyle); set from EraManager on set_spirling.
var era: int = 1
## A plate of a one-on-one battle (BattleHud.layout_single): its Vigor bar takes bar_h_single.
var single: bool = false
## Era V: where the soft trail behind the bar sits (lags display_hp on damage).
var trail_hp: float = 1.0
var _time: float = 0.0
## Colour-blind mode: patterned HP fill in every era.
var color_blind: bool = false
var max_hp: int = 1
var energy: int = 0
## Energy pip animation (KAMPF_PLAN_1000 674): the pips before the last change and how far the
## pop (gain) or fade (spend) still has to go, 1 -> 0.
var pip_from: int = 0
var pip_pulse: float = 0.0
var _pip_tween: Tween
## Most Energy of the Spirling shown (EnergyKit.cap_of, item 50): that many pips stand on the plate.
var energy_cap: int = Spirling.MAX_ENERGY
## Set by a Rest (item 73): the next Energy gain flows back pip by pip.
var flow_next: bool = false
## Seconds into that flow, -1 while none runs.
var _flow: float = -1.0
var spirling_name: String = ""
## Element symbols drawn after the name (shape, not colour, tells them apart).
var elements: Array[int] = []
## KAMPF_PLAN_1000 item 113: after a very effective hit the symbols of the elements that took it
## hop twice (glyph_hop). Under reduced motion they only stand out on a paper rim while it lasts.
const GLYPH_HOP_TIME: float = 0.45
const GLYPH_HOP_PX: int = 3
## 1 -> 0 while the hop runs; [member _kick_element] is the element of the art that hit.
var _kick: float = 0.0
var _kick_element: int = -1
var level: int = 1
var status: String = ""
## Turns left on [member status], shown as a small number under its tag (0 = open-ended, no number).
var status_turns: int = 0
## Share of Vigor where a boss changes phase (BattleInfo.phase_mark), -1 for no mark.
var phase_mark: float = -1.0:
	set(v):
		phase_mark = v
		queue_redraw()
var speed_scale: float = 1.0
## Stat stages shown as small up/down arrows after the Energy pips.
var stages: Dictionary[String, int] = {}
## Turns left on an Energy tax, drawn as a coin with the number at the right end of the pips.
var tax: int = 0
const TAX_COIN: Color = Color("b8862b")
## Which side of the plate leans (the side toward the middle of the screen).
var slant_left: bool = true
## From Era II: this kind was bonded before (a small filled lozenge by the ring number). Only
## on a plate without the Growth bar, so never on the player's own Spirling.
var caught: bool = false
## From Era II: a Gleam or Prism (a four-ray glint by the ring number).
var spark: bool = false
## Era V: pixels the plate still has to glide to its place.
var slide: float = 0.0
## Era V: how far the battle camera pushed the plate (BattleHud sets it each frame).
var cam_shift: Vector2 = Vector2.ZERO:
	set(v):
		if v != cam_shift:
			cam_shift = v
			queue_redraw()
var _slide_tween: Tween

func _ready() -> void:
	visibility_changed.connect(_on_shown)

func set_spirling(s: Spirling) -> void:
	spirling_name = s.display_name()
	elements = s.elements()
	level = s.level
	max_hp = s.max_hp()
	display_hp = s.hp
	trail_hp = s.hp
	era = EraManager.active_era()
	color_blind = GameState.color_blind
	energy = s.energy
	energy_cap = EnergyKit.cap_of(s)
	status = s.status
	status_turns = s.status_turns
	stages = s.stages.duplicate()
	tax = s.energy_tax
	caught = not show_xp and s.data != null and Collection._bonded(s.data.species_name)
	spark = s.gleam or s.prism
	xp_frac = xp_fraction(s)
	xp_left = s.xp_to_next()
	_stop_xp()
	xp_shown = xp_frac
	queue_redraw()

## Share of the way [param s] has grown from its ring to the next, 0 to 1.
static func xp_fraction(s: Spirling) -> float:
	if s.level >= Spirling.LEVEL_SANITY:
		return 1.0
	var lo: int = Spirling.xp_for_level(s.level)
	var hi: int = Spirling.xp_for_level(s.level + 1)
	return clampf(float(s.xp - lo) / float(maxi(hi - lo, 1)), 0.0, 1.0)

## Where the Growth bar runs to for a Spirling at ring [param real_level] while the plate
## still shows ring [param shown_level]: to the full bar first when a ring rise is still to
## come, else to [param frac].
static func xp_target(shown_level: int, real_level: int, frac: float) -> float:
	return 1.0 if real_level > shown_level else frac

## Does the Growth bar of [param p_era] run to its new value (Era III on)? Never under
## reduced motion.
static func xp_animates(p_era: int, reduced: bool) -> bool:
	return not reduced and EraBattleHud.text(p_era, "xp", "static") == "fill"

func set_xp(s: Spirling) -> void:
	xp_frac = xp_fraction(s)
	xp_left = s.xp_to_next()
	var to: float = xp_target(level, s.level, xp_frac)
	_stop_xp()
	if not xp_animates(era, Juice.reduced()) or not is_inside_tree() or not show_xp:
		xp_shown = to
		queue_redraw()
		return
	# After a ring rise the bar starts again from empty.
	if to < xp_shown:
		xp_shown = 0.0
	_xp_tween = create_tween()
	var time: float = float(EraBattleHud.cfg().get("xp_fill_time", 0.5)) * maxf(absf(to - xp_shown), 0.2)
	_xp_tween.tween_method(_set_xp_shown, xp_shown, to, time / speed_scale)

func _stop_xp() -> void:
	if _xp_tween != null and _xp_tween.is_valid():
		_xp_tween.kill()
	_xp_tween = null

func _set_xp_shown(v: float) -> void:
	xp_shown = v
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
	# Era I/II count down at a fixed pace across the bar (a big hit takes longer); later eras
	# ease in a fixed time (EraBattleFeel.hp_drain_time).
	var span: float = float(maxi(max_hp, 1))
	var time: float = EraBattleFeel.hp_drain_time(era, display_hp / span, float(hp) / span, TWEEN_TIME)
	var step: Tweener = tw.tween_method(_set_display_hp, display_hp, float(hp), time / speed_scale)
	if not EraBattleFeel.hp_steps(era):
		(step as MethodTweener).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if bool(HpBarStyle.for_era(era).get("trail", false)) and float(hp) < trail_hp:
		var c: Dictionary = HpBarStyle.cfg()
		var tt: Tween = create_tween()
		tt.tween_interval(float(c.get("trail_delay", 0.35)) / speed_scale)
		tt.tween_method(_set_trail_hp, trail_hp, float(hp), float(c.get("trail_time", 0.5)) / speed_scale)
	else:
		trail_hp = float(hp)
	await tw.finished

func set_energy(value: int) -> void:
	var flow: bool = flow_next and value > energy and is_inside_tree() and not Juice.reduced()
	flow_next = false
	_flow = -1.0
	if flow:
		# After a Rest the gained pips fill one after another (item 73).
		pip_from = energy
		if _pip_tween != null and _pip_tween.is_valid():
			_pip_tween.kill()
		var total: float = EnergyKit.flow_time(energy, value)
		_flow = 0.0
		_pip_tween = create_tween()
		_pip_tween.tween_method(func(v: float) -> void:
			_flow = v
			queue_redraw(), 0.0, total, total / speed_scale)
		_pip_tween.tween_callback(func() -> void:
			_flow = -1.0
			queue_redraw())
	elif value != energy and is_inside_tree() and not Juice.reduced():
		pip_from = energy
		if _pip_tween != null and _pip_tween.is_valid():
			_pip_tween.kill()
		_pip_tween = create_tween()
		_pip_tween.tween_method(func(v: float) -> void:
			pip_pulse = v
			queue_redraw(), 1.0, 0.0, float((BattleShow.cfg().get("energy_pips", {}) as Dictionary).get("time", 0.35)) / speed_scale)
	energy = value
	queue_redraw()

## Look of pip [param i] (674): {"fill": filled, "alpha": fill strength, "grow": extra pixels}.
## A gained pip pops one pixel bigger and settles, a spent one fades out from full.
static func pip_look(i: int, now: int, from: int, pulse: float) -> Dictionary:
	if i < now:
		var gained: bool = i >= from and pulse > 0.0
		return {"fill": true, "alpha": 1.0, "grow": 1 if gained and pulse > 0.5 else 0}
	if i < from and pulse > 0.0:
		return {"fill": true, "alpha": pulse, "grow": 0}
	return {"fill": false, "alpha": 1.0, "grow": 0}

## Look of pip [param i] while Energy flows back after a Rest (item 73): [param lit] pips stand
## filled, and the newest gained one pops a pixel bigger.
static func flow_look(i: int, from: int, lit: int) -> Dictionary:
	return {"fill": i < lit, "alpha": 1.0, "grow": 1 if i == lit - 1 and i >= from else 0}

func set_status(value: String) -> void:
	status = value
	if value.is_empty():
		status_turns = 0
	queue_redraw()

## Turns left on the status (item 163), refreshed each time orders are asked for.
func set_status_turns(turns: int) -> void:
	if turns != status_turns:
		status_turns = turns
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

## Era V: the plate glides in from its screen edge when it appears. Not under reduced motion.
func _on_shown() -> void:
	if not is_visible_in_tree() or not slides(EraManager.active_era(), Juice.reduced()):
		slide = 0.0
		return
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	slide = slide_from(size.x, slant_left)
	modulate.a = 0.0
	_slide_tween = create_tween().set_parallel(true)
	var t: float = float(EraBattleHud.cfg().get("slide_time", 0.3)) / speed_scale
	Juice.shaped(_slide_tween.tween_method(_set_slide, slide, 0.0, t), "open")
	Juice.shaped(_slide_tween.tween_property(self, "modulate:a", 1.0, t), "fade")

static func slides(p_era: int, reduced: bool) -> bool:
	return not reduced and EraBattleHud.flag(p_era, "plate_slide")

## Where a gliding plate starts: half its width out toward its own screen edge.
static func slide_from(width: float, p_slant_left: bool) -> float:
	return roundf(width * 0.5) * (1.0 if p_slant_left else -1.0)

func _set_slide(v: float) -> void:
	slide = v
	queue_redraw()

## The rect the plate draws over, in the parent's coordinates (at rest).
func plate_rect() -> Rect2:
	return EraBattleHud.plate_outer(era, Rect2(position, size), slant_left)

## What a screen reader says for this strip (item 77): the strip itself is drawn by hand.
func screen_reader_text() -> String:
	var t: String = Loc.t("%s ring %d, Vigor %d of %d, Energy %d" % [spirling_name, level, int(round(display_hp)), max_hp, energy])
	if not status.is_empty():
		t += ", " + Loc.t(StatusRules.label(status))
		if status_turns > 0:
			t += ", " + Loc.t("%d turns left") % status_turns
	if tax > 0:
		t += ", " + Loc.t("Energy tax %d" % tax)
	# Stages with their factor (KAMPF_PLAN_1000 item 222).
	for stat: String in BattleRules.STAGE_STATS:
		if int(stages.get(stat, 0)) != 0:
			t += ", " + BattleRules.stage_line(Loc.t(str(BattleEvent.STAT_NAMES[stat])), int(stages[stat]))
	if show_xp:
		t += ", " + Loc.t("Growth to next ring %d" % xp_left)
	return t

## Element symbols beside the name? Only on a plate wide enough for both.
func icons_by_name() -> bool:
	return size.x >= WIDE

func _draw() -> void:
	accessibility_name = screen_reader_text()
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var rows: Dictionary = EraBattleHud.plate_rows(era, single)
	var c: Dictionary = EraBattleHud.colours(era)
	var w: float = size.x
	var asc: float = float(rows.asc)
	draw_set_transform(Vector2(roundf(slide), 0) + cam_shift)
	var pad: Array[int] = EraBattleHud.plate_pad(era, slant_left)
	var shadow: int = 2 if EraBattleHud.flag(era, "plate_shadow") else 0
	var outer := Rect2(-pad[0], -pad[1], w + pad[0] + pad[2] - shadow, size.y + pad[1] + pad[3] - shadow)
	var band: bool = EraBattleHud.flag(era, "plate_header")
	EraBattleHud.draw_plate(self, outer, era, slant_left, pad[1] + int(asc) + 2)
	var head: Color = c.paper if band else c.ink
	# Row 1: name (and symbols on a wide plate) on the left, marks and the ring number right.
	var right: String = "R%d" % level
	var x_right: float = w - font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(x_right, asc), right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, head)
	x_right -= 2.0
	var by_name: bool = icons_by_name()
	var marked: bool = EraBattleHud.flag(era, "marks")
	if marked and by_name:
		x_right = _draw_marks(x_right, asc - 4.0, head, c.light if band else Color(XP_ON))
	var icons_w: float = elements.size() * (ElementIcons.SIZE + 1)
	var name_max: float = maxf(x_right - 1.0 - (icons_w + 2.0 if by_name else 0.0), 8.0)
	draw_string(font, Vector2(0, asc), spirling_name, HORIZONTAL_ALIGNMENT_LEFT, name_max, fs, head)
	if by_name:
		var name_w: float = minf(font.get_string_size(spirling_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, name_max)
		_draw_elements(Vector2(name_w + 2.0, asc - ElementIcons.SIZE), band)
	# Row 2: the Vigor bar, shortened for the status tag at its right end.
	var bar_y: float = float(rows.bar_y)
	var bar_h: int = int(rows.bar_h)
	var bar_w: float = w
	var tag_right: float = w
	if not status.is_empty():
		var tag: String = StatusRules.tag(status)
		var bold: bool = UITheme.high_contrast
		var tw: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (1.0 if bold else 0.0)
		# The status symbol (item 162) sits left of the letters, so the tag reads by shape too.
		var sym_w: float = SYMBOL_SIZE + 1.0 if not StatusRules.symbol(status).is_empty() else 0.0
		var box := Rect2(roundf(w - tw - sym_w - 3.0), bar_y - 1.0, roundf(tw + sym_w + 3.0), asc + 1.0)
		var badge: Color = EraBattleFeel.status_badge(era, status)
		if badge.a > 0.0:
			# Era II+: the status as a coloured badge; Era I keeps plain ink letters.
			draw_rect(box, badge)
		var ink: Color = badge_text(badge)
		if bold:
			# High contrast (item 190): an ink frame and doubled strokes, so the tag reads bold.
			draw_rect(box.grow(1.0), UITheme.INK, false, 1.0)
		var sym_at := Vector2(box.position.x + 1.0, box.position.y + floorf((box.size.y - SYMBOL_SIZE) / 2.0))
		draw_symbol(self, status, sym_at, ink)
		var text_at := Vector2(box.position.x + 2.0 + sym_w, box.position.y + asc)
		draw_string(font, text_at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		if bold:
			draw_string(font, text_at + Vector2(1, 0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		bar_w = box.position.x - 2.0
		tag_right = box.end.x
	var frac: float = clampf(display_hp / float(maxi(max_hp, 1)), 0.0, 1.0)
	_draw_hp_bar(bar_y, bar_w, frac, bar_h)
	# Notches every few pixels make the bar read as a measured scale, like a map ruler.
	for x: int in range(TICK_STEP, int(bar_w) - 1, TICK_STEP):
		draw_rect(Rect2(x, bar_y + 1, 1, 1), UITheme.INK)
	# Boss phase mark (KAMPF_PLAN item 598): a tall notch where the second phase starts.
	if phase_mark > 0.0 and phase_mark < 1.0:
		draw_rect(Rect2(roundf(bar_w * phase_mark), bar_y - 1, 1, bar_h + 2), UITheme.INK)
	# Row 3: Energy pips, stat arrows, the Energy tax and (narrow plate) the element symbols.
	var row3: float = float(rows.row3_y)
	var row3_h: float = float(rows.row3_h)
	# One-hand mode draws bigger pips (item 72); a kind that holds more shows more (item 50).
	var pip: float = minf(EnergyKit.pip_size(EraBattleHud.num(era, "pip", 2), GameState.one_hand), row3_h)
	var pips: int = maxi(energy_cap, energy)
	for i: int in pips:
		var r := Rect2(i * (pip + 1.0), row3 + floorf((row3_h - pip) / 2.0), pip, pip)
		var look: Dictionary = pip_look(i, energy, pip_from, pip_pulse) if _flow < 0.0 \
			else flow_look(i, pip_from, EnergyKit.flow_lit(pip_from, energy, _flow))
		if bool(look.fill):
			if float(look.alpha) < 1.0:
				draw_rect(r, UITheme.MID, false, 1.0)
			draw_rect(r.grow(float(look.grow)), Color(ENERGY_ON, float(look.alpha)))
		else:
			draw_rect(r, UITheme.MID, false, 1.0)
	var limit: float = w
	if not by_name:
		limit = w - icons_w + 1.0
		_draw_elements(Vector2(limit, row3 + floorf((row3_h - ElementIcons.SIZE) / 2.0)), false)
		limit -= 2.0
		if marked:
			limit = _draw_marks(limit, row3 + floorf(row3_h / 2.0), c.ink, Color(XP_ON))
	# The turns left on the status, under its tag (item 163): only for a status that runs out.
	var turns: String = StatusRules.turns_tag(status_turns) if not status.is_empty() else ""
	if not turns.is_empty():
		var nw: float = font.get_string_size(turns, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var nx: float = minf(tag_right, limit) - nw
		draw_string(font, Vector2(nx, row3 + minf(font.get_ascent(fs), row3_h)), turns, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		limit = nx - 2.0
	if tax > 0:
		limit = _draw_tax(limit, row3, row3_h) - 2.0
	_draw_stages(pips * (pip + 1.0) + 2.0, limit, row3, row3_h)
	# Row 4 (the player's own plate): Growth bar on the left, Vigor numbers on the right.
	var x_num: float = w
	if show_numbers:
		x_num = _draw_numbers(float(rows.row4), w)
	if show_xp:
		_draw_xp(float(rows.row4), x_num - 3.0)
	draw_set_transform(Vector2.ZERO)

## Side of the status symbol grid (StatusRules.SYMBOLS), in pixels.
const SYMBOL_SIZE: int = 5

## Draws the symbol of [param p_status] with its top-left at [param at] on [param ci].
static func draw_symbol(ci: CanvasItem, p_status: String, at: Vector2, col: Color) -> void:
	for d: Array in StatusRules.symbol(p_status):
		ci.draw_rect(Rect2(at + Vector2(int(d[0]), int(d[1])), Vector2(1, 1)), col)

## Letters on a status badge: light or ink, whichever stands out more on [param badge]
## (plain ink where there is no badge, Era I).
static func badge_text(badge: Color) -> Color:
	if badge.a <= 0.0:
		return UITheme.INK
	var light := Color("f8f4ec")
	return light if UITheme.contrast(light, badge) >= UITheme.contrast(UITheme.INK, badge) else UITheme.INK

## The Gleam / Prism glint and the bonded-before lozenge, right to left from [param right];
## returns the left edge they used.
func _draw_marks(right: float, mid_y: float, col: Color, spark_col: Color) -> float:
	var x: float = right
	if spark:
		x -= 6.0
		_draw_spark(Vector2(x + 2.0, mid_y), spark_col)
	if caught:
		x -= 6.0
		_draw_caught(Vector2(x + 2.0, mid_y), col)
	return x

func _draw_elements(at: Vector2, on_band: bool) -> void:
	var x: float = at.x
	var reduced: bool = Juice.reduced()
	for el: int in elements:
		var kicked: bool = _kick > 0.0 and glyph_kicked(_kick_element, el)
		var y: float = at.y + (glyph_hop(_kick, reduced) if kicked else 0)
		# High contrast (item 108) and a kicked symbol under reduced motion get the 9 px rimmed symbol.
		if on_band or UITheme.high_contrast or (kicked and reduced):
			draw_texture(ElementIcons.outlined(el, BattleUiStyle.badge_color(era, el), UITheme.BG), Vector2(x - 1.0, y - 1.0))
		else:
			draw_texture(ElementIcons.texture(el, BattleUiStyle.badge_color(era, el)), Vector2(x, y))
		x += ElementIcons.SIZE + 1

## Starts the hop of the symbols hit very effectively by an art of [param art_element].
func kick_glyphs(art_element: int) -> void:
	_kick_element = art_element
	if not is_inside_tree() or not elements.any(func(el: int) -> bool: return glyph_kicked(art_element, el)):
		return
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void:
		_kick = v
		queue_redraw(), 1.0, 0.0, GLYPH_HOP_TIME / maxf(speed_scale, 0.1))

## True when [param art_element] hits the element [param el] very effectively.
static func glyph_kicked(art_element: int, el: int) -> bool:
	return art_element >= 0 and Elements.single(art_element, el) > 1.0

## Vertical offset of a kicked symbol at [param k] (1 -> 0): two hops of up to GLYPH_HOP_PX
## pixels, whole pixels only; 0 under reduced motion.
static func glyph_hop(k: float, reduced: bool) -> int:
	if reduced or k <= 0.0 or k >= 1.0:
		return 0
	return -roundi(GLYPH_HOP_PX * absf(sin(k * TAU)))

## Bonded before: a small filled lozenge (5 px).
func _draw_caught(at: Vector2, col: Color) -> void:
	for y: int in 5:
		var half: int = 2 - absi(y - 2)
		draw_rect(Rect2(at.x - half, at.y - 2 + y, half * 2 + 1, 1), col)

## Gleam or Prism: a four-ray glint (5 px).
func _draw_spark(at: Vector2, col: Color) -> void:
	draw_rect(Rect2(at.x, at.y - 2, 1, 5), col)
	draw_rect(Rect2(at.x - 2, at.y, 5, 1), col)

## HP bar in the active era's look (HpBarStyle): pattern (I), traffic colours and blink (II),
## frame and gradient (III), slant (IV), soft trail (V).
func _draw_hp_bar(bar_y: float, w: float, frac: float, bar_h: int = BAR_HEIGHT) -> void:
	var st: Dictionary = HpBarStyle.for_era(era)
	var slant: float = float(st.get("slant", 0))
	var inner_w: float = w - 2.0
	var fill_w: float = floorf(inner_w * frac)
	draw_rect(Rect2(0, bar_y, w, bar_h + 2), UITheme.INK)
	draw_rect(Rect2(1, bar_y + 1, inner_w, bar_h), UITheme.BG)
	if bool(st.get("trail", false)) and trail_hp > display_hp:
		var tw_frac: float = clampf(trail_hp / float(maxi(max_hp, 1)), 0.0, 1.0)
		draw_rect(Rect2(1 + fill_w, bar_y + 1, floorf(inner_w * tw_frac) - fill_w, bar_h), Color(String(HpBarStyle.cfg().get("trail_color", "f2e3c2"))))
	if not HpBarStyle.blink_hidden(era, frac, _time):
		var col: Color = HpBarStyle.color(era, frac)
		if BattleUiStyle.hp_pattern(era, color_blind):
			var state: int = HpBarStyle.state(frac)
			for y: int in bar_h:
				for x: int in int(fill_w):
					if HpBarStyle.pattern_ink(state, x, y):
						draw_rect(Rect2(1 + x, bar_y + 1 + y, 1, 1), col)
		else:
			draw_rect(Rect2(1, bar_y + 1, fill_w, bar_h), col)
			if bool(st.get("gradient", false)) and fill_w > 0:
				draw_rect(Rect2(1, bar_y + 1, fill_w, 1), col.lightened(0.35))
				draw_rect(Rect2(1, bar_y + bar_h, fill_w, 1), col.darkened(0.3))
	if bool(st.get("frame", false)):
		draw_rect(Rect2(-1, bar_y - 1, w + 2, bar_h + 4), UITheme.MID, false, 1.0)
	if slant > 0.0:
		# Cut both ends at an angle so the bar reads as leaning into the stage.
		for i: int in int(slant):
			draw_rect(Rect2(0, bar_y + bar_h + 1 - i, slant - i, 1), UITheme.BG)
			draw_rect(Rect2(w - 1 - i, bar_y + i, i + 1, 1), UITheme.BG)

## The Vigor numbers, right-aligned at [param right]; returns their left edge. Era V rolls the
## digits like a counter while the bar moves.
func _draw_numbers(baseline: float, right: float) -> float:
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var tail: String = "/%d" % max_hp
	var tail_w: float = font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(right - tail_w, baseline), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
	var places: int = str(maxi(max_hp, 1)).length()
	var dw: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0: float = right - tail_w - places * dw
	if EraBattleHud.text(era, "hp_numbers", "plain") != "roll" or Juice.reduced():
		var now: String = str(int(round(display_hp)))
		draw_string(font, Vector2(right - tail_w - font.get_string_size(now, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, baseline), now,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		return x0
	var digits: Array[Dictionary] = EraBattleHud.roll_digits(display_hp, places)
	var lead: bool = true
	for i: int in digits.size():
		var d: Dictionary = digits[i]
		var x: float = x0 + i * dw
		var shift: float = float(d.shift)
		# Leading zeros stay blank ("  7/31").
		if lead and int(d.digit) == 0 and i < digits.size() - 1 and (shift <= 0.0 or int(d.next) == 0):
			continue
		lead = false
		draw_string(font, Vector2(x, baseline - roundf(shift * ROLL_PX)), str(int(d.digit)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UITheme.INK, 1.0 - shift))
		if shift > 0.0:
			draw_string(font, Vector2(x, baseline + roundf((1.0 - shift) * ROLL_PX)), str(int(d.next)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UITheme.INK, shift))
	return x0

## "EXP" and a thin bar on the bottom line, from the left edge to [param right]. The label is
## left out when the bar would get too short. Era I draws it in ink, later eras in gold.
func _draw_xp(baseline: float, right: float) -> void:
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var x0: float = 0.0
	var label_w: float = font.get_string_size(XP_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
	if right - label_w >= 14.0:
		draw_string(font, Vector2(0, baseline), XP_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		x0 = label_w
	var bw: float = right - x0
	if bw < 6.0:
		return
	var y: float = baseline - 4.0
	draw_rect(Rect2(x0, y, bw, 4), UITheme.INK)
	draw_rect(Rect2(x0 + 1, y + 1, bw - 2, 2), UITheme.BG)
	var col: Color = Color(str(EraBattleHud.cfg().get("xp_colour", "c9a227"))) if EraBattleHud.flag(era, "xp_colour") else UITheme.MID
	draw_rect(Rect2(x0 + 1, y + 1, floorf((bw - 2) * clampf(xp_shown, 0.0, 1.0)), 2), col)

## How many of [param entries] ([letter width, arrows] each) fit between two x positions.
static func stages_that_fit(room: float, entries: Array) -> int:
	var used: float = 0.0
	var n: int = 0
	for e: Variant in entries:
		var need: float = float((e as Array)[0]) + absi(int((e as Array)[1])) * 4.0 + 2.0
		if used + need > room:
			break
		used += need
		n += 1
	return n

## One letter plus an arrow per changed stat ("A" with up triangles for +ATK), left to right,
## as many as fit before [param limit].
func _draw_stages(x0: float, limit: float, row_y: float, row_h: float) -> void:
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var asc: float = font.get_ascent(fs)
	var entries: Array = []
	var letters: Array[String] = []
	for stat: String in BattleRules.STAGE_STATS:
		var st: int = int(stages.get(stat, 0))
		if st == 0:
			continue
		var letter: String = stat.substr(0, 1).to_upper()
		letters.append(letter)
		entries.append([font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, st])
	var x: float = x0
	for i: int in stages_that_fit(limit - x0, entries):
		var st: int = int(entries[i][1])
		draw_string(font, Vector2(x, row_y + minf(asc, row_h)), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		x += float(entries[i][0])
		for k: int in absi(st):
			var top: float = row_y + floorf((row_h - 4.0) / 2.0)
			var tri: PackedVector2Array = [Vector2(x, top + 4), Vector2(x + 4, top + 4), Vector2(x + 2, top)] if st > 0 \
				else [Vector2(x, top), Vector2(x + 4, top), Vector2(x + 2, top + 4)]
			draw_colored_polygon(tri, UITheme.INK)
			x += 4
		x += 2

## Energy tax: a small coin and the turns left, right-aligned at [param right]; returns the
## left edge it used.
func _draw_tax(right: float, row_y: float, row_h: float) -> float:
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var num: String = str(tax)
	var num_w: float = font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x: float = right - num_w
	draw_string(font, Vector2(x, row_y + minf(font.get_ascent(fs), row_h)), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
	var c: Vector2 = Vector2(x - 4.0, row_y + row_h / 2.0)
	draw_circle(c, 2.5, UITheme.INK)
	draw_circle(c, 1.5, TAX_COIN)
	return x - 7.0
