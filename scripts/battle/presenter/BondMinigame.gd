class_name BondMinigame
extends Control
## Bond minigame "Echo call": the wild Spirling calls a short sequence on three marks
## (diamond, square, triangle; moon, star, spark for Lumen and Umbra), then the player taps
## the same marks in the same order. run() is awaitable and returns a score 0..1.
## No odds or grades are shown while it runs, and afterwards only words (LEGAL.md).
## Rules live in BondEcho; this scene only plays a plan from BondEcho.make_plan().

signal finished(score: float)

enum Phase { IDLE, CALL, ECHO, AFTER_CALL, AFTER_ECHO, RESULT, MINE }

const MARK_SIZE: float = 26.0
const FLASH_TIME: float = 0.18
const TARGET_SIZE: float = 40.0
## Seconds the result words stay up before the battle goes on.
const RESULT_TIME: float = 1.1
## Seconds to echo the single afterglow mark.
const AFTER_ECHO_TIME: float = 2.5

## The wild Spirling being reached out to, drawn above the marks.
var target: Texture2D
## Its name, shown on the plate under it from Era III on.
var target_name: String = ""
## Era whose look the screen is drawn in (EraBattleHud "bond", docs/ERA_FEEL_HUD.md): plain ink
## (I), coloured marks (II), a framed screen with a name plate (III), bigger marks for touch
## and a slanted plate (IV), and softly breathing marks (V, not under reduced motion). Only the
## look changes: still no odds, no aiming and no shrinking shapes (LEGAL.md).
var era: int = 1
## Set for reproducible calls (tests, screenshots); otherwise randomized per run.
var rng: RandomNumberGenerator
## Bonding style "Calm" (Kampf-Plan, Barrierefreiheit): the echo has no time limit, so nobody
## has to keep a rhythm. The afterglow waits too; Back or a tap beside the marks skips it.
var calm: bool = false

var _phase: Phase = Phase.IDLE
var _time: float = 0.0
var _plan: Dictionary = {}
var _phase_index: int = 0
## Marks of the phase being called or echoed right now.
var _sequence: Array[int] = []
var _taps: Array[int] = []
## Taps of every phase so far (for BondEcho.plan_score).
var _all_taps: Array = []
var _afterglow_tap: int = -1
var _flash_mark: int = -1
var _flash_left: float = 0.0
var _last_lit: int = -1
var _score: float = 0.0
var _hint: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 6
	_hint.offset_left = 8
	_hint.offset_right = -8
	add_child(_hint)
	visible = false
	visibility_changed.connect(func() -> void:
		if visible:
			era = EraManager.active_era())

## Size of one mark in the era on screen (bigger on the 270 px wide screens).
func mark_size() -> float:
	return EraBattleHud.num(era, "bond_mark", MARK_SIZE)

## Size the Spirling is drawn at above the marks.
func target_size() -> float:
	return TARGET_SIZE * mark_size() / MARK_SIZE

## Fill of mark [param i]: Era I ink on paper; from Era II each mark has its own colour, pale
## while it rests and full while it sounds.
static func mark_fill(p_era: int, i: int, lit: bool) -> Color:
	if EraBattleHud.rank(p_era, "bond") < 1 or UITheme.high_contrast:
		return UITheme.INK if lit else UITheme.ACCENT
	var cols: Array = EraBattleHud.cfg().get("bond_mark_colours", [])
	var c: Color = Color(str(cols[i % cols.size()])) if not cols.is_empty() else UITheme.ACCENT
	return c if lit else c.lerp(UITheme.BG, 0.6)

## "Mine!" (owner, 9 Nov): one big button, just tap it fast. Each tap fills the bar; a full bar
## inside MINE_TIME bonds best, otherwise the fill reached is the score. Nothing pulls back.
const MINE_TIME: float = 3.5
const MINE_SIZE: float = 44.0
var mine_fill: float = 0.0
var _mine_needed: int = 0

## Taps for a full bar: 18 for a common Spirling (about 5 a second, as hard as a clean echo),
## up to 24 for rarer ones (longer calls), two fewer near a mended Rift, two more near a muted one.
static func mine_taps(plan: Dictionary) -> int:
	var marks: int = 0
	for p: Variant in plan.get("phases", []):
		marks += (p as Array).size()
	var n: int = clampi(18 + (marks - 4), 18, 24)
	match str(plan.get("state", "")):
		"mended":
			n -= 2
		"muted":
			n += 2
	return n

## Plays the "Mine!" tug for [param plan]; returns a score 0..1 like run().
func run_mine(plan: Dictionary = {}) -> float:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_plan = plan if not plan.is_empty() else BondEcho.make_plan(rng, null)
	_mine_needed = mine_taps(_plan)
	mine_fill = 0.0
	_time = 0.0
	_phase = Phase.MINE
	_hint.text = "Tap Mine! fast!"
	visible = true
	var result: float = await finished
	visible = false
	return result

## One tap on "Mine!".
func mine_tap() -> void:
	if _phase != Phase.MINE:
		return
	mine_fill = minf(mine_fill + 1.0 / _mine_needed, 1.0)
	_tone(rng.randi_range(0, BondEcho.MARKS - 1))
	if mine_fill >= 0.999:
		_mine_end()

func _mine_end() -> void:
	_score = mine_fill
	_hint.text = BondEcho.result_words(_score)
	_phase = Phase.RESULT
	_time = 0.0

## Plays [param plan] (BondEcho.make_plan); with none, a plain four-mark call.
func run(plan: Dictionary = {}) -> float:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_plan = plan if not plan.is_empty() else BondEcho.make_plan(rng, null)
	_all_taps.clear()
	_afterglow_tap = -1
	_mine_needed = 0
	_start_phase(0)
	visible = true
	var result: float = await finished
	visible = false
	return result

func _start_phase(i: int) -> void:
	_phase_index = i
	_sequence.assign(_plan.phases[i])
	_taps.clear()
	_flash_mark = -1
	_last_lit = -1
	_time = 0.0
	_phase = Phase.CALL
	_hint.text = "Listen to the call..." if i == 0 else "It calls again..."

func _echo_time() -> float:
	return BondEcho.ECHO_TIME * maxf(1.0, _sequence.size() / float(BondEcho.SEQUENCE_LENGTH))

func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_time += delta
	_flash_left = maxf(_flash_left - delta, 0.0)
	var lit: int = _lit_mark()
	if (_phase == Phase.CALL or _phase == Phase.AFTER_CALL) and lit >= 0 and lit != _last_lit:
		_tone(lit)
	_last_lit = lit
	if _phase == Phase.MINE:
		if _time >= MINE_TIME:
			_mine_end()
		queue_redraw()
		return
	if _phase == Phase.CALL and _time >= BondEcho.call_duration(_sequence.size()) + BondEcho.GAP_TIME:
		_phase = Phase.ECHO
		_time = 0.0
		_hint.text = "Echo it back, no hurry." if calm else "Now echo it back!"
	elif _phase == Phase.ECHO and not calm and _time >= _echo_time():
		_end_phase()
	elif _phase == Phase.AFTER_CALL and _time >= BondEcho.SHOW_TIME + BondEcho.GAP_TIME:
		_phase = Phase.AFTER_ECHO
		_time = 0.0
		_hint.text = "One more?"
	elif _phase == Phase.AFTER_ECHO and not calm and _time >= AFTER_ECHO_TIME:
		_finish()
	elif _phase == Phase.RESULT and _time >= RESULT_TIME:
		_phase = Phase.IDLE
		finished.emit(_score)
	queue_redraw()

func _tap(mark: int) -> void:
	if mark < 0:
		if calm and _phase == Phase.AFTER_ECHO:
			_finish()
		return
	if _phase == Phase.AFTER_ECHO:
		_afterglow_tap = mark
		_flash(mark)
		_finish()
		return
	if _phase != Phase.ECHO:
		return
	_taps.append(mark)
	_flash(mark)
	if not BondEcho.is_on_track(_sequence, _taps) or _taps.size() >= _sequence.size():
		_end_phase()

func _flash(mark: int) -> void:
	_flash_mark = mark
	_flash_left = FLASH_TIME
	_tone(mark)

func _tone(mark: int) -> void:
	var sound: Node = get_node_or_null(^"/root/Sound")
	if sound != null:
		sound.call("mark_tone", int(_plan.get("element", 0)), mark, _plan.get("state", "") == "muted")

## One phase is over: on to the next phase, the afterglow, or the result.
func _end_phase() -> void:
	_all_taps.append(_taps.duplicate())
	var flawless: bool = BondEcho.score(_sequence, _taps) >= 1.0
	if flawless and _phase_index + 1 < (_plan.phases as Array).size():
		_start_phase(_phase_index + 1)
		return
	var after: int = int(_plan.get("afterglow", -1))
	if flawless and after >= 0 and BondEcho.plan_score(_plan, _all_taps, after) >= 1.0:
		_sequence.assign([after])
		_taps.clear()
		_last_lit = -1
		_time = 0.0
		_phase = Phase.AFTER_CALL
		_hint.text = "An afterglow..."
		return
	_finish()

func _finish() -> void:
	if _phase == Phase.IDLE or _phase == Phase.RESULT:
		return
	_score = BondEcho.plan_score(_plan, _all_taps, _afterglow_tap)
	_hint.text = BondEcho.result_words(_score)
	_phase = Phase.RESULT
	_time = 0.0

## Centre of mark [param i] (three marks in a row, lower half of the screen).
func _mark_center(i: int) -> Vector2:
	var step: float = size.x / float(BondEcho.MARKS + 1)
	return Vector2(step * (i + 1), size.y * 0.62)

func _mark_at_point(p: Vector2) -> int:
	for i: int in BondEcho.MARKS:
		if p.distance_to(_mark_center(i)) <= mark_size() * 0.75:
			return i
	return -1

func _gui_input(event: InputEvent) -> void:
	if _phase == Phase.MINE and TapInput.is_press(event):
		# Anywhere counts, so fast tapping never misses the button.
		mine_tap()
		accept_event()
		return
	if TapInput.is_press(event):
		_tap(_mark_at_point(TapInput.position(event)))
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.MINE and event.is_action_pressed("ui_accept"):
		mine_tap()
		get_viewport().set_input_as_handled()
		return
	if _phase != Phase.ECHO and _phase != Phase.AFTER_ECHO:
		return
	if calm and _phase == Phase.AFTER_ECHO and event.is_action_pressed("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()
		return
	var mark: int = -1
	if event.is_action_pressed("ui_left"):
		mark = 0
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_up"):
		mark = 1
	elif event.is_action_pressed("ui_right"):
		mark = 2
	if mark >= 0:
		_tap(mark)
		get_viewport().set_input_as_handled()

func _lit_mark() -> int:
	if _phase == Phase.CALL or _phase == Phase.AFTER_CALL:
		return BondEcho.mark_at(_sequence, _time)
	if _flash_left > 0.0:
		return _flash_mark
	return -1

func _draw() -> void:
	# Opaque paper: the battle HUD behind would show through the marks in the colour eras.
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.BG)
	var look: int = EraBattleHud.rank(era, "bond")
	var c: Dictionary = EraBattleHud.colours(era)
	if look >= 2:
		# Era III on: the whole screen in the era's frame.
		draw_style_box(EraBattleHud.frame_style(era, Color(UITheme.BG, 0.0)), Rect2(Vector2.ZERO, size))
	var state: String = str(_plan.get("state", ""))
	if state == "mended":
		# A glowing frame: the reward for mending the Rift nearby (item 281).
		var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 260.0)
		for k: int in 3:
			draw_rect(Rect2(Vector2(2 + k * 2, 2 + k * 2), size - Vector2(4 + k * 4, 4 + k * 4)), Color(UITheme.ACCENT, pulse * (1.0 - k * 0.3)), false, 1.0)
	if target != null:
		var half := Vector2(target_size(), target_size()) / 2.0
		var at := Vector2(size.x / 2.0, size.y * 0.3)
		var box := Rect2((at - half).round(), half * 2.0)
		if look >= 1:
			# Era II on: the Spirling stands in a box of its own.
			draw_rect(box.grow(3), c.light)
			draw_rect(box.grow(3), UITheme.INK, false, 1.0)
		draw_texture_rect(target, box, false)
		if look >= 2 and not target_name.is_empty():
			var font: Font = get_theme_default_font()
			var fs: int = get_theme_default_font_size()
			var nw: float = font.get_string_size(target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var lh: int = EraBattleHud.line_h(era)
			var plate := Rect2(roundf(at.x - nw / 2.0 - 8.0), box.end.y + 6.0, roundf(nw + 16.0), lh + 4)
			EraBattleHud.draw_plate(self, plate, era, true, lh + 4)
			draw_string(font, Vector2(plate.position.x + 9.0, plate.position.y + 2.0 + EraBattleHud.ascent(era)), target_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c.paper)
	if _phase == Phase.MINE or (_phase == Phase.RESULT and _plan.has("phases") and _mine_needed > 0):
		_draw_mine()
		return
	var lit: int = _lit_mark()
	for i: int in BondEcho.MARKS:
		_draw_mark(i, _mark_center(i).round(), i == lit, state == "muted")
	# Progress pips for the echo (how many taps so far), never odds.
	if _phase == Phase.ECHO:
		var y: float = size.y * 0.62 + mark_size()
		var x0: float = size.x / 2.0 - (_sequence.size() * 6) / 2.0
		for i: int in _sequence.size():
			var filled: bool = i < _taps.size()
			draw_rect(Rect2(x0 + i * 6, y, 4, 4), UITheme.INK if filled else UITheme.DISABLED, filled)

## Outline points of mark [param i]: diamond, square, triangle, or for Lumen and Umbra
## moon, star and spark (item 286). Only the look changes.
static func mark_points(i: int, c: Vector2, r: float, sky: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if sky:
		match i:
			0:  # moon: outer arc, then the inner arc back
				for k: int in 9:
					var a: float = lerpf(-PI * 0.75, PI * 0.75, k / 8.0)
					pts.append(c + Vector2(-cos(a), sin(a)) * r)
				for k: int in 9:
					var a: float = lerpf(PI * 0.6, -PI * 0.6, k / 8.0)
					pts.append(c + Vector2(-r * 0.2 - cos(a) * r * 0.55, sin(a) * r * 0.75))
			1:  # star: five points
				for k: int in 10:
					var a: float = -PI / 2.0 + k * PI / 5.0
					pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
			_:  # spark: four thin rays
				for k: int in 8:
					var a: float = -PI / 2.0 + k * PI / 4.0
					pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.25))
		return pts
	match i:
		0:  # diamond
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		1:  # square
			var s: float = r * 0.8
			pts = PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, s), c + Vector2(-s, s)])
		_:  # triangle
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)])
	return pts

func _draw_mark(i: int, c: Vector2, lit: bool, muted: bool = false) -> void:
	var fill: Color = mark_fill(era, i, lit)
	if muted:
		# Pale lights next to an open Rift (item 280).
		fill = Color(fill, 0.45)
	var r: float = mark_size() / 2.0
	if EraBattleHud.rank(era, "bond") >= 4 and not Juice.reduced() and not lit:
		# Era V: the resting marks breathe by a pixel, each a little after the other.
		r += roundf(sin(Time.get_ticks_msec() / 400.0 + i * 1.3))
	var pts: PackedVector2Array = mark_points(i, c, r, bool(_plan.get("sky", false)))
	draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(UITheme.INK, 0.5) if muted else UITheme.INK, 2.0 if lit and EraBattleHud.rank(era, "bond") >= 3 else 1.0)

## The bar (how close the bond is, a picture not odds) and the big "Mine!" button.
func _draw_mine() -> void:
	var w: float = size.x * 0.6
	var bar := Rect2(Vector2((size.x - w) / 2.0, size.y * 0.47), Vector2(w, 6)).abs()
	draw_rect(bar, UITheme.DISABLED, true)
	draw_rect(Rect2(bar.position, Vector2(w * mine_fill, bar.size.y)), UITheme.INK, true)
	draw_rect(bar, UITheme.INK, false, 1.0)
	var c := Vector2(size.x / 2.0, size.y * 0.72).round()
	var r: float = MINE_SIZE / 2.0
	draw_circle(c, r, UITheme.ACCENT)
	draw_arc(c, r, 0.0, TAU, 32, UITheme.INK, 1.0)
	var font: Font = get_theme_default_font()
	var label: String = Loc.t("Mine!")
	var fs: int = UITheme.FONT_SIZE
	var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-tw / 2.0, fs / 2.0 - 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
