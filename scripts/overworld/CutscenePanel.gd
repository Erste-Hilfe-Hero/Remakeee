class_name CutscenePanel
extends Control
## A picture panel for story cut-scenes (ScenePlayer step "panel", docs/STORY.md "Cut-scenes"),
## drawn in code in the look of an era (docs/ERA_LOOK_TITLE.md): the era's landscape from
## EraBackdrop or a plain sheet, one motif of the story moment on top, the era's frame around
## it. The era also sets the cadence: Era I redraws twice a second, Era II four times, Era III
## twelve times, from Era IV every frame. With reduced motion the motif stands finished and
## nothing moves. No text and no image files: everything is primitives in the era's colours.

## Motif -> background: "lake" (landscape with the lighthouse), "land" (landscape without it),
## "sheet" (a plain sheet of the era's ink).
const MOTIFS: Dictionary[String, String] = {
	"pages": "lake", "ferry": "lake", "flock": "land", "rift": "land", "train": "land",
	"plate": "sheet", "seal": "sheet", "dunes": "land", "tower": "land", "caravan": "land",
	"edge": "land", "choir": "sheet", "guild": "sheet", "home": "lake", "book": "sheet",
}
## Seconds a motif takes to build up; the reduced-motion picture is the built one.
const BUILD_TIME: float = 3.0
const STILL_T: float = 4.0
## Redraws per second per era (0 = every frame).
const CADENCE: Dictionary[int, float] = {1: 2.0, 2: 4.0, 3: 12.0}
## Share of the screen height the picture takes, from the top of the safe area.
const PICTURE_SHARE: float = 0.56
const MARGIN: float = 6.0

var era: int = 1
var motif: String = "pages"
var t: float = 0.0
var still: bool = false
## Tests and shots drive the clock by hand.
var manual: bool = false

static func known(m: String) -> bool:
	return MOTIFS.has(m)

func _init(e: int = 1, m: String = "pages") -> void:
	era = clampi(e, 1, 5)
	motif = m
	still = Juice.reduced()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if manual or still:
		return
	var before: float = _clock()
	t += delta
	if _clock() != before:
		queue_redraw()

## The drawn second: the clock in the era's steps, or the finished picture when still.
func _clock() -> float:
	if still:
		return STILL_T
	var fps: float = float(CADENCE.get(era, 0.0))
	return floorf(t * fps) / fps if fps > 0.0 else t

## Build-up of the motif, 0..1.
func progress() -> float:
	return clampf(_clock() / BUILD_TIME, 0.0, 1.0)

## The picture's place on screen: the upper part of the safe area.
func picture_rect() -> Rect2:
	var vp: Vector2 = size
	var safe: Rect2 = SafeArea.rect(vp) if is_inside_tree() else Rect2(Vector2.ZERO, vp)
	var top: float = safe.position.y + MARGIN
	return Rect2(Vector2(safe.position.x + MARGIN, top), Vector2(safe.size.x - MARGIN * 2.0, floorf(safe.size.y * PICTURE_SHARE)))

func _draw() -> void:
	var c: float = _clock()
	draw_rect(Rect2(Vector2.ZERO, size), col("ink"))
	var outer: Rect2 = picture_rect()
	EraBackdrop.draw_frame(self, outer, era)
	var r: Rect2 = outer.grow(-3.0)
	match str(MOTIFS.get(motif, "sheet")):
		"lake":
			EraBackdrop.paint(self, r, era, c, still)
		"land":
			EraBackdrop.paint(self, r, era, c, still, false)
		_:
			draw_rect(r, col("sky_top"))
	var u: float = r.size.y / EraBackdrop.BASE_H
	var call: Callable = Callable(self, "_m_" + motif)
	if call.is_valid():
		call.call(r, u, c, progress())

func col(key: String) -> Color:
	return EraMoments.col(era, key)

## A colour with alpha, but solid in the limited-colour eras (I and II have no blending).
func soft(key: String, a: float) -> Color:
	return col(key) if era <= 2 else Color(col(key), a)

func _ground(r: Rect2) -> float:
	return floorf(r.position.y + r.size.y * EraBackdrop.HORIZON)

func _figure(at: Vector2, u: float, c: Color, bob: float = 0.0) -> void:
	var s: float = maxf(roundf(u), 1.0)
	draw_rect(Rect2(at + Vector2(-1.5 * s, -9.0 * s + bob), Vector2(3.0 * s, 3.0 * s)), c)
	draw_rect(Rect2(at + Vector2(-2.0 * s, -6.0 * s + bob), Vector2(4.0 * s, 6.0 * s)), c)

## Chapter 5: Mirela's pages slide together under the lamp and a path runs north.
func _m_pages(r: Rect2, u: float, _c: float, p: float) -> void:
	var mid := Vector2(r.position.x + r.size.x * 0.62, r.position.y + r.size.y * 0.3)
	var page := Vector2(16.0, 20.0) * u
	for i: int in 3:
		var from: Vector2 = mid + Vector2((i - 1) * 34.0, (i % 2) * 14.0 - 6.0) * u
		var at: Vector2 = from.lerp(mid + Vector2((i - 1) * page.x, 0), p).round()
		draw_rect(Rect2(at - page / 2.0, page), col("paper"))
		draw_rect(Rect2(at - page / 2.0, page), col("ink"), false, 1.0)
		for l: int in 3:
			draw_rect(Rect2(at + Vector2(-5.0, -5.0 + l * 4.0) * u, Vector2(10.0 * u, 1.0)), col("mid"))
	if p >= 1.0:
		var y: float = mid.y - page.y / 2.0
		while y > r.position.y + 4.0:
			draw_rect(Rect2(mid.x, y - 2.0, maxf(u, 1.0), 2.0), col("accent"))
			y -= 5.0 * u

## Chapter 6: Aldo's ferry leaves the pier, the village waves from the boards.
func _m_ferry(r: Rect2, u: float, c: float, p: float) -> void:
	var lake: float = _ground(r)
	var pier_x: float = r.position.x + 30.0 * u
	draw_rect(Rect2(pier_x, lake - 1.0 * u, 26.0 * u, 3.0 * u), col("ink"))
	for i: int in 4:
		_figure(Vector2(pier_x + (4.0 + i * 6.0) * u, lake - 1.0 * u), u * 0.8, col("ink"), -u if int(c * 2.0 + i) % 2 == 0 else 0.0)
	var x: float = pier_x + (34.0 + p * (r.size.x / u - 90.0)) * u
	var y: float = lake + 14.0 * u
	draw_colored_polygon(PackedVector2Array([Vector2(x - 12.0 * u, y), Vector2(x + 12.0 * u, y), Vector2(x + 8.0 * u, y + 4.0 * u), Vector2(x - 8.0 * u, y + 4.0 * u)]), col("ink"))
	_figure(Vector2(x - 4.0 * u, y), u, col("accent"))
	_figure(Vector2(x + 4.0 * u, y), u, col("paper"))
	var a: float = sin(c * 3.0) * 0.5
	draw_line(Vector2(x - 4.0 * u, y - 4.0 * u), Vector2(x - 4.0 * u, y - 4.0 * u) + Vector2(-cos(a), 0.6 + sin(a) * 0.4) * 12.0 * u, col("ink"), maxf(u, 1.0))

## Corvane Landing: a flock of grey Zephlets lifts off the quay roof.
func _m_flock(r: Rect2, u: float, c: float, p: float) -> void:
	var ground: float = _ground(r)
	var roof_x: float = r.position.x + r.size.x * 0.15
	draw_colored_polygon(PackedVector2Array([Vector2(roof_x, ground), Vector2(roof_x + 20.0 * u, ground - 14.0 * u), Vector2(roof_x + 40.0 * u, ground)]), col("ink"))
	draw_rect(Rect2(roof_x + 4.0 * u, ground, 32.0 * u, 10.0 * u), col("ink"))
	for i: int in 7:
		var k: float = clampf(p * 1.4 - i * 0.06, 0.0, 1.0)
		var at := Vector2(roof_x + (14.0 + i * 9.0 + k * 50.0) * u, ground - (14.0 + k * (60.0 + i * 5.0)) * u)
		for poly: PackedVector2Array in EraBackdrop.flyer_points(at.round(), u, sin(c * 6.0 + i)):
			draw_colored_polygon(poly, col("mid"))

## The Wide Rift: a torn seam across the sky, and three burned marks on the rock below.
func _m_rift(r: Rect2, u: float, c: float, p: float) -> void:
	var pts := PackedVector2Array()
	var y0: float = r.position.y + r.size.y * 0.28
	for i: int in 9:
		pts.append(Vector2(r.position.x + r.size.x * i / 8.0, y0 + (6.0 if i % 2 == 0 else -5.0) * u + sin(i * 1.7) * 3.0 * u))
	var glow: float = 3.0 + 2.0 * (sin(c * 2.0) * 0.5 + 0.5)
	draw_polyline(pts, soft("accent", 0.5), glow * u)
	draw_polyline(pts, col("paper"), maxf(u, 1.0))
	var rock := Vector2(r.get_center().x, _ground(r) + 6.0 * u)
	draw_rect(Rect2(rock - Vector2(22.0, 6.0) * u, Vector2(44.0, 14.0) * u), col("ink"))
	for i: int in int(ceilf(p * 3.0)):
		draw_rect(Rect2(rock + Vector2(-14.0 + i * 11.0, -2.0) * u, Vector2(6.0, 4.0) * u), col("accent"))

## Ashmere station: the railway car in falling ash, a Spirling frozen on the platform.
func _m_train(r: Rect2, u: float, c: float, _p: float) -> void:
	var ground: float = _ground(r) + 10.0 * u
	draw_rect(Rect2(r.position.x, ground, r.size.x, 1.0 * u), col("ink"))
	var car := Rect2(r.position.x + 10.0 * u, ground - 22.0 * u, 70.0 * u, 20.0 * u)
	draw_rect(car, col("ink"))
	for i: int in 4:
		draw_rect(Rect2(car.position + Vector2(5.0 + i * 16.0, 4.0) * u, Vector2(10.0, 7.0) * u), col("sun"))
	draw_rect(Rect2(Vector2(car.end.x + 16.0 * u, ground - 6.0 * u), Vector2(8.0, 6.0) * u), col("accent"))
	draw_rect(Rect2(Vector2(car.end.x + 14.0 * u, ground - 9.0 * u), Vector2(3.0, 3.0) * u), col("accent"))
	for i: int in 14:
		var fx: float = fmod(i * 37.0 * u + sin(c * 0.7 + i) * 6.0 * u, r.size.x)
		var fy: float = fmod(i * 23.0 * u + c * 8.0 * u, r.size.y)
		draw_rect(Rect2(r.position + Vector2(fx, fy).round(), Vector2.ONE * maxf(u, 1.0)), col("paper"))

## Veit's plate: a copper plate engraved with the Wide Rift cracks clean through.
func _m_plate(r: Rect2, u: float, _c: float, p: float) -> void:
	var plate := Rect2(r.get_center() - Vector2(46.0, 30.0) * u, Vector2(92.0, 60.0) * u)
	var split: float = 2.0 * u if p >= 1.0 else 0.0
	var left := Rect2(plate.position - Vector2(split, 0), Vector2(plate.size.x / 2.0, plate.size.y))
	var right := Rect2(plate.position + Vector2(plate.size.x / 2.0 + split, 0), Vector2(plate.size.x / 2.0, plate.size.y))
	for half: Rect2 in [left, right]:
		draw_rect(half, col("accent"))
		draw_rect(half, col("ink"), false, 1.0)
	for l: int in 5:
		var y: float = plate.position.y + (10.0 + l * 10.0) * u
		draw_line(Vector2(plate.position.x + 6.0 * u, y), Vector2(plate.end.x - 6.0 * u, y + sin(l * 1.3) * 4.0 * u), col("ink"), 1.0)
	var crack := PackedVector2Array()
	var steps: int = int(ceilf(p * 8.0))
	for i: int in steps + 1:
		crack.append(Vector2(plate.get_center().x + (3.0 if i % 2 == 0 else -3.0) * u, plate.position.y + plate.size.y * i / 8.0))
	if crack.size() >= 2:
		draw_polyline(crack, col("paper"), maxf(u, 1.0))

## The guild seal: the curtain of light parts and the Undrawn shows behind it.
func _m_seal(r: Rect2, u: float, c: float, p: float) -> void:
	var mid: Vector2 = r.get_center()
	var open: float = p * r.size.x * 0.5
	draw_rect(Rect2(mid.x - open, r.position.y, open * 2.0, r.size.y), col("paper"))
	for i: int in 4:
		var y: float = r.position.y + r.size.y * (0.3 + i * 0.12)
		draw_rect(Rect2(mid.x - open * (0.3 + i * 0.15), y, open * (0.6 + i * 0.3) * 0.5, 1.0), col("mid"))
	draw_rect(Rect2(r.position.x, r.position.y, mid.x - open - r.position.x, r.size.y), col("ink"))
	draw_rect(Rect2(mid.x + open, r.position.y, r.end.x - mid.x - open, r.size.y), col("ink"))
	var ring: float = (10.0 + 2.0 * sin(c * 3.0)) * u
	draw_arc(mid, ring, 0.0, TAU, 24, col("accent"), maxf(2.0 * u, 1.0))
	draw_circle(mid, 4.0 * u, col("sun"))

## Desert of Solenne: low sun over the dunes, the clay domes of Ochrewell.
func _dunes(r: Rect2, u: float) -> float:
	var ground: float = _ground(r)
	draw_circle(Vector2(r.position.x + r.size.x * 0.75, ground - 8.0 * u), 12.0 * u, col("sun"))
	draw_rect(Rect2(r.position.x, ground, r.size.x, r.end.y - ground), col("shore"))
	var pts := PackedVector2Array([Vector2(r.position.x, ground + 4.0 * u)])
	for i: int in 9:
		pts.append(Vector2(r.position.x + r.size.x * i / 8.0, ground - (4.0 + 5.0 * sin(i * 1.9)) * u))
	pts.append(Vector2(r.end.x, ground + 4.0 * u))
	draw_colored_polygon(pts, col("accent"))
	return ground

func _m_dunes(r: Rect2, u: float, c: float, p: float) -> void:
	var ground: float = _dunes(r, u)
	for i: int in 3:
		var at := Vector2(r.position.x + (24.0 + i * 22.0) * u, ground + 8.0 * u)
		draw_rect(Rect2(at - Vector2(8.0, 0) * u, Vector2(16.0, 10.0) * u), col("paper"))
		draw_arc(at, 8.0 * u, PI, TAU, 12, col("paper"), 8.0 * u)
	_figure(Vector2(r.position.x + (10.0 + p * 6.0) * u, r.end.y - 6.0 * u), u, col("ink"), -u if int(c * 4.0) % 2 == 0 else 0.0)

## The Tower Rift in the sandstorm.
func _m_tower(r: Rect2, u: float, c: float, _p: float) -> void:
	var ground: float = _dunes(r, u)
	var tower := Rect2(r.position.x + r.size.x * 0.55, r.position.y + 14.0 * u, 18.0 * u, ground - r.position.y - 10.0 * u)
	draw_rect(tower, col("ink"))
	for i: int in 4:
		draw_rect(Rect2(tower.position + Vector2(7.0, 10.0 + i * 16.0) * u, Vector2(4.0, 6.0) * u), col("sun"))
	for i: int in 10:
		var sx: float = fmod(i * 29.0 * u + c * 40.0 * u, r.size.x + 20.0 * u) - 20.0 * u
		var sy: float = r.position.y + (20.0 + i * 9.0) * u
		draw_rect(Rect2(r.position.x + sx, sy, 14.0 * u, maxf(u, 1.0)), col("paper"))

## North from Solenne: the strangers' caravan walks along the horizon.
func _m_caravan(r: Rect2, u: float, c: float, p: float) -> void:
	var ground: float = _dunes(r, u)
	for i: int in 11:
		var x: float = r.position.x + (6.0 + i * 11.0 + p * 18.0) * u
		var bob: float = -u if int(c * 4.0 + i) % 2 == 0 else 0.0
		_figure(Vector2(x, ground + 14.0 * u), u * 0.9, col("ink") if i % 3 else col("mid"), bob)

## The edge of the Undrawn: the drawn land stops in a ragged line; Mirela sits at it, drawing.
func _m_edge(r: Rect2, u: float, c: float, p: float) -> void:
	var edge_x: float = r.position.x + r.size.x * (0.78 - 0.16 * p)
	draw_rect(Rect2(edge_x, r.position.y, r.end.x - edge_x, r.size.y), col("paper"))
	for i: int in 12:
		var y: float = r.position.y + r.size.y * i / 12.0
		draw_rect(Rect2(edge_x - (2.0 if i % 2 == 0 else 0.0) * u, y, 3.0 * u, r.size.y / 12.0), col("ink"))
	for i: int in 4:
		var y: float = r.position.y + r.size.y * (0.3 + i * 0.15)
		draw_rect(Rect2(edge_x + 6.0 * u, y, (10.0 + i * 5.0) * u, 1.0), col("mid"))
	var seat := Vector2(edge_x - 10.0 * u, r.end.y - 10.0 * u)
	draw_rect(Rect2(seat + Vector2(-4.0, 0) * u, Vector2(8.0, 2.0) * u), col("ink"))
	_figure(seat, u, col("accent"))
	var flame: float = 1.0 + (sin(c * 5.0) * 0.5 + 0.5)
	draw_circle(seat + Vector2(3.0, -11.0) * u, flame * u, col("sun"))

## The Echo listens: hushed Spirlings in a ring lift their heads, the song goes out in soft rings.
## Sorrow, not menace: round shapes, no eyes, no teeth.
func _m_choir(r: Rect2, u: float, c: float, p: float) -> void:
	var mid := Vector2(r.get_center().x, r.position.y + r.size.y * 0.42)
	for i: int in 4:
		var k: float = fmod(c * 0.4 + i * 0.25, 1.0)
		var rad: float = (8.0 + k * 50.0) * u
		draw_arc(mid, rad, 0.0, TAU, 32, soft("accent", 0.6 * (1.0 - k)), maxf(u, 1.0))
	draw_circle(mid, 5.0 * u, col("paper"))
	for i: int in 7:
		var a: float = PI * (0.15 + 0.7 * i / 6.0)
		var at: Vector2 = mid + Vector2(cos(a), sin(a)) * 44.0 * u
		var lift: float = p * 3.0 * u
		draw_circle(at - Vector2(0, lift), 5.0 * u, col("mid"))
		draw_circle(at + Vector2(-3.0, -5.0) * u - Vector2(0, lift), 2.0 * u, col("mid"))
		draw_circle(at + Vector2(3.0, -5.0) * u - Vector2(0, lift), 2.0 * u, col("mid"))
		if p >= 1.0:
			var ny: float = fmod(c * 6.0 + i * 5.0, 18.0) * u
			draw_rect(Rect2(at + Vector2(0, -12.0 * u - ny), Vector2(2.0, 3.0) * u), col("paper"))

## Epilogue, the guild house: the wall map gets a new, finished edge.
func _m_guild(r: Rect2, u: float, _c: float, p: float) -> void:
	var map := r.grow(-10.0 * u)
	draw_rect(map, col("paper"))
	draw_rect(map, col("ink"), false, 1.0)
	for i: int in 5:
		var x: float = map.position.x + map.size.x * (i + 1) / 6.0
		draw_rect(Rect2(x, map.position.y, 1.0, map.size.y), col("mid"))
	var coast := PackedVector2Array()
	var n: int = int(ceilf(p * 12.0))
	for i: int in n + 1:
		coast.append(Vector2(map.position.x + map.size.x * i / 12.0, map.position.y + map.size.y * (0.55 + 0.15 * sin(i * 1.1))))
	if coast.size() >= 2:
		draw_polyline(coast, col("ink"), maxf(2.0 * u, 1.0))
	var rose: Vector2 = map.end - Vector2(14.0, 14.0) * u
	draw_arc(rose, 6.0 * u, 0.0, TAU, 16, col("accent"), maxf(u, 1.0))
	draw_rect(Rect2(rose - Vector2(0.5, 9.0) * u, Vector2(1.0, 18.0) * u), col("accent"))
	draw_rect(Rect2(rose - Vector2(9.0, 0.5) * u, Vector2(18.0, 1.0) * u), col("accent"))

## Epilogue, home: the lamp is lit, two figures on the Brindlewick dock.
func _m_home(r: Rect2, u: float, c: float, _p: float) -> void:
	var lake: float = _ground(r)
	var dock_x: float = r.position.x + r.size.x * 0.5
	draw_rect(Rect2(dock_x, lake - 1.0 * u, 34.0 * u, 3.0 * u), col("ink"))
	_figure(Vector2(dock_x + 12.0 * u, lake - 1.0 * u), u, col("ink"))
	_figure(Vector2(dock_x + 18.0 * u, lake - 1.0 * u), u, col("accent"))
	draw_circle(Vector2(dock_x + 15.0 * u, lake - 14.0 * u), (1.0 + 0.5 * sin(c * 2.0)) * u, col("sun"))

## Epilogue, the map book: every page full, the last one with a wide margin left to draw.
func _m_book(r: Rect2, u: float, _c: float, p: float) -> void:
	var book := Rect2(r.get_center() - Vector2(56.0, 34.0) * u, Vector2(112.0, 68.0) * u)
	draw_rect(book, col("paper"))
	draw_rect(book, col("ink"), false, 1.0)
	draw_rect(Rect2(book.get_center().x, book.position.y, 1.0, book.size.y), col("ink"))
	for l: int in 7:
		var y: float = book.position.y + (8.0 + l * 8.0) * u
		draw_rect(Rect2(book.position.x + 6.0 * u, y, book.size.x / 2.0 - 12.0 * u, 1.0), col("mid"))
		if l < int(ceilf(p * 4.0)):
			draw_rect(Rect2(book.get_center().x + 6.0 * u, y, book.size.x / 4.0, 1.0), col("mid"))
	var rose := Vector2(book.position.x + 10.0 * u, book.end.y - 10.0 * u)
	draw_arc(rose, 4.0 * u, 0.0, TAU, 12, col("accent"), maxf(u, 1.0))
