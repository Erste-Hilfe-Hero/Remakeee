class_name EraBoot
extends EraMomentLayer
## The boot card, once per app start, in the look of the title's era (data/era_moments.json
## "boot", docs/ERA_LOOK_TITLE.md):
##   I   power on: a drop of ink falls down the blank paper in whole-pixel steps, lands with a
##       chime and spreads into a blot in three frames; the screen then clears in 4 shades
##   II  the blot is in colour and three colour stripes slide in pixel by pixel
##   III a bevelled plate on a banded sky, a light runs over the studio line
##   IV  two half screens slide together and close on the line
##   V   the living lake drifts behind a glossy card that eases in
## A press skips it. With reduced motion every era shows one still card.

const REDUCED_TIME: float = 0.8
## Era I: the drop moves this many px every DROP_STEP seconds.
const DROP_PX: float = 4.0
const DROP_STEP: float = 0.04
const LAND_AT: float = 0.9
const BLOT_FRAMES: Array[float] = [3.0, 7.0, 11.0]
const BLOT_FRAME_TIME: float = 0.12
const TEXT_AT: float = 1.3
const FADE_STEPS: int = 4
const FADE_TIME: float = 0.32
## The second the still card of reduced motion shows: every kind has arrived by then.
const STILL_AT: float = 60.0

## True once the card ran in this app start.
static var shown: bool = false

var era: int = 1
var _rang: bool = false

## Shows the boot card of [param e] over [param parent]; null when it already ran or there is
## no screen (tests, the dedicated server).
static func start(parent: Node, e: int) -> EraBoot:
	if shown or DisplayServer.get_name() == "headless":
		return null
	shown = true
	var b := EraBoot.new()
	b.era = clampi(e, 1, 5)
	parent.add_child(b)
	return b

func total() -> float:
	return REDUCED_TIME if reduced else float(EraMoments.boot(era).get("time", 2.0))

## Era I: y of the falling drop at second [param s], from above the screen to [param land_y].
static func drop_y(s: float, land_y: float) -> float:
	var steps: float = floorf(s / DROP_STEP)
	var from: float = land_y - floorf(LAND_AT / DROP_STEP) * DROP_PX
	return minf(from + steps * DROP_PX, land_y)

## Radius of the blot at second [param s] (0 before the drop lands; three held frames).
static func blot_radius(s: float) -> float:
	if s < LAND_AT:
		return 0.0
	return BLOT_FRAMES[mini(int((s - LAND_AT) / BLOT_FRAME_TIME), BLOT_FRAMES.size() - 1)]

## Opacity of the card at second [param s] of [param length]: full, then FADE_STEPS even
## steps down over the last FADE_TIME seconds (the 4-shade fade of the first handhelds).
static func fade_alpha(s: float, length: float) -> float:
	var left: float = length - s
	if left >= FADE_TIME:
		return 1.0
	return clampf(floorf(left / FADE_TIME * FADE_STEPS) / FADE_STEPS, 0.0, 1.0)

func step() -> void:
	if not _rang and (reduced or t >= (LAND_AT if era == 1 else 0.35)):
		_rang = true
		Sound.sfx(str(EraMoments.boot(era).get("sound", "confirm")))
	# Era I and II clear in four hard steps; later eras fade smoothly.
	stage.modulate.a = fade_alpha(t, total()) if era <= 2 or reduced else smoothstep(0.0, 1.0, (total() - t) / FADE_TIME)
	if t >= total():
		close()

func paint(ci: Control) -> void:
	var size: Vector2 = ci.size
	var k: int = ui_scale(size.x)
	var paper: Color = EraMoments.col(era, "paper")
	var ink: Color = EraMoments.col(era, "ink")
	var c: Vector2 = (size / 2.0).floor()
	var font: Font = ci.get_theme_default_font()
	var line: String = EraMoments.text("studio")
	# The line is drawn at the screen's UI scale, or one smaller when it would not fit.
	if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE * k).x + 12.0 * k > size.x:
		k = 1
	var fs: int = PixelFont.BASE_SIZE * k
	var lw: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var card := Rect2(roundf(c.x - lw / 2.0) - 5 * k, c.y + 14 * k, lw + 10 * k, fs + 12 * k)
	var text_at := Vector2(roundf(c.x - lw / 2.0), card.position.y + 6 * k + PixelFont.ASCENT * k)
	# Reduced motion: the finished card, nothing on the way there.
	var s: float = STILL_AT if reduced else t
	match str(EraMoments.boot(era).get("kind", "")):
		"ink_drop":
			ci.draw_rect(Rect2(Vector2.ZERO, size), paper)
			if s < LAND_AT:
				_drop(ci, Vector2(c.x, drop_y(s, c.y - 6)), ink, 1.0)
			_blot(ci, c - Vector2(0, 6), blot_radius(s), ink)
			if s >= TEXT_AT:
				ci.draw_string(font, text_at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		"wash_card":
			ci.draw_rect(Rect2(Vector2.ZERO, size), paper)
			var cols: Array[Color] = [EraMoments.col(era, "sky_top"), EraMoments.col(era, "accent"), EraMoments.col(era, "mid")]
			for i: int in cols.size():
				# Stripes slide in from the left, 3 px a step, one after the other.
				var w: float = clampf(floorf((s - i * 0.15) / 0.03) * 3.0, 0.0, size.x)
				ci.draw_rect(Rect2(0, c.y - 30 + i * 5, w, 4), cols[i])
			_blot(ci, c - Vector2(0, 6), BLOT_FRAMES[2], EraMoments.col(era, "water"))
			_drop(ci, c - Vector2(0, 9), paper, 1.0)
			# A 2-frame twinkle.
			if int(s / 0.25) % 2 == 0:
				ci.draw_rect(Rect2(c.x + 12, c.y - 20, 1, 3), cols[1])
				ci.draw_rect(Rect2(c.x + 11, c.y - 19, 3, 1), cols[1])
			if s >= 0.6:
				EraBackdrop.draw_frame(ci, card, era)
				ci.draw_string(font, text_at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		"shine_card":
			EraBackdrop.paint(ci, Rect2(Vector2.ZERO, size), era, 0.0, true)
			ci.draw_rect(Rect2(Vector2.ZERO, size), Color(ink, 0.45))
			EraBackdrop.draw_frame(ci, card, era)
			ci.draw_string(font, text_at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			# The light runs once over the line.
			var at: float = text_at.x + (s - 0.4) / 0.9 * lw
			if not reduced and at > text_at.x - 6 and at < text_at.x + lw:
				ci.draw_rect(Rect2(at, card.position.y + 2, 3, card.size.y - 4), Color(1, 1, 1, 0.7))
				ci.draw_rect(Rect2(at + 5, card.position.y + 2, 1, card.size.y - 4), Color(1, 1, 1, 0.5))
			_drop(ci, c - Vector2(0, 8), EraMoments.col(era, "sun"), 2.0)
		"fold_card":
			# Two shutters, one per half screen, open on the scene; the line sits on the seam.
			var p: float = clampf(s / 0.8, 0.0, 1.0)
			p = 1.0 - (1.0 - p) * (1.0 - p)
			var half: float = size.y / 2.0
			EraBackdrop.paint(ci, Rect2(Vector2.ZERO, size), era, 0.0, true)
			ci.draw_rect(Rect2(0, 0, size.x, half * (1.0 - p)), ink)
			ci.draw_rect(Rect2(0, size.y - half * (1.0 - p), size.x, half * (1.0 - p)), ink)
			ci.draw_rect(Rect2(0, half - 1, size.x, 2), Color(ink, 1.0 - p))
			if s >= 0.5:
				card.position.y = c.y - card.size.y / 2.0
				EraBackdrop.draw_frame(ci, card, era)
				ci.draw_string(font, Vector2(text_at.x, card.position.y + 6 * k + PixelFont.ASCENT * k), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
				_drop(ci, Vector2(c.x, card.position.y - 14 * k), EraMoments.col(era, "sun"), 2.0 * k)
		_:
			EraBackdrop.paint(ci, Rect2(Vector2.ZERO, size), era, t * 2.0, reduced)
			var p: float = clampf((s - 0.3) / 0.6, 0.0, 1.0)
			p = 1.0 - (1.0 - p) * (1.0 - p)
			ci.draw_rect(Rect2(Vector2.ZERO, size), Color(ink, 0.35 * p))
			if p > 0.0:
				var grown := card.grow(-(1.0 - p) * 6.0 * k)
				ci.draw_set_transform(Vector2(0, (1.0 - p) * 10.0 * k), 0.0, Vector2.ONE)
				EraBackdrop.draw_frame(ci, grown, era)
				ci.draw_string(font, text_at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, p))
				_drop(ci, c - Vector2(0, 10 * k), EraMoments.col(era, "accent"), 2.0 * k)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The studio mark: one drop of ink, drawn from rows of pixels.
static func _drop(ci: CanvasItem, at: Vector2, c: Color, s: float) -> void:
	var rows: Array[int] = [1, 1, 3, 3, 5, 5, 3]
	for i: int in rows.size():
		ci.draw_rect(Rect2(roundf(at.x - rows[i] * s / 2.0), roundf(at.y + (i - 4) * s), rows[i] * s, s), c)

## The blot the drop leaves: a rough disc with splash dots around it.
static func _blot(ci: CanvasItem, at: Vector2, radius: float, c: Color) -> void:
	if radius <= 0.0:
		return
	var r: int = int(radius)
	for y: int in range(-r, r + 1):
		var half: float = floorf(sqrt(float(r * r - y * y)) + ((y * 7) % 3) * 0.5)
		ci.draw_rect(Rect2(at.x - half, at.y + y * 0.6, half * 2.0, 1), c)
	for i: int in 6:
		var ang: float = i * 1.05 + 0.4
		ci.draw_rect(Rect2((at + Vector2(cos(ang), sin(ang) * 0.6) * (radius + 3.0 + i % 2 * 2.0)).round(), Vector2(1 + i % 2, 1)), c)
