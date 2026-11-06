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

## WCAG contrast ratio of two colours (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## Switches the UI palette. Screens built afterwards use it; the theme is rebuilt on demand.
static func set_high_contrast(on: bool) -> void:
	high_contrast = on
	var p: Array[Color] = HIGH_CONTRAST_PALETTE if on else NORMAL_PALETTE
	BG = p[0]
	INK = p[1]
	MID = p[2]
	ACCENT = p[3]
	DISABLED = p[4]
	_theme = null
	_frames.clear()

## Frame slice size and how much of it is border.
const FRAME_SIZE: int = 9
const FRAME_MARGIN: int = 3

static var _theme: Theme
static var _frames: Dictionary[Color, ImageTexture] = {}

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

static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	t.default_font = PixelFont.get_font()
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
