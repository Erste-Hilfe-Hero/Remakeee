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
static var _silhouettes: Dictionary[int, Texture2D] = {}

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
	_sprite = Control.new()
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
	_sprite.draw.connect(_draw_sprite)
	add_child(_sprite)
	_center()
	resized.connect(_center)

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
	Sound.sfx("evolve")
	await Juice.pop(_sprite)

func _gui_input(event: InputEvent) -> void:
	if _skippable and TapInput.is_press(event):
		_skipped = true
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.BG)

func _draw_sprite() -> void:
	var r := Rect2(Vector2.ZERO, _sprite.size)
	if _fade > 0.0:
		_draw_form(_old, r, Color(1, 1, 1, 1.0 - _fade))
		_draw_form(_new, r, Color(1, 1, 1, _fade))
		return
	var tex: Texture2D = _new if _show_new else _old
	if _silhouette:
		tex = silhouette_of(tex)
	_draw_form(tex, r, Color.WHITE)

func _draw_form(tex: Texture2D, r: Rect2, tint: Color) -> void:
	if tex == null:
		_sprite.draw_rect(r.grow(-8), UITheme.INK if _silhouette else UITheme.MID)
		return
	_sprite.draw_texture_rect(tex, r, false, tint)

## The sprite as a flat ink shape (every visible pixel in ink).
static func silhouette_of(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var key: int = tex.get_rid().get_id()
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
				img.set_pixel(x, y, UITheme.INK)
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
