class_name EraMoveFx
extends Control
## Small effects around one Spirling that follow the battle's era (data/era_battle_feel.json
## "move_fx" and the per-era keys "sendout", "hit_mark", "stat_arrows", "faint_motes",
## "fx_steps"): the puff or burst when a Spirling is sent out, the mark where a hit lands, the
## arrows of a stat change and the motes after a faint. Era I/II play in a few hard steps, later
## eras move smoothly. Drawn with whole pixels only. Presentation only, never rules.

const KINDS: Array[String] = ["sendout", "hitmark", "stat_up", "stat_down", "faint_motes"]

var kind: String = ""
var era: int = 1
var info: Dictionary = {}
var _t: float = 0.0
var _held: bool = false

## What [param p_kind] shows in [param p_era]: {"style", "count", "time", "steps", "still"}, or {}
## when the era shows nothing. Under reduced motion only the stat arrows stay, standing still.
static func spec(p_kind: String, p_era: int, reduced: bool = false) -> Dictionary:
	if not p_kind in KINDS:
		return {}
	var base: Dictionary = EraBattleFeel.cfg().get("move_fx", {})
	var stat: bool = p_kind.begins_with("stat_")
	if reduced and not stat:
		return {}
	var style: String = p_kind
	var count: int = 0
	match p_kind:
		"sendout":
			style = EraBattleFeel.text(p_era, "sendout", "")
			count = int((base.get("sendout_parts", {}) as Dictionary).get(style, 0))
		"hitmark":
			style = EraBattleFeel.text(p_era, "hit_mark", "")
			count = int((base.get("hit_mark_parts", {}) as Dictionary).get(style, 0))
		"faint_motes":
			count = int(EraBattleFeel.num(p_era, "faint_motes", 0))
		_:
			count = int(EraBattleFeel.num(p_era, "stat_arrows", 0))
	if style.is_empty() or count <= 0:
		return {}
	return {
		"style": style,
		"count": count,
		"time": float(base.get(("stat" if stat else p_kind) + "_time", 0.3)),
		"steps": int(EraBattleFeel.num(p_era, "fx_steps", 0)),
		"still": reduced,
	}

## Progress [param t] (0..1) in [param steps] hard steps (old eras), unchanged for 0 steps.
static func quant(t: float, steps: int) -> float:
	t = clampf(t, 0.0, 1.0)
	if steps <= 0:
		return t
	return minf(floorf(t * steps) + 1.0, steps) / steps

## How far past the Spirling's rect an effect may draw, in pixels.
static func reach(p_kind: String, size: Vector2) -> float:
	var share: Dictionary = (EraBattleFeel.cfg().get("move_fx", {}) as Dictionary).get("reach", {})
	return roundf(size.x * float(share.get("stat" if p_kind.begins_with("stat_") else p_kind, 0.25)))

## The moving parts of [param p_kind] at progress [param q] inside a Spirling rect of
## [param size] (origin at its top left). Rounded to whole pixels.
static func points(p_kind: String, n: int, q: float, size: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = []
	var c: Vector2 = size / 2.0
	var far: float = reach(p_kind, size)
	for i: int in n:
		var p: Vector2 = c
		match p_kind:
			"sendout", "hitmark":
				var a: float = TAU * i / n + (0.4 if p_kind == "hitmark" else 0.0)
				var r: float = (size.x * (0.2 if p_kind == "sendout" else 0.1) + (size.x * 0.3 + far) * q)
				# Sparks sag a little as they fly, so the burst does not read as a plain ring.
				p = c + Vector2(cos(a), sin(a)) * r + Vector2(0, far * 0.3 * q * q)
			"faint_motes":
				var x: float = size.x * (i + 0.5) / n
				p = Vector2(x + sin(q * PI * 2.0 + i) * 2.0, size.y - 2.0 - (size.y * 0.5 + far) * q * (0.6 + 0.4 * ((i * 7) % 5) / 4.0))
			"stat_up", "stat_down":
				var sx: float = size.x * (i + 0.5) / n
				# Every second arrow runs half a lap ahead, so they stream instead of marching.
				var k: float = fposmod(q + (0.5 if i % 2 == 1 else 0.0), 1.0)
				var y: float = size.y * (1.0 - k) if p_kind == "stat_up" else size.y * k
				p = Vector2(sx, y)
		out.append(p.round())
	return out

## Starts [param p_kind] over the Spirling at [param rect] (in [param parent]'s space). Returns
## null when the era or the reduced-motion setting shows nothing.
static func spawn(parent: Node, p_kind: String, p_era: int, rect: Rect2) -> EraMoveFx:
	var s: Dictionary = spec(p_kind, p_era, Juice.reduced())
	if s.is_empty() or parent == null:
		return null
	var fx := EraMoveFx.new()
	fx.kind = p_kind
	fx.era = clampi(p_era, 1, EraBattleFeel.ERAS)
	fx.info = s
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.position = rect.position
	fx.size = rect.size
	parent.add_child(fx)
	return fx

## Freezes the effect at progress [param t] (screenshots).
func hold(t: float) -> void:
	_held = true
	_t = t
	queue_redraw()

func _process(delta: float) -> void:
	if _held:
		return
	_t += delta * Juice.speed() / maxf(float(info.get("time", 0.3)), 0.01)
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _colour(key: String) -> Color:
	var cols: Dictionary = (EraBattleFeel.cfg().get("move_fx", {}) as Dictionary).get("colours", {})
	if not EraBattleFeel.flag(era, "fx_colour"):
		return UITheme.INK if key != "light" else UITheme.MID
	return Color(str(cols.get(key, "f8f4ec")))

func _dot(p: Vector2, px: int, c: Color) -> void:
	draw_rect(Rect2((p - Vector2(px, px) / 2.0).round(), Vector2(px, px)), c)

func _draw() -> void:
	if info.is_empty():
		return
	var still: bool = bool(info.get("still", false))
	var q: float = 0.5 if still else quant(_t, int(info.get("steps", 0)))
	var n: int = int(info.count)
	var style: String = str(info.style)
	var c: Vector2 = size / 2.0
	var fade: float = 1.0 if still or int(info.get("steps", 0)) > 0 else clampf(1.6 - q * 1.6, 0.0, 1.0)
	var px: int = 3 if era >= 4 else 2
	match kind:
		"sendout":
			var light: Color = Color(_colour("light"), fade)
			var warm: Color = Color(_colour("burst"), fade)
			var pts: PackedVector2Array = points(kind, n, q, size)
			if style.begins_with("puff"):
				for i: int in pts.size():
					_dot(pts[i], px + (1 if i % 2 == 0 else 0), light if i % 2 == 0 else warm)
			else:
				# Rays of light from the centre; later eras add sparks and a ring.
				var rays: int = 8
				for i: int in rays:
					var a: float = TAU * i / rays
					var d := Vector2(cos(a), sin(a))
					draw_line((c + d * size.x * 0.15 * q).round(), (c + d * size.x * (0.2 + 0.4 * q)).round(), light, 1.0)
				draw_rect(Rect2((c - Vector2(2, 2)).round(), Vector2(4, 4)), warm)
				if style != "burst":
					for p: Vector2 in pts:
						_dot(p, 2, warm)
				if style == "burst_ring":
					draw_arc(c.round(), size.x * (0.25 + 0.45 * q), 0.0, TAU, 24, Color(light, fade * 0.8), 1.0)
		"hitmark":
			var hot: Color = Color(_colour("hit"), fade)
			var white: Color = Color(_colour("light"), fade)
			var arm: float = roundf(size.x * (0.1 + 0.12 * q))
			draw_line(c.round() - Vector2(arm, 0), c.round() + Vector2(arm + 1, 0), hot, 1.0 if era < 4 else 2.0)
			draw_line(c.round() - Vector2(0, arm), c.round() + Vector2(0, arm + 1), hot, 1.0 if era < 4 else 2.0)
			if style != "cross":
				var dg: float = roundf(arm * 0.6)
				draw_line(c.round() - Vector2(dg, dg), c.round() + Vector2(dg, dg), white, 1.0)
				draw_line(c.round() + Vector2(-dg, dg), c.round() + Vector2(dg, -dg), white, 1.0)
			if style in ["star_ring", "star_sparks", "star_shards"]:
				draw_arc(c.round(), size.x * (0.12 + 0.2 * q), 0.0, TAU, 16, Color(white, fade * 0.8), 1.0)
			if style in ["star_sparks", "star_shards"]:
				var pts2: PackedVector2Array = points(kind, n, q, size)
				for p: Vector2 in pts2:
					if style == "star_shards":
						draw_line(p, (p + (c - p).normalized() * 4.0).round(), hot, 1.0)
					_dot(p, 2, white)
		"faint_motes":
			var m: Color = Color(_colour("mote"), fade)
			for p: Vector2 in points(kind, n, q, size):
				_dot(p, 2, m)
		"stat_up", "stat_down":
			var up: bool = kind == "stat_up"
			var col: Color = _colour("stat_up" if up else "stat_down")
			var pts3: PackedVector2Array = points(kind, n, q, size)
			var half: int = 2 if era < 4 else 3
			for p: Vector2 in pts3:
				if p.y < 2.0 or p.y > size.y - 2.0:
					continue
				# A chevron: two strokes meeting at the tip, pointing the way the stat moves.
				var tip: Vector2 = p + Vector2(0, -half if up else half)
				var back: float = float(half) if up else float(-half)
				draw_line(tip, tip + Vector2(-half - 1, back + (1 if up else -1)), col, 1.0)
				draw_line(tip, tip + Vector2(half + 1, back + (1 if up else -1)), col, 1.0)
