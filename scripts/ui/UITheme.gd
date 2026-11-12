class_name UITheme
extends RefCounted
## Builds the shared UI Theme in code. Original Chimora look: "map-sheet" frames with notched
## corners and a double rule (ink line, paper gap, pencil line), like the edge of a hand-drawn
## cartographer's chart. Square, flat, no rounded "battle box" shapes.

const FONT_SIZE: int = 8
## Palette. Static (not const) so the high-contrast option can swap it (item 78).
static var BG: Color = Color("f4f1e6")
static var INK: Color = Color("2a1e2c")
static var MID: Color = Color("7d5f5f")
static var ACCENT: Color = Color("e6c9a0")
static var DISABLED: Color = Color("908679")

## MID reaches 5:1 on paper and DISABLED 3.2:1 (plan item 2041; they were 4.3:1 and 2.3:1).
const NORMAL_PALETTE: Array[Color] = [Color("f4f1e6"), Color("2a1e2c"), Color("7d5f5f"), Color("e6c9a0"), Color("908679")]
## Pure paper and ink, a darker mid tone and a stronger accent: text stays above 15:1.
const HIGH_CONTRAST_PALETTE: Array[Color] = [Color("ffffff"), Color("000000"), Color("3a3a3a"), Color("ffe680"), Color("6a6a6a")]

static var high_contrast: bool = false
## Large text (item 2042): menus, info windows, tips and talk use "Chimora Pixel Groß".
static var large_text: bool = false

static func set_large_text(on: bool) -> void:
	if large_text == on:
		return
	large_text = on
	_theme = null

## Era skin (data/era_feel.json via EraFeel): the menu palette, the frame kind and whether the
## era uses the large font. Era I is the plain ink sheet above.
static var era_palette: Array[Color] = NORMAL_PALETTE.duplicate()
static var frame_kind: String = "ink"
static var era_large_font: bool = false

## Switches the era skin; high contrast still wins over the era palette.
static func set_era_skin(p: Array[Color], frame: String, large_font: bool) -> void:
	if p.size() != NORMAL_PALETTE.size():
		p = NORMAL_PALETTE.duplicate()
	if p == era_palette and frame == frame_kind and large_font == era_large_font:
		return
	era_palette = p
	frame_kind = frame
	era_large_font = large_font
	set_high_contrast(high_contrast)

## The font every screen uses, small or large.
static func font() -> FontFile:
	return PixelFont.get_large_font() if large_text or era_large_font else PixelFont.get_font()

## WCAG contrast ratio of two colours (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## Switches the UI palette. Screens built afterwards use it; the theme is rebuilt on demand.
static func set_high_contrast(on: bool) -> void:
	high_contrast = on
	var p: Array[Color] = HIGH_CONTRAST_PALETTE if on else era_palette
	BG = p[0]
	INK = p[1]
	MID = p[2]
	ACCENT = p[3]
	DISABLED = p[4]
	_theme = null
	_frames.clear()
	_text_frames.clear()

## Frame slice size and how much of it is border.
const FRAME_SIZE: int = 9
const FRAME_MARGIN: int = 3

static var _theme: Theme
static var _frames: Dictionary[Color, ImageTexture] = {}
## Era II to V frames by "kind:colour".
static var _era_frames: Dictionary[String, ImageTexture] = {}

static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme

## The notched double-rule frame, filled with [param bg].
static func panel_style(bg: Color = BG, _border: Color = INK) -> StyleBox:
	var sb := StyleBoxTexture.new()
	sb.texture = _frame_texture(bg)
	sb.texture_margin_left = FRAME_MARGIN
	sb.texture_margin_top = FRAME_MARGIN
	sb.texture_margin_right = FRAME_MARGIN
	sb.texture_margin_bottom = FRAME_MARGIN
	sb.set_content_margin_all(FRAME_MARGIN + 2)
	return sb

## The panel frame of era frame kind [param kind] (EraFeel.FRAMES) in the current colours,
## whatever era is on screen (the era-change caption shows the old frame, then the new one).
static func frame_style_of(kind: String) -> StyleBox:
	var keep: String = frame_kind
	frame_kind = kind
	var sb: StyleBox = panel_style()
	frame_kind = keep
	return sb

## A plain flat box (buttons, bars): 1 px border, square corners.
static func flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(2)
	sb.anti_aliasing = false
	return sb

static func _frame_texture(bg: Color) -> ImageTexture:
	if frame_kind != "ink":
		return _era_frame_texture(frame_kind, bg)
	if _frames.has(bg):
		return _frames[bg]
	var img := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	var last: int = FRAME_SIZE - 1
	for i: int in FRAME_SIZE:
		for ring: int in 2:
			var c: Color = INK if ring == 0 else BG
			img.set_pixel(i, ring, c)
			img.set_pixel(i, last - ring, c)
			img.set_pixel(ring, i, c)
			img.set_pixel(last - ring, i, c)
	for i: int in range(2, FRAME_SIZE - 2):
		img.set_pixel(i, 2, MID)
		img.set_pixel(i, last - 2, MID)
		img.set_pixel(2, i, MID)
		img.set_pixel(last - 2, i, MID)
	# Notched corners with an ink rivet inside each notch.
	for p: Vector2i in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
		img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		var inner := Vector2i(1 if p.x == 0 else last - 1, 1 if p.y == 0 else last - 1)
		img.set_pixel(inner.x, inner.y, INK)
	var tex := ImageTexture.create_from_image(img)
	_frames[bg] = tex
	return tex

## Frames of the later eras, each one step further from the ink sheet: Era II a soft colour
## wash with rounded corners, Era III an etched bevel (light top left, dark bottom right) with a
## dotted gold rule, Era IV a clean rounded panel with a sky rule, Era V the same with a light
## gloss band along the top.
static func _era_frame_texture(kind: String, bg: Color) -> ImageTexture:
	var key: String = "%s:%s:%s" % [kind, bg.to_html(), INK.to_html()]
	if _era_frames.has(key):
		return _era_frames[key]
	var img := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	var last: int = FRAME_SIZE - 1
	var clear := Color(0, 0, 0, 0)
	var light: Color = bg.lerp(Color.WHITE, 0.6)
	for i: int in FRAME_SIZE:
		match kind:
			"wash":
				for ring: int in 3:
					var c: Color = [INK, ACCENT, ACCENT.lerp(bg, 0.5)][ring]
					img.set_pixel(i, ring, c)
					img.set_pixel(i, last - ring, c)
					img.set_pixel(ring, i, c)
					img.set_pixel(last - ring, i, c)
			"etched":
				img.set_pixel(i, 0, INK)
				img.set_pixel(i, last, INK)
				img.set_pixel(0, i, INK)
				img.set_pixel(last, i, INK)
				if i > 0 and i < last:
					img.set_pixel(i, 1, light)
					img.set_pixel(1, i, light)
					img.set_pixel(i, last - 1, MID)
					img.set_pixel(last - 1, i, MID)
				if i > 1 and i < last - 1:
					var dot: Color = ACCENT if i % 2 == 0 else bg
					img.set_pixel(i, 2, dot)
					img.set_pixel(i, last - 2, dot)
					img.set_pixel(2, i, dot)
					img.set_pixel(last - 2, i, dot)
			_:
				img.set_pixel(i, 0, INK)
				img.set_pixel(i, last, INK)
				img.set_pixel(0, i, INK)
				img.set_pixel(last, i, INK)
				if i > 0 and i < last:
					img.set_pixel(i, 1, ACCENT)
					img.set_pixel(1, i, ACCENT)
					img.set_pixel(i, last - 1, ACCENT.darkened(0.15))
					img.set_pixel(last - 1, i, ACCENT.darkened(0.15))
	if kind == "living":
		for x: int in range(2, last - 1):
			img.set_pixel(x, 2, light)
			img.set_pixel(x, 3, bg.lerp(Color.WHITE, 0.3))
	# Corners: Era III keeps the notch with a gold rivet, the others are rounded.
	for p: Vector2i in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
		var sx: int = 1 if p.x == 0 else -1
		var sy: int = 1 if p.y == 0 else -1
		img.set_pixel(p.x, p.y, clear)
		if kind == "etched":
			img.set_pixel(p.x + sx, p.y + sy, ACCENT)
		elif kind != "wash":
			img.set_pixel(p.x + sx, p.y, clear)
			img.set_pixel(p.x, p.y + sy, clear)
			img.set_pixel(p.x + sx, p.y + sy, INK)
	var tex := ImageTexture.create_from_image(img)
	_era_frames[key] = tex
	return tex

## Shop text frames for the dialogue box (item 4282): only looks. Each kind gives the three
## outer rings of one 3 px edge tile (outside first); the tile repeats along every edge.
const TEXT_FRAMES: Array[String] = ["vine", "brass", "wave", "lantern", "frost"]
static var _text_frames: Dictionary[String, StyleBoxTexture] = {}

## The dialogue box style: the plain panel, or a worn shop frame by kind.
static func text_frame_style(kind: String) -> StyleBox:
	if not kind in TEXT_FRAMES:
		return panel_style()
	var key: String = kind + BG.to_html()
	if _text_frames.has(key):
		return _text_frames[key]
	var rings: Array = _frame_rings(kind)
	var img := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	var last: int = FRAME_SIZE - 1
	for i: int in FRAME_SIZE:
		for ring: int in 3:
			var c: Color = rings[ring][i % 3]
			if ring == 2 and (i < 2 or i > last - 2):
				continue
			img.set_pixel(i, ring, c)
			img.set_pixel(i, last - ring, c)
			img.set_pixel(ring, i, c)
			img.set_pixel(last - ring, i, c)
	var corner: Color = rings[3]
	for p: Vector2i in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
		img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		var inner := Vector2i(1 if p.x == 0 else last - 1, 1 if p.y == 0 else last - 1)
		img.set_pixel(inner.x, inner.y, corner)
		img.set_pixel(inner.x + (1 if p.x == 0 else -1), inner.y, corner)
		img.set_pixel(inner.x, inner.y + (1 if p.y == 0 else -1), corner)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = FRAME_MARGIN
	sb.texture_margin_top = FRAME_MARGIN
	sb.texture_margin_right = FRAME_MARGIN
	sb.texture_margin_bottom = FRAME_MARGIN
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.set_content_margin_all(FRAME_MARGIN + 2)
	_text_frames[key] = sb
	return sb

## Three rings of three pixels each, then the corner rivet colour.
static func _frame_rings(kind: String) -> Array:
	match kind:
		"vine":
			return [[INK, INK, INK], [MID, ACCENT, MID], [BG, MID, BG], MID]
		"brass":
			return [[INK, INK, INK], [ACCENT, ACCENT, ACCENT], [INK, BG, INK], ACCENT]
		"wave":
			return [[INK, INK, INK], [BG, MID, BG], [MID, BG, MID], MID]
		"lantern":
			return [[INK, INK, INK], [INK, ACCENT, INK], [ACCENT, BG, BG], ACCENT]
		_:
			return [[INK, INK, INK], [BG, BG, ACCENT], [ACCENT, BG, BG], BG]

static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	t.default_font = font()
	t.set_color("font_color", "Label", INK)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg: Color = BG
		var border: Color = MID
		# Focus must survive the 4-shade Retro filter, so it inverts to ink on paper.
		if state == "hover" or state == "focus":
			bg = INK
			border = INK
		elif state == "pressed":
			bg = MID
			border = INK
		elif state == "disabled":
			border = DISABLED
		var sb: StyleBoxFlat = flat_style(bg, border)
		if frame_kind in ["panorama", "living"]:
			sb.set_corner_radius_all(2)
		elif frame_kind == "etched" and state != "pressed":
			sb.border_width_bottom = 2
		if state == "pressed":
			# Held buttons sink 1 px (item 2415).
			sb.content_margin_top = 3
			sb.content_margin_bottom = 1
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", BG)
	t.set_color("font_focus_color", "Button", BG)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_hover_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", DISABLED)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("normal", "LineEdit", flat_style(ACCENT, INK))
	t.set_stylebox("focus", "LineEdit", flat_style(ACCENT, INK))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	return t
