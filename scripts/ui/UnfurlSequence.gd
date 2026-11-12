class_name UnfurlSequence
extends Control
## The unfurl moment (items 2327, 2328): the old and new form swap as ink silhouettes, first
## every 0.4 s, then faster down to every 0.05 s, over 2.4 s; then the new form shows in full
## with a pop. After the first time a tap skips it. Under reduced motion: one short crossfade.
##   var u := UnfurlSequence.new(); parent.add_child(u); await u.play(old_data, new_data)

const TOTAL_TIME: float = 2.4
const FIRST_SWAP: float = 0.4
const LAST_SWAP: float = 0.05
const SWAP_RATIO: float = 0.85
const SEEN_FLAG: String = "unfurl_seen"
const SPRITE_SIZE: int = 56

var _old: Texture2D
var _new: Texture2D
var _show_new: bool = false
var _silhouette: bool = true
var _fade: float = 0.0
var _skippable: bool = false
var _skipped: bool = false
var _sprite: Control
static var _silhouettes: Dictionary[String, Texture2D] = {}
## Era look of the moment (data/era_battle_feel.json "unfurl"): "ink" on parchment (I), a flat
## colour wash (II), banded light (III), turning light rays (IV), rays with rising motes (V).
## From Era II the silhouettes glow white instead of ink, and the sprite grows with the era.
var style: String = "ink"
var _time: float = 0.0

## Durations between swaps: 0.4 s shrinking by 15 % each time to 0.05 s, filling 2.4 s.
static func intervals() -> Array[float]:
	var out: Array[float] = []
	var d: float = FIRST_SWAP
	var total: float = 0.0
	while total < TOTAL_TIME - 0.001:
		var step: float = maxf(d, LAST_SWAP)
		# Never leave a sliver shorter than the fastest swap at the end.
		if total + step > TOTAL_TIME - LAST_SWAP:
			step = TOTAL_TIME - total
		out.append(step)
		total += step
		d *= SWAP_RATIO
	return out

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var era: int = EraManager.active_era()
	style = EraBattleFeel.text(era, "unfurl", "ink")
	_sprite = Control.new()
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px: int = sprite_size(era)
	_sprite.size = Vector2(px, px)
	_sprite.draw.connect(_draw_sprite)
	add_child(_sprite)
	_center()
	resized.connect(_center)

## Sprite size of the moment in [param era]: the era's battle sprite size, at least 56 px.
static func sprite_size(era: int) -> int:
	return maxi(SPRITE_SIZE, int(EraManager.BATTLE_SPRITE_SIZE.get(clampi(era, 1, EraManager.NEWEST), SPRITE_SIZE)))

func _process(delta: float) -> void:
	if style in ["rays", "rays_motes"] and not Juice.reduced():
		_time += delta
		queue_redraw()

func _center() -> void:
	if _sprite != null:
		_sprite.position = ((size - _sprite.size) / 2.0).round()

static func _tex(sd: SpirlingData) -> Texture2D:
	if sd == null:
		return null
	var path: String = EraManager.sprite_path(sd.species_name, "front")
	return load(path) if not path.is_empty() else null

func play(old_form: SpirlingData, new_form: SpirlingData) -> void:
	_old = _tex(old_form)
	_new = _tex(new_form)
	_skippable = GameState.has_flag(SEEN_FLAG)
	GameState.set_flag(SEEN_FLAG)
	if Juice.reduced():
		_silhouette = false
		var tw: Tween = create_tween()
		tw.tween_method(func(k: float) -> void:
			_fade = k
			_sprite.queue_redraw(), 0.0, 1.0, Juice.REDUCED_MAX_TIME)
		await tw.finished
		_show_new = true
		_fade = 0.0
		_sprite.queue_redraw()
		return
	for d: float in intervals():
		if _skipped:
			break
		_sprite.queue_redraw()
		await get_tree().create_timer(d).timeout
		_show_new = not _show_new
	_show_new = true
	_silhouette = false
	_sprite.queue_redraw()
	Sound.sfx("level_up")
	if style != "ink" and style != "wash":
		LevelRing.spawn(self, _sprite.position + _sprite.size / 2.0)
	await Juice.pop(_sprite)

func _gui_input(event: InputEvent) -> void:
	if _skippable and TapInput.is_press(event):
		_skipped = true
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.BG)
	if style == "ink":
		return
	var c: Dictionary = EraBattleFeel.backdrop_colours(3 if style != "wash" else 2, "field")
	var sky := Color(str(c.get("sky", "a8d0e8")))
	var low := Color(str(c.get("sky_low", c.get("bg", "f6f0d8"))))
	if style == "wash":
		draw_rect(Rect2(Vector2.ZERO, size), sky)
		return
	var mid: Vector2 = (size / 2.0).round()
	var far: float = mid.length()
	for i: int in range(6, 0, -1):
		var r: float = far * i / 6.0
		draw_rect(Rect2(mid - Vector2(r, r), Vector2(r, r) * 2.0), sky.lerp(low, 1.0 - i / 6.0))
	if style == "bands":
		return
	for i: int in 12:
		var a: float = _time * 0.4 + i * TAU / 12.0
		var tip: Vector2 = mid + Vector2(cos(a), sin(a)) * far
		var tip2: Vector2 = mid + Vector2(cos(a + 0.12), sin(a + 0.12)) * far
		draw_colored_polygon(PackedVector2Array([mid, tip, tip2]), Color(1, 1, 0.92, 0.18))
	if style == "rays_motes":
		for i: int in 14:
			var x: float = fmod(i * 37.0, size.x)
			var y: float = size.y - fmod(_time * (18.0 + i % 4 * 6.0) + i * 29.0, size.y)
			draw_rect(Rect2(Vector2(x, y).round(), Vector2(1, 1) * (1 + i % 2)), Color(1, 1, 0.92, 0.7))

func _draw_sprite() -> void:
	var r := Rect2(Vector2.ZERO, _sprite.size)
	if _fade > 0.0:
		_draw_form(_old, r, Color(1, 1, 1, 1.0 - _fade))
		_draw_form(_new, r, Color(1, 1, 1, _fade))
		return
	var tex: Texture2D = _new if _show_new else _old
	if _silhouette:
		tex = silhouette_of(tex, UITheme.INK if style == "ink" else Color(1, 1, 0.94))
	_draw_form(tex, r, Color.WHITE)

func _draw_form(tex: Texture2D, r: Rect2, tint: Color) -> void:
	if tex == null:
		_sprite.draw_rect(r.grow(-8), (UITheme.INK if style == "ink" else Color.WHITE) if _silhouette else UITheme.MID)
		return
	_sprite.draw_texture_rect(tex, r, false, tint)

## The sprite as a flat shape (every visible pixel in [param col], ink by default).
static func silhouette_of(tex: Texture2D, col: Color = UITheme.INK) -> Texture2D:
	if tex == null:
		return null
	var key: String = "%d|%s" % [tex.get_rid().get_id(), col.to_html()]
	if _silhouettes.has(key):
		return _silhouettes[key]
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				img.set_pixel(x, y, col)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(img)
	_silhouettes[key] = out
	return out

## Showing the new form in colour (tests).
func showing_new() -> bool:
	return _show_new and not _silhouette

func silhouette() -> bool:
	return _silhouette
