class_name EraFont
extends RefCounted
## Chimora's own text fonts of the later eras, built into bitmap FontFiles at runtime from the
## glyph tables in EraFontGlyphs (tools/fonts/build_era_fonts.py): "etch10", the 10 px font of
## Era III, and "pano12", the 12 px font of Eras IV and V. They draw English and German; any
## other character comes from the Chimora pixel font behind them (small for the 10 px font,
## large for the 12 px one) and from its CJK fonts. Like the pixel font they answer to
## PixelFont.BASE_SIZE, so no screen needs a new font size.

const GAP: int = 1
const COLS: int = 16

static var _fonts: Dictionary[String, FontFile] = {}

static func has_font(id: String) -> bool:
	return EraFontGlyphs.FONTS.has(id)

static func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(EraFontGlyphs.FONTS.keys())
	return out

## Rows of one text line of font [param id] (0 when unknown).
static func cell_height(id: String) -> int:
	return int((EraFontGlyphs.FONTS.get(id, {}) as Dictionary).get("cell_h", 0))

## Pixels from the top of a line of font [param id] to its baseline (0 when unknown).
static func ascent_of(id: String) -> int:
	return int((EraFontGlyphs.FONTS.get(id, {}) as Dictionary).get("ascent", 0))

## True if font [param id] draws [param ch] itself.
static func has_glyph(id: String, ch: String) -> bool:
	return ((EraFontGlyphs.FONTS.get(id, {}) as Dictionary).get("glyphs", {}) as Dictionary).has(ch)

## The pixel rows of [param ch] in font [param id] ("#" = ink), empty when it has none. A bold
## font (data/era_text.json "bold") draws every stroke doubled, like the Era IV/V battle HUD.
static func glyph(id: String, ch: String) -> Array:
	var rows: Array = ((EraFontGlyphs.FONTS.get(id, {}) as Dictionary).get("glyphs", {}) as Dictionary).get(ch, [])
	return PixelFont.embolden(rows) if is_bold(id) and not rows.is_empty() else rows

## True when font [param id] is drawn bold (data/era_text.json "bold": the Era IV/V font).
static func is_bold(id: String) -> bool:
	return id in (EraText.config().get("bold", []) as Array)

## Pixels [param text] is wide in font [param id], counting only its own glyphs.
static func text_width(id: String, text: String) -> int:
	var def: Dictionary = EraFontGlyphs.FONTS.get(id, {})
	var w: int = 0
	for i: int in text.length():
		var g: Array = glyph(id, text[i])
		if text[i] == " ":
			w += int(def.get("space", 3))
		elif not g.is_empty():
			w += str(g[0]).length() + GAP
	return w

## The FontFile of [param id], null when there is no such font.
static func get_font(id: String) -> FontFile:
	if not has_font(id):
		return null
	if not _fonts.has(id):
		_fonts[id] = _build(id)
	return _fonts[id]

static func _build(id: String) -> FontFile:
	var def: Dictionary = EraFontGlyphs.FONTS[id]
	var glyphs: Dictionary = def.glyphs
	var cw: int = int(def.cell_w) + (1 if is_bold(id) else 0)
	var chh: int = int(def.cell_h)
	var ascent: int = int(def.ascent)
	var chars: Array = glyphs.keys()
	var pad: int = 1
	var rows: int = int(ceil(chars.size() / float(COLS)))
	var img := Image.create(COLS * (cw + pad), rows * (chh + pad), false, Image.FORMAT_LA8)
	var f := FontFile.new()
	var base: int = PixelFont.BASE_SIZE
	f.fixed_size = base
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.font_name = str(def.name)
	var size := Vector2i(base, 0)
	f.set_cache_ascent(0, base, ascent)
	f.set_cache_descent(0, base, chh - ascent)
	for i: int in chars.size():
		var ch: String = chars[i]
		var bitmap: Array = glyph(id, ch)
		var gx: int = (i % COLS) * (cw + pad)
		var gy: int = (i / COLS) * (chh + pad)
		var w: int = str(bitmap[0]).length()
		for y: int in bitmap.size():
			var line: String = bitmap[y]
			for x: int in w:
				if line[x] == "#":
					img.set_pixel(gx + x, gy + y, Color(1, 1, 1, 1))
		var code: int = ch.unicode_at(0)
		if ch == " ":
			w = int(def.space) - GAP
		f.set_glyph_advance(0, base, code, Vector2(w + GAP, 0))
		f.set_glyph_offset(0, size, code, Vector2(0, -ascent))
		f.set_glyph_size(0, size, code, Vector2(w, chh))
		f.set_glyph_uv_rect(0, size, code, Rect2(gx, gy, w, chh))
		f.set_glyph_texture_idx(0, size, code, 0)
	f.set_texture_image(0, size, 0, img)
	# Accents, Cyrillic, the button marks and CJK come from the pixel font of the nearest size.
	var behind: Array[Font] = [PixelFont.get_large_font() if chh >= PixelFont.LARGE_H else PixelFont.get_font()]
	f.fallbacks = behind
	return f
