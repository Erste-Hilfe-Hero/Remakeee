class_name SpirlingAura
extends Control
## Small marks around a battle Spirling, drawn in whole pixels (docs/KAMPF_PLAN_1000.md):
## - status motes (647): sparks rise off a Scorched Spirling, drops fall off a Soaked one, a
##   Rooted one stands in still chain links (item 187), and so on (data/battle_show.json "status_motes");
## - the stage aura (648): a dotted ring at the feet, warm while its stages add up above zero,
##   cool below; it turns slowly and never blinks;
## - the lantern light (650): a warm glow at the feet as it steps out, no ball, no throw.
## Era I and high contrast draw in the palette's ink and accent, later eras in the status colour
## (668, 669). Reduced motion keeps every mark still. The marks only move in STEPS whole steps a
## period, so the node redraws a few times a second, not every frame (664).

const STEPS: int = 8

var status: String = ""
## 1 when the stages add up above zero, -1 below, 0 for none.
var stage_dir: int = 0
var era: int = 1
## Lantern glow strength, 0 when off.
var lantern: float = 0.0
var _t: float = 0.0
var _step: int = -1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)

## Shows [param p_status] and the aura of [param stages] (a Spirling's stat stages).
func set_state(p_status: String, stages: Dictionary) -> void:
	status = p_status if mote_spec(p_status).size() > 0 else ""
	stage_dir = stage_dir_of(stages)
	set_process(status != "" or stage_dir != 0)
	queue_redraw()

## The warm light at the feet that fades as the Spirling steps out. Never waited for.
func glow_lantern() -> void:
	var cfg: Dictionary = BattleShow.cfg().get("lantern", {})
	lantern = float(cfg.get("alpha", 0.55))
	queue_redraw()
	if not is_inside_tree():
		return
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void:
		lantern = v
		queue_redraw(), lantern, 0.0, float(cfg.get("time", 0.5)) / Juice.speed()).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	if Juice.reduced():
		return
	_t += delta * Juice.speed()
	var s: int = int(floorf(phase(_t) * STEPS))
	if s != _step:
		_step = s
		queue_redraw()

## Share (0..1) of the mote period at [param t] seconds.
static func phase(t: float) -> float:
	var period: float = maxf(float(BattleShow.cfg().get("mote_period", 1.4)), 0.1)
	return fposmod(t, period) / period

## Sign of the sum of [param stages] (stat -> stage).
static func stage_dir_of(stages: Dictionary) -> int:
	var sum: int = 0
	for k: Variant in stages:
		sum += int(stages[k])
	return signi(sum)

## data/battle_show.json "status_motes" entry of [param p_status] ({} for none).
static func mote_spec(p_status: String) -> Dictionary:
	var m: Variant = (BattleShow.cfg().get("status_motes", {}) as Dictionary).get(p_status, {})
	return m if m is Dictionary else {}

## Colour of a status mote: ink in Era I and in high contrast, else the status colour.
static func mote_color(spec: Dictionary, p_era: int, hc: bool) -> Color:
	if p_era <= 1 or hc or not spec.has("color"):
		return UITheme.INK
	return Color(str(spec.color))

## Aura colour for [param dir]: Era I and high contrast use the palette's mid tone (up) and ink
## (down), later eras the warm and cool colours of the data.
static func aura_color(dir: int, p_era: int, hc: bool) -> Color:
	if p_era <= 1 or hc:
		return UITheme.MID if dir > 0 else UITheme.INK
	var a: Dictionary = BattleShow.cfg().get("aura", {})
	return Color(str(a.get("up" if dir > 0 else "down", "ffffff")))

## Whole-pixel spots of [param count] motes over a sprite of [param box] at period share [param q].
## drift -1 rises from the chest to the head, 1 falls from the head to the chest, 0 circles
## above the head.
static func mote_points(drift: int, count: int, q: float, box: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in count:
		var k: float = fposmod(q + float(i) / maxf(count, 1), 1.0)
		var p := Vector2.ZERO
		if drift == 2:
			# Still links round the feet (Root, item 187): they do not move, so motion never matters.
			var x2: float = box.x * (0.2 + 0.6 * float(i) / maxf(count - 1, 1))
			out.append(Vector2(x2, box.y - 3.0 + (i % 2)).round())
			continue
		if drift == 0:
			var a: float = TAU * k
			p = Vector2(box.x / 2.0 + cos(a) * box.x * 0.3, box.y * 0.08 + sin(a) * 2.0)
		else:
			var x: float = box.x * (0.25 + 0.5 * (float(i) + 0.5) / maxf(count, 1))
			var y0: float = box.y * 0.55
			var y1: float = box.y * 0.05
			p = Vector2(x, lerpf(y0, y1, k) if drift < 0 else lerpf(y1, y0, k))
		out.append(p.round())
	return out

## Whole-pixel dots of the stage ring at the feet of a sprite of [param box], turned by [param q].
static func aura_points(dots: int, q: float, box: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := Vector2(box.x / 2.0, box.y - 2.0)
	for i: int in dots:
		var a: float = TAU * (float(i) / maxf(dots, 1) + q)
		out.append((c + Vector2(cos(a) * box.x * 0.42, sin(a) * 3.0)).round())
	return out

func _q() -> float:
	return 0.25 if Juice.reduced() else float(maxi(_step, 0)) / STEPS

func _draw() -> void:
	var hc: bool = UITheme.high_contrast
	if lantern > 0.0:
		var lc := Color(str((BattleShow.cfg().get("lantern", {}) as Dictionary).get("color", "f2c870")))
		if hc or era <= 1:
			lc = UITheme.ACCENT
		lc.a = lantern
		var w: int = int(size.x * 0.7)
		for row: int in 4:
			var inset: int = [w / 3, w / 6, w / 12, 0][row]
			# Dithered: every second pixel, offset per row, keeps the pixel look.
			for x: int in range(inset + row % 2, w - inset, 2):
				draw_rect(Rect2(int((size.x - w) / 2.0) + x, size.y - 4 + row - 2, 1, 1), lc)
	if stage_dir != 0:
		var a: Dictionary = BattleShow.cfg().get("aura", {})
		var c: Color = aura_color(stage_dir, era, hc)
		for p: Vector2 in aura_points(int(a.get("dots", 10)), _q() * (1.0 if stage_dir > 0 else -1.0), size):
			draw_rect(Rect2(p, Vector2(1, 1)), c)
	var spec: Dictionary = mote_spec(status)
	if spec.is_empty():
		return
	var mc: Color = mote_color(spec, era, hc)
	for p: Vector2 in mote_points(int(spec.get("drift", -1)), int(spec.get("count", 2)), _q(), size):
		_draw_mote(str(spec.get("shape", "spark")), p, mc)

func _draw_mote(shape: String, p: Vector2, c: Color) -> void:
	var dots: Array = []
	match shape:
		"spark": dots = [[0, -1], [-1, 0], [0, 0], [1, 0], [0, 1]]
		"drop": dots = [[0, -1], [0, 0], [-1, 1], [0, 1], [1, 1]]
		"leaf": dots = [[1, -1], [0, 0], [1, 0], [-1, 1]]
		"zig": dots = [[-1, -1], [0, -1], [0, 0], [0, 1], [1, 1]]
		"ring": dots = [[0, -1], [-1, 0], [1, 0], [0, 1]]
		"z": dots = [[-1, -1], [0, -1], [1, -1], [0, 0], [-1, 1], [0, 1], [1, 1]]
		"chain": dots = [[-1, -1], [0, -1], [1, -1], [-2, 0], [2, 0], [-1, 1], [0, 1], [1, 1], [3, 0]]
		_: dots = [[0, 0]]
	for d: Array in dots:
		draw_rect(Rect2(p + Vector2(d[0], d[1]), Vector2(1, 1)), c)
