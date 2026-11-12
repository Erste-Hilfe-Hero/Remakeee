class_name EraFinaleCard
extends EraMomentLayer
## The finale card of an era (data/era_moments.json "finale", docs/ERA_LOOK_TITLE.md): the
## era's title picture with the logo, and under it the closing lines in a frame of that era.
## Each era brings the lines on its own way:
##   I type      typed letter by letter, a 2-frame cursor blinks
##   II scroll   the block scrolls up into the frame in whole pixels
##   III shine   line after line fades in (the logo above has its running light)
##   IV parallax the frame slides in from the side while the picture pans
##   V camera    lines rise and fade in over the drifting scene
## A press shows everything, the next one closes. Reduced motion: everything at once, still.

const TYPE_CPS: float = 28.0
const LINE_GAP: float = 0.9
const LINE_FADE: float = 0.5
const SCROLL_PX: float = 22.0
const SLIDE_TIME: float = 0.6
const START: float = 0.5
## Px between two lines and px kept free for the hint under the frame (times the UI scale).
const LINE_SPACE: float = 3.0
const HINT_H: float = 11.0

var era: int = 1
var _art: EraTitleArt

## Shows the card of [param e] over [param parent]; returns when it closed.
static func play(parent: Node, e: int) -> void:
	var c := EraFinaleCard.new()
	c.era = clampi(e, 1, 5)
	parent.add_child(c)
	await c.finished

## The Era V finale has no era change after it: shows its card once when it is owed.
## [param host] is untyped: the call is deferred and the map may be gone by then.
static func play_if_owed(host: Variant) -> void:
	if not is_instance_valid(host) or not (host as Node).is_inside_tree():
		return
	var e: int = EraManager.NEWEST
	if not EraMoments.card_owed(e, GameState.has_flag):
		return
	GameState.set_flag(EraMoments.CARD_FLAG % e)
	var was_busy: Variant = host.get("busy")
	host.set("busy", true)
	await play(host, e)
	host.set("busy", was_busy)

## Translated lines of the card: the headline, the era's lines and the closing word.
static func lines(e: int) -> Array[String]:
	var f: Dictionary = EraMoments.finale(e)
	var out: Array[String] = [Loc.t(str(f.get("headline", "")))]
	for l: Variant in f.get("lines", []):
		out.append(Loc.t(str(l)))
	out.append(EraMoments.text("the_end" if e >= EraManager.NEWEST else "to_be_continued"))
	return out

## Seconds until every line of [param e] is on screen.
static func full_time(e: int) -> float:
	var kind: String = str(EraMoments.finale(e).get("kind", ""))
	var ls: Array[String] = lines(e)
	if kind == "type":
		var chars: int = 0
		for l: String in ls:
			chars += l.length()
		return START + chars / TYPE_CPS
	return START + ls.size() * LINE_GAP + LINE_FADE

## How line [param i] of a card of [param kind] shows at second [param s]: "a" opacity,
## "dy" px below its place, "chars" letters typed (-1 = all). [param before] = letters of the
## lines above it (the typed card).
static func line_state(kind: String, i: int, s: float, before: int = 0) -> Dictionary:
	var at: float = s - START
	match kind:
		"type":
			var typed: int = int(maxf(at, 0.0) * TYPE_CPS) - before
			return {"a": 1.0 if typed > 0 else 0.0, "dy": 0.0, "chars": maxi(typed, 0)}
		"scroll":
			return {"a": 1.0, "dy": maxf(floorf((i + 1) * LINE_GAP * SCROLL_PX - maxf(at, 0.0) * SCROLL_PX), 0.0), "chars": -1}
		"camera":
			var p: float = clampf((at - i * LINE_GAP) / LINE_FADE, 0.0, 1.0)
			return {"a": p, "dy": (1.0 - p) * 8.0, "chars": -1}
	return {"a": clampf((at - i * LINE_GAP) / LINE_FADE, 0.0, 1.0), "dy": 0.0, "chars": -1}

func build() -> void:
	_art = EraTitleArt.new()
	_art.theme = UITheme.get_theme()
	_art.era = era
	_art.still = reduced
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_art)
	stage.resized.connect(_layout)
	_layout()

## Height the lines need inside the frame at the stage's width.
func lines_height() -> float:
	var k: int = ui_scale(stage.size.x)
	var font: Font = stage.get_theme_default_font()
	var h: float = 12.0 * k
	for l: String in lines(era):
		h += font.get_multiline_string_size(l, HORIZONTAL_ALIGNMENT_CENTER, stage.size.x - 20.0 * k, PixelFont.BASE_SIZE * k).y + LINE_SPACE * k
	return h

## The picture takes what the lines leave, between half and all of its title height.
func _layout() -> void:
	var k: int = ui_scale(stage.size.x)
	var full: float = EraTitleArt.art_height(stage.size.x)
	_art.position = Vector2.ZERO
	_art.size = Vector2(stage.size.x, clampf(stage.size.y - lines_height() - (HINT_H + 7.0) * k, full * 0.5, full))

func panel_rect() -> Rect2:
	var k: int = ui_scale(stage.size.x)
	var top: float = _art.size.y + 3.0 * k
	return Rect2(4.0 * k, top, stage.size.x - 8.0 * k, maxf(stage.size.y - top - (HINT_H + 3.0) * k, 60.0 * k))

func paint(ci: Control) -> void:
	var size: Vector2 = ci.size
	var k: int = ui_scale(size.x)
	var kind: String = str(EraMoments.finale(era).get("kind", ""))
	var s: float = full_time(era) + 1.0 if reduced else t
	var ink: Color = EraMoments.col(era, "ink")
	ci.draw_rect(Rect2(0, _art.size.y, size.x, size.y - _art.size.y), ink)
	var pr: Rect2 = panel_rect()
	if kind == "parallax" and not reduced:
		var left: float = 1.0 - clampf(s / SLIDE_TIME, 0.0, 1.0)
		pr.position.x += left * left * size.x
	EraBackdrop.draw_frame(ci, pr, era)
	var font: Font = ci.get_theme_default_font()
	var fs: int = PixelFont.BASE_SIZE * k
	var width: float = pr.size.x - 12.0 * k
	var y: float = pr.position.y + 6.0 * k
	var before: int = 0
	var ls: Array[String] = lines(era)
	for i: int in ls.size():
		var st: Dictionary = line_state(kind, i, s, before)
		before += ls[i].length()
		var shown: String = ls[i] if int(st.chars) < 0 else ls[i].substr(0, int(st.chars))
		var h: float = font.get_multiline_string_size(ls[i], HORIZONTAL_ALIGNMENT_CENTER, width, fs).y
		var line_y: float = y + float(st.dy) * k
		# The headline and the closing word carry the era's accent.
		var c: Color = EraMoments.col(era, "accent").darkened(0.25) if i == 0 or i == ls.size() - 1 else ink
		if float(st.a) > 0.0 and line_y + h <= pr.end.y - 2.0 * k:
			if kind == "type" and not reduced and int(st.chars) < ls[i].length() and int(s * 4.0) % 2 == 0:
				shown += "_"
			ci.draw_multiline_string(font, Vector2(pr.position.x + 6.0 * k, line_y + PixelFont.ASCENT * k), shown, HORIZONTAL_ALIGNMENT_CENTER, width, fs, -1, Color(c, float(st.a)))
		y += h + LINE_SPACE * k
	if s >= full_time(era):
		var hint: String = EraMoments.text("continue")
		ci.draw_string(font, Vector2(0, size.y - 3.0 * k), hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4.0 * k, PixelFont.BASE_SIZE * fit_scale(font, hint, k, size.x - 8.0 * k), EraMoments.col(era, "paper"))

func press() -> void:
	var full: float = full_time(era)
	if not reduced and t < full:
		t = full
		stage.queue_redraw()
		return
	close()
