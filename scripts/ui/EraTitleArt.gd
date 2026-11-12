class_name EraTitleArt
extends TitleArt
## The title illustration in the look of an era (data/era_moments.json "title",
## docs/ERA_LOOK_TITLE.md). The logo artwork is the same wordmark in every era; only what
## happens around it changes, the way the genre's title screens grew with the hardware:
##   I   the ink title of TitleArt, held still, with a 2-frame blink (beam, stars, glints)
##   II  flat colour, clouds and far shore scroll in whole pixels
##   III banded sky, a light running over the logo, a silhouette flying past
##   IV  four parallax layers, big figures with shadows on a lake drawn in perspective
##   V   a living scene: drifting camera, aurora, waves, motes, breathing figures and the
##       era's legend standing in the sky behind the hills
## With reduced motion every era is a still picture.

## Era I: the two held frames are these two moments of TitleArt's clock.
const INK_FRAMES: Array[float] = [0.0, 7.85]
const BASE_W: float = 144.0
const BASE_ART_H: float = 148.0
## Cast sprite size per era in px (Era I and II as TitleArt draws them, native 64 px art in
## III, twice that from IV on).
const CAST_SIZE: Array[int] = [0, 40, 40, 64, 128, 128]
const SHINE_PERIOD: float = 4.5

var era: int = 1
var still: bool = false
var show_logo: bool = true
var show_cast: bool = true
## Seconds since the art appeared (the scene clock; Era I only uses it to pick its frame).
var clock: float = 0.0
## Tests and frame strips set this to drive the clock by hand.
var manual: bool = false

var _cast: Array[Texture2D] = []
var _cast_era: int = 0

## Height of the title art for a screen [param width] px wide (148 px at 144).
static func art_height(width: float) -> int:
	return int(round(BASE_ART_H * width / BASE_W))

## Which of the two Era I frames shows at second [param t].
static func ink_frame(t: float, blink: float) -> int:
	return int(floor(t / maxf(blink, 0.05))) % 2

## The logo is drawn at 3x the pixel font at 144 px and grows with the screen width.
static func logo_scale(width: float) -> int:
	return maxi(int(round(width / 45.0)), 1)

func _ready() -> void:
	super._ready()
	clip_contents = true
	still = still or Juice.reduced()

func set_era(e: int) -> void:
	era = clampi(e, 1, 5)
	queue_redraw()

func _process(delta: float) -> void:
	if not manual and not still:
		clock += delta
	if era == 1:
		_t = INK_FRAMES[0 if still else ink_frame(clock, float(EraMoments.title(1).get("blink", 0.6)))]
	else:
		_t = clock
	queue_redraw()

func _load_cast() -> void:
	_cast_era = era
	_cast.clear()
	for sp: Variant in EraMoments.title(era).get("cast", []):
		var p: String = EraManager.art_path_from("spirlings/%s_front.png" % str(sp), era)
		_cast.append(load(p) if not p.is_empty() else null)

func _draw() -> void:
	if era == 1:
		if show_logo and show_cast:
			super._draw()
		else:
			EraBackdrop.paint(self, Rect2(Vector2.ZERO, size), 1, _t, true)
		return
	var r := Rect2(Vector2.ZERO, size)
	EraBackdrop.paint(self, r, era, _t, still)
	if show_cast:
		_draw_cast(r)
	if era == 5 and not still:
		EraBackdrop.motes(self, r, _t)
	if show_logo:
		_draw_era_logo(Vector2(size.x / 2.0, 6.0 * size.x / BASE_W))

func _draw_cast(r: Rect2) -> void:
	if _cast_era != era:
		_load_cast()
	var u: float = r.size.y / BASE_ART_H
	var shore_y: float = r.end.y - 6.0 * u
	var px: float = CAST_SIZE[era]
	for i: int in _cast.size():
		if _cast[i] == null:
			continue
		var cx: float = r.size.x * (i + 1) / (_cast.size() + 1)
		var bob: float = 0.0
		var stretch: float = 1.0
		if not still:
			match era:
				2: bob = roundf(sin(_t * 2.0 + i * 2.1))
				3, 4: bob = sin(_t * 2.0 + i * 2.1) * 1.5
				5: stretch = 1.0 + 0.03 * sin(_t * 1.7 + i * 1.9)
		var feet: float = shore_y + px * 0.07
		if era >= 4:
			# A soft shadow under each figure: the 2.5D stage feel of the fourth step.
			draw_set_transform(Vector2(cx, feet - px * 0.1), 0.0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, px * 0.3, Color(EraMoments.col(era, "ink"), 0.35))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var h: float = px * stretch
		draw_texture_rect(_cast[i], Rect2(roundf(cx - px / 2.0), roundf(feet - h + bob), px, h), false)

## The same wordmark as TitleArt._draw_logo (ink outline, drop shadow, paper letters), scaled
## to the era's screen and in the era's inks. From Era III a light runs over the letters.
func _draw_era_logo(center: Vector2) -> void:
	var font: Font = get_theme_default_font()
	# The wordmark keeps its size, but never runs off the screen.
	var k: int = logo_scale(size.x)
	while k > 1 and font.get_string_size(LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE * k).x + 6.0 * k / 3.0 > size.x - 4.0:
		k -= 1
	var fs: int = PixelFont.BASE_SIZE * k
	var ink: Color = EraMoments.col(era, "ink")
	var paper: Color = EraMoments.col(era, "paper")
	var shadow: Color = EraMoments.col(era, "far")
	var width: float = font.get_string_size(LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(roundf(center.x - width / 2.0), center.y + PixelFont.ASCENT * k)
	var d: float = maxf(k / 3.0, 1.0)
	if era == 5 and not still:
		# A soft pulse of light behind the wordmark.
		var glow: Color = Color(EraMoments.col(5, "accent"), 0.25 + 0.15 * sin(_t * 1.3))
		for o: Vector2 in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
			draw_string(font, pos + o * d, LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glow)
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
		draw_string(font, pos + (o + Vector2(2, 2)) * d, LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_string(font, pos + Vector2(2, 2) * d, LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shadow)
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, pos + o * d, LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_string(font, pos, LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, paper)
	if bool(EraMoments.title(era).get("shine", false)) and not still:
		_draw_shine(font, pos, fs, width)
	var sub: String = Loc.t(str(EraMoments.era(era).get("subtitle", "")))
	var sfs: int = PixelFont.BASE_SIZE * EraMomentLayer.fit_scale(font, sub, EraMoments.font_scale(era), size.x - 4.0)
	var sw: float = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
	var sub_pos := Vector2(roundf(center.x - sw / 2.0), pos.y + PixelFont.DESCENT * k + 3.0 * d + PixelFont.ASCENT * sfs / PixelFont.BASE_SIZE + 2)
	draw_string(font, sub_pos + Vector2(1, 1), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, ink)
	draw_string(font, sub_pos, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, EraMoments.col(era, "sun"))

## Where the light stands on the logo at second [param t]: -0.3..1.3 across its width while it
## runs, -1 while it rests.
static func shine_at(t: float) -> float:
	var k: float = fmod(t, SHINE_PERIOD) / SHINE_PERIOD
	return -0.3 + k / 0.35 * 1.6 if k < 0.35 else -1.0

func _draw_shine(font: Font, pos: Vector2, fs: int, width: float) -> void:
	var at: float = shine_at(_t)
	if at < -0.5:
		return
	var x: float = pos.x
	var light: Color = EraMoments.col(era, "sun").lerp(Color.WHITE, 0.6)
	for i: int in LOGO.length():
		var ch: String = LOGO[i]
		var cw: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var mid: float = (x + cw / 2.0 - pos.x) / maxf(width, 1.0)
		var a: float = clampf(1.0 - absf(mid - at) / 0.18, 0.0, 1.0)
		if a > 0.0:
			draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(light, a))
		x += cw
	# A four-point glint rides on the light.
	var gx: float = pos.x + clampf(at, 0.0, 1.0) * width
	var gy: float = pos.y - fs * 0.7
	var s: float = fs * 0.22
	draw_line(Vector2(gx - s, gy), Vector2(gx + s, gy), Color.WHITE, 1.0)
	draw_line(Vector2(gx, gy - s), Vector2(gx, gy + s), Color.WHITE, 1.0)
