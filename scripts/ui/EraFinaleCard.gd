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
## Lines that do not fit the frame (a long translation on a 16:9 phone) go on a next page: a
## press then turns the page and only the last page's press closes (before 1.3.2 they were cut).

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
## The page shown: an index into pages.
var page: int = 0
## Line ranges [x, y) of lines(era) that fit the frame together, set by the layout.
var pages: Array[Vector2i] = []
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
	# Wait for the warp that loaded the map: busy taken mid-fade and given back after the card
	# froze the Wayfarer for good once the warp had ended (1.3.2).
	var tree: SceneTree = (host as Node).get_tree()
	while is_instance_valid(host) and (host as Node).is_inside_tree() and bool(host.get("busy")):
		await tree.process_frame
	if not is_instance_valid(host) or not (host as Node).is_inside_tree() or not EraMoments.card_owed(e, GameState.has_flag):
		return
	GameState.set_flag(EraMoments.CARD_FLAG % e)
	host.set("busy", true)
	await play(host, e)
	if is_instance_valid(host):
		host.set("busy", false)

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
	return lines_time(str(EraMoments.finale(e).get("kind", "")), lines(e))

## Seconds until all of [param ls] are on screen on a card of [param kind].
static func lines_time(kind: String, ls: Array[String]) -> float:
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
	var pr: Rect2 = panel_rect()
	var font: Font = stage.get_theme_default_font()
	var heights: Array[float] = []
	for l: String in lines(era):
		heights.append(font.get_multiline_string_size(l, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x - 12.0 * k, PixelFont.BASE_SIZE * k).y)
	pages = page_ranges(heights, pr.size.y - 8.0 * k, LINE_SPACE * k)
	page = mini(page, pages.size() - 1)

## Groups lines of [param heights] into pages whose lines fit [param room] px with [param gap]
## px between them; a page always takes at least one line.
static func page_ranges(heights: Array[float], room: float, gap: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var from: int = 0
	var y: float = 0.0
	for i: int in heights.size():
		if i > from and y + heights[i] > room:
			out.append(Vector2i(from, i))
			from = i
			y = 0.0
		y += heights[i] + gap
	out.append(Vector2i(from, heights.size()))
	return out

## Lines of the page shown.
func page_lines() -> Array[String]:
	var r: Vector2i = pages[page] if page < pages.size() else Vector2i(0, lines(era).size())
	return lines(era).slice(r.x, r.y)

## Seconds until every line of the page shown is on screen.
func page_time() -> float:
	return lines_time(str(EraMoments.finale(era).get("kind", "")), page_lines())

func panel_rect() -> Rect2:
	var k: int = ui_scale(stage.size.x)
	var top: float = _art.size.y + 3.0 * k
	return Rect2(4.0 * k, top, stage.size.x - 8.0 * k, maxf(stage.size.y - top - (HINT_H + 3.0) * k, 60.0 * k))

func paint(ci: Control) -> void:
	var size: Vector2 = ci.size
	var k: int = ui_scale(size.x)
	var kind: String = str(EraMoments.finale(era).get("kind", ""))
	var s: float = page_time() + 1.0 if reduced else t
	var ink: Color = EraMoments.col(era, "ink")
	ci.draw_rect(Rect2(0, _art.size.y, size.x, size.y - _art.size.y), ink)
	var pr: Rect2 = panel_rect()
	if kind == "parallax" and not reduced and page == 0:
		var left: float = 1.0 - clampf(s / SLIDE_TIME, 0.0, 1.0)
		pr.position.x += left * left * size.x
	EraBackdrop.draw_frame(ci, pr, era)
	var font: Font = ci.get_theme_default_font()
	var fs: int = PixelFont.BASE_SIZE * k
	var width: float = pr.size.x - 12.0 * k
	var y: float = pr.position.y + 6.0 * k
	var before: int = 0
	var all: Array[String] = lines(era)
	var first: int = pages[page].x if page < pages.size() else 0
	var ls: Array[String] = page_lines()
	for i: int in ls.size():
		var st: Dictionary = line_state(kind, i, s, before)
		before += ls[i].length()
		var shown: String = ls[i] if int(st.chars) < 0 else ls[i].substr(0, int(st.chars))
		var h: float = font.get_multiline_string_size(ls[i], HORIZONTAL_ALIGNMENT_CENTER, width, fs).y
		var line_y: float = y + float(st.dy) * k
		# The headline and the closing word carry the era's accent.
		var c: Color = EraMoments.col(era, "accent").darkened(0.25) if first + i == 0 or first + i == all.size() - 1 else ink
		if float(st.a) > 0.0 and line_y + h <= pr.end.y - 2.0 * k:
			if kind == "type" and not reduced and int(st.chars) < ls[i].length() and int(s * 4.0) % 2 == 0:
				shown += "_"
			ci.draw_multiline_string(font, Vector2(pr.position.x + 6.0 * k, line_y + PixelFont.ASCENT * k), shown, HORIZONTAL_ALIGNMENT_CENTER, width, fs, -1, Color(c, float(st.a)))
		y += h + LINE_SPACE * k
	if s >= page_time():
		var hint: String = EraMoments.text("continue")
		ci.draw_string(font, Vector2(0, size.y - 3.0 * k), hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4.0 * k, PixelFont.BASE_SIZE * fit_scale(font, hint, k, size.x - 8.0 * k), EraMoments.col(era, "paper"))

func press() -> void:
	var full: float = page_time()
	if not reduced and t < full:
		t = full
		stage.queue_redraw()
		return
	if page < pages.size() - 1:
		page += 1
		t = 0.0
		stage.queue_redraw()
		return
	close()
