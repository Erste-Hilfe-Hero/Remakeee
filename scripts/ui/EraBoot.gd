class_name EraBoot
extends EraMomentLayer
## The boot card, once per app start, in the look of the title's era (data/era_moments.json
## "boot", docs/ERA_LOOK_TITLE.md). Every card is at most 2 s long:
##   I   power on: a drop of ink falls down the blank paper in whole-pixel steps, lands with a
##       chime and a splash crown, spreads into a blot in three frames and then into a brush
##       stroke; the CHIMORA wordmark is stamped into it letter by letter, the studio line
##       follows; the screen then clears in 4 shades
##   II  the blot is in colour and three colour stripes slide in pixel by pixel
##   III a bevelled plate on a banded sky, a light runs over the studio line
##   IV  two half screens slide together and close on the line
##   V   the living lake drifts behind a glossy card that eases in
## A single press skips it at any second. With reduced motion every era shows one still card.

const REDUCED_TIME: float = 0.8
## Era I: the drop moves this many px every DROP_STEP seconds.
const DROP_PX: float = 4.0
const DROP_STEP: float = 0.025
const LAND_AT: float = 0.55
const BLOT_FRAMES: Array[float] = [3.0, 7.0, 11.0]
const BLOT_FRAME_TIME: float = 0.1
## Era I: the blot spreads into a stroke behind the wordmark in BAND_STEPS held frames.
const BAND_AT: float = 0.8
const BAND_STEP: float = 0.035
const BAND_STEPS: int = 5
## Era I: the wordmark letters are stamped from the middle outwards, one pair per LETTER_STEP.
const LETTERS_AT: float = 1.0
const LETTER_STEP: float = 0.045
const TEXT_AT: float = 1.2
const FADE_STEPS: int = 4
const FADE_TIME: float = 0.32
## The second the still card of reduced motion shows: every kind has arrived by then.
const STILL_AT: float = 60.0
## Room the studio card keeps to the screen edges, in px per UI scale (5 inside the card, 1 out).
const LINE_MARGIN: float = 12.0
## Pixels between the two rows of a broken studio line, per UI scale.
const LINE_GAP: int = 2

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

## How far the stroke behind the wordmark has spread at second [param s]: 0 before BAND_AT,
## then BAND_STEPS held steps up to 1.
static func band_part(s: float) -> float:
	if s < BAND_AT:
		return 0.0
	return minf(floorf((s - BAND_AT) / BAND_STEP + 1.0) / BAND_STEPS, 1.0)

## True when letter [param i] of a [param n] letter wordmark is stamped at second [param s]:
## the middle letter first, then the pairs to each side.
static func letter_shown(i: int, n: int, s: float) -> bool:
	var rank: int = absi(2 * i - (n - 1)) / 2
	return s >= LETTERS_AT + rank * LETTER_STEP

## Opacity of the card at second [param s] of [param length]: full, then FADE_STEPS even
## steps down over the last FADE_TIME seconds (the 4-shade fade of the first handhelds).
static func fade_alpha(s: float, length: float) -> float:
	var left: float = length - s
	if left >= FADE_TIME:
		return 1.0
	return clampf(floorf(left / FADE_TIME * FADE_STEPS) / FADE_STEPS, 0.0, 1.0)

## Splits [param line] into two rows at the space nearest its middle (no space: unchanged).
static func split_line(line: String) -> String:
	var mid: int = line.length() / 2
	var best: int = -1
	for i: int in line.length():
		if line[i] == " " and (best < 0 or absi(i - mid) < absi(best - mid)):
			best = i
	return line if best < 0 else line.substr(0, best) + "\n" + line.substr(best + 1)

static func _line_w(font: Font, text: String, k: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE * k).x

## Where the studio line goes on a screen of [param size]: {k, fs, lines, width, card}. The line
## is drawn at the screen's UI scale, one smaller when it would not fit, and broken into two
## rows at the middle space when even the plain size is too wide. German needs 149 px and a
## 390 pt iPhone shows 146 (ScreenFit: 1170 px / scale 8), so before 28 Nov the line ran off
## both edges there; French, Dutch, Polish, Turkish and Spanish are wider still.
static func line_layout(font: Font, line: String, size: Vector2) -> Dictionary:
	var k: int = ui_scale(size.x)
	while k > 1 and _line_w(font, line, k) + LINE_MARGIN * k > size.x:
		k -= 1
	var lines: PackedStringArray = [line]
	if _line_w(font, line, k) + LINE_MARGIN * k > size.x:
		lines = split_line(line).split("\n")
	var fs: int = PixelFont.BASE_SIZE * k
	var lw: float = 0.0
	for l: String in lines:
		lw = maxf(lw, _line_w(font, l, k))
	var h: float = fs * lines.size() + LINE_GAP * k * (lines.size() - 1)
	var c: Vector2 = (size / 2.0).floor()
	var card := Rect2(roundf(c.x - lw / 2.0) - 5 * k, c.y + 14 * k, lw + 10 * k, h + 12 * k)
	return {"k": k, "fs": fs, "lines": lines, "width": lw, "card": card}

## Draws the rows of [param lay] inside [param card], each centred.
static func draw_lines(ci: CanvasItem, font: Font, lay: Dictionary, card: Rect2, col: Color) -> void:
	var k: int = lay.k
	var fs: int = lay.fs
	var lines: PackedStringArray = lay.lines
	for i: int in lines.size():
		var w: float = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(roundf(card.get_center().x - w / 2.0), card.position.y + 6 * k + PixelFont.ASCENT * k + i * (fs + LINE_GAP * k))
		ci.draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## Era I: pixel scale of the wordmark on a screen [param width] px wide (the title's scale, one
## smaller while the stroke around it would not fit).
static func logo_scale(font: Font, width: float) -> int:
	var k: int = EraTitleArt.logo_scale(width)
	while k > 1 and font.get_string_size(TitleArt.LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE * k).x + 4.0 * k + 8.0 > width:
		k -= 1
	return k

## Era I: the full stroke behind the wordmark, centred on [param at].
static func band_rect(font: Font, width: float, at: Vector2) -> Rect2:
	var k: int = logo_scale(font, width)
	var lw: float = font.get_string_size(TitleArt.LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE * k).x
	var size := Vector2(roundf(lw + 4.0 * k), PixelFont.ASCENT * k + 3.0 * k)
	return Rect2((at - size / 2.0).round(), size)

func step() -> void:
	if not _rang and (reduced or t >= (LAND_AT if era == 1 else 0.35)):
		_rang = true
		Sound.sfx(str(EraMoments.boot(era).get("sound", "confirm")))
		# The drop lands with a light tap in the hand (off with reduced motion or Vibration Off).
		if era == 1 and not reduced:
			Haptics.play("tap")
	# Era I and II clear in four hard steps; later eras fade smoothly.
	stage.modulate.a = fade_alpha(t, total()) if era <= 2 or reduced else smoothstep(0.0, 1.0, (total() - t) / FADE_TIME)
	if t >= total():
		close()

func paint(ci: Control) -> void:
	var size: Vector2 = ci.size
	var paper: Color = EraMoments.col(era, "paper")
	var ink: Color = EraMoments.col(era, "ink")
	var c: Vector2 = (size / 2.0).floor()
	var font: Font = ci.get_theme_default_font()
	var lay: Dictionary = line_layout(font, EraMoments.text("studio"), size)
	var k: int = lay.k
	var lw: float = lay.width
	var card: Rect2 = lay.card
	var text_x: float = roundf(c.x - lw / 2.0)
	# Reduced motion: the finished card, nothing on the way there.
	var s: float = STILL_AT if reduced else t
	match str(EraMoments.boot(era).get("kind", "")):
		"ink_drop":
			ci.draw_rect(Rect2(Vector2.ZERO, size), paper)
			var land := Vector2(c.x, c.y - 12)
			var band: Rect2 = band_rect(font, size.x, land)
			if s < LAND_AT:
				var y: float = drop_y(s, land.y)
				# Two specks of the drop's wake: it falls fast.
				ci.draw_rect(Rect2(c.x, y - 9, 1, 1), ink)
				ci.draw_rect(Rect2(c.x, y - 14, 1, 1), EraMoments.col(era, "mid"))
				_drop(ci, Vector2(c.x, y), ink, 1.0)
			else:
				_crown(ci, land, s - LAND_AT, ink)
			var part: float = band_part(s)
			if part <= 0.0:
				_blot(ci, land, blot_radius(s), ink)
			else:
				_band(ci, band, part, ink)
				_stamp(ci, font, band, s, era)
			if s >= TEXT_AT:
				card.position.y = band.end.y + 8
				draw_lines(ci, font, lay, card, ink)
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
				draw_lines(ci, font, lay, card, ink)
		"shine_card":
			EraBackdrop.paint(ci, Rect2(Vector2.ZERO, size), era, 0.0, true)
			ci.draw_rect(Rect2(Vector2.ZERO, size), Color(ink, 0.45))
			EraBackdrop.draw_frame(ci, card, era)
			draw_lines(ci, font, lay, card, ink)
			# The light runs once over the line.
			var at: float = text_x + (s - 0.4) / 0.9 * lw
			if not reduced and at > text_x - 6 and at < text_x + lw:
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
				draw_lines(ci, font, lay, card, ink)
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
				draw_lines(ci, font, lay, card, Color(ink, p))
				_drop(ci, c - Vector2(0, 10 * k), EraMoments.col(era, "accent"), 2.0 * k)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Era I: the splash crown the drop throws up when it lands, [param since] seconds ago: six
## specks fly out and up in three held frames, then fall back to the paper.
static func _crown(ci: CanvasItem, at: Vector2, since: float, c: Color) -> void:
	var f: int = int(since / BLOT_FRAME_TIME)
	if f > 2:
		return
	for i: int in 6:
		var side: float = -1.0 if i < 3 else 1.0
		var out: float = 5.0 + (i % 3) * 3.0 + f * 3.0
		var up: float = [4.0, 6.0, 3.0][f] - (i % 3) * 1.0
		ci.draw_rect(Rect2((at + Vector2(side * out, -up)).round(), Vector2(1 + (i % 2), 1 + (i % 2))), c)

## Era I: the brush stroke, [param part] (0..1) of [param full] spread out from the middle, with
## rough top and bottom edges like ink on paper.
static func _band(ci: CanvasItem, full: Rect2, part: float, c: Color) -> void:
	var w: float = roundf(lerpf(22.0, full.size.x, part) / 2.0) * 2.0
	var h: float = roundf(lerpf(13.0, full.size.y, minf(part * 2.0, 1.0)))
	var mid: Vector2 = full.get_center()
	var left: float = roundf(mid.x - w / 2.0)
	var top: float = roundf(mid.y - h / 2.0)
	ci.draw_rect(Rect2(left, top + 1, w, h - 2), c)
	# Ragged edges: every pixel column reaches 0..2 px further up or down.
	for x: int in int(w):
		var up: int = (x * 7 + 3) % 5 / 2
		var down: int = (x * 11 + 1) % 5 / 2
		ci.draw_rect(Rect2(left + x, top + 1 - up, 1, up), c)
		ci.draw_rect(Rect2(left + x, top + h - 1, 1, down), c)
	# The stroke ends in a dry tip on each side.
	ci.draw_rect(Rect2(left - 2, mid.y - 1, 2, 3), c)
	ci.draw_rect(Rect2(left + w, mid.y - 2, 2, 3), c)

## Era I: the wordmark stamped into the stroke in paper letters with a shadow, letter by letter.
## A letter shows in the accent ink for its first frame, as if still wet.
static func _stamp(ci: CanvasItem, font: Font, band: Rect2, s: float, e: int) -> void:
	var k: int = int(roundf((band.size.y) / (PixelFont.ASCENT + 3.0)))
	var fs: int = PixelFont.BASE_SIZE * k
	var logo: String = TitleArt.LOGO
	var width: float = font.get_string_size(logo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x: float = roundf(band.get_center().x - width / 2.0)
	var y: float = band.position.y + roundf(1.5 * k) + PixelFont.ASCENT * k
	var shadow: Color = EraMoments.col(e, "mid")
	var paper: Color = EraMoments.col(e, "paper")
	var wet: Color = EraMoments.col(e, "accent")
	for i: int in logo.length():
		var ch: String = logo[i]
		var cw: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if letter_shown(i, logo.length(), s):
			var fresh: bool = not letter_shown(i, logo.length(), s - LETTER_STEP)
			ci.draw_string(font, Vector2(x + k, y + k), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shadow)
			ci.draw_string(font, Vector2(x, y - (1 if fresh else 0)), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, wet if fresh else paper)
		x += cw

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
