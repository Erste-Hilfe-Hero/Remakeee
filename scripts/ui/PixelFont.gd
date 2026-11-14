class_name PixelFont
extends RefCounted
## Chimora's own proportional pixel font (original glyphs on a 5x9 grid, 7 px above the baseline, 2 below),
## built into a bitmap FontFile at runtime. No system or third-party font is used, so text
## looks the same on every device and in headless CI.

const CELL_W: int = 5
const CELL_H: int = 9
const ASCENT: int = 7
const DESCENT: int = 2
## Gap after each glyph, and the width of a space.
const GAP: int = 1
const SPACE_ADVANCE: int = 3
## The font renders 1:1 at this size; integer multiples scale cleanly.
const BASE_SIZE: int = 8

static var _font: FontFile
static var _large: FontFile
static var _all: Dictionary[String, Array] = {}

## Every glyph of the font: GLYPHS plus the accented Latin letters and Cyrillic of
## PixelFontExtra.GLYPHS (French, Italian, Spanish, Portuguese, Polish, Turkish, Dutch, Russian).
static func glyphs() -> Dictionary[String, Array]:
	if _all.is_empty():
		_all = GLYPHS.duplicate()
		_all.merge(PixelFontExtra.GLYPHS)
	return _all

## True if the pixel font draws [param ch] itself (CJK text comes from CjkFont fallbacks).
static func has_glyph(ch: String) -> bool:
	return glyphs().has(ch)

## "Chimora Pixel Groß" (plan item 2042): the same glyphs drawn on a 7x12 grid, 9 px above the
## baseline and 3 below, for the Large text option. It answers to the same font size, so every
## screen can swap it in without new sizes.
const LARGE_W: int = 7
const LARGE_H: int = 12
const LARGE_ASCENT: int = 9
const LARGE_DESCENT: int = 3
## Which small column and row each large column and row comes from: the inner columns and two
## rows above the baseline and one below are drawn twice, so outlines stay one pixel thin.
const LARGE_COLS: Array[int] = [0, 1, 1, 2, 3, 3, 4]
const LARGE_ROWS: Array[int] = [0, 1, 2, 2, 3, 4, 5, 5, 6, 7, 7, 8]

static func get_font() -> FontFile:
	if _font == null:
		_font = _build()
		_font.fallbacks = cjk_fallbacks(_lang)
	return _font

static func get_large_font() -> FontFile:
	if _large == null:
		_large = _build(true)
		_large.fallbacks = cjk_fallbacks(_lang)
	return _large

## Bold large font (Era IV/V battle HUD): the large glyphs with every stroke doubled to the
## right, so text reads heavy on the 270 px screens. One pixel wider than the large set.
static var _bold: FontFile
const BOLD_W: int = LARGE_W + 1

static func get_bold_font() -> FontFile:
	if _bold == null:
		_bold = _build(true, true)
		_bold.fallbacks = cjk_fallbacks(_lang)
	return _bold

## Rows of a glyph drawn bold: each lit pixel also lights the next to its right, so every row
## is one pixel wider. The Era IV/V fonts (bold set below, EraFont "bold") share it.
static func embolden(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for r: Variant in rows:
		var line: String = str(r)
		var b: String = ""
		for x: int in line.length() + 1:
			var here: bool = x < line.length() and line[x] == "#"
			var left: bool = x > 0 and line[x - 1] == "#"
			b += "#" if here or left else "."
		out.append(b)
	return out

## One glyph of the bold set: [method large_glyph] with each lit pixel also lighting the next.
static func bold_glyph(ch: String) -> Array[String]:
	var out: Array[String] = []
	for line: String in large_glyph(ch):
		var b: String = ""
		for x: int in BOLD_W:
			var here: bool = x < line.length() and line[x] == "#"
			var left: bool = x > 0 and x - 1 < line.length() and line[x - 1] == "#"
			b += "#" if here or left else "."
		out.append(b)
	return out

## Japanese, Korean and Chinese come from the Fusion Pixel 8px fonts in art/fonts (OFL, built by
## tools/fonts/build_cjk.py), added as fallbacks of the pixel font. The current language's font
## comes first, so shared characters get its regional form; the others stay behind it, because
## the language list shows every language's own name.
const CJK_FONT: String = "res://art/fonts/chimora_cjk_8px_%s.otf"
static var _lang: String = "en"
static var _cjk: Dictionary[String, Font] = {}

static func cjk_fallbacks(code: String) -> Array[Font]:
	var order: Array[String] = ["ja", "zh_CN", "zh_TW", "ko"]
	if code in order:
		order.erase(code)
		order.push_front(code)
	var out: Array[Font] = []
	for c: String in order:
		if not _cjk.has(c):
			var f: Font = load(CJK_FONT % c) as Font
			if f == null:
				continue
			_cjk[c] = f
		out.append(_cjk[c])
	return out

## Called by Loc.set_language: puts the language's own CJK font first.
static func use_language(code: String) -> void:
	if code == _lang:
		return
	_lang = code
	if _font != null:
		_font.fallbacks = cjk_fallbacks(code)
	if _large != null:
		_large.fallbacks = cjk_fallbacks(code)
	if _bold != null:
		_bold.fallbacks = cjk_fallbacks(code)

## One glyph of the large set, as rows of "#" and ".".
static func large_glyph(ch: String) -> Array[String]:
	var small: Array = glyphs()[ch]
	var out: Array[String] = []
	for r: int in LARGE_ROWS:
		var line: String = ""
		for c: int in LARGE_COLS:
			line += str(small[r])[c]
		out.append(line)
	return out

static func _build(large: bool = false, bold: bool = false) -> FontFile:
	var chars: Array = glyphs().keys()
	var cw: int = (BOLD_W if bold else LARGE_W) if large else CELL_W
	var chh: int = LARGE_H if large else CELL_H
	var ascent: int = LARGE_ASCENT if large else ASCENT
	var descent: int = LARGE_DESCENT if large else DESCENT
	var space: int = SPACE_ADVANCE + 1 if large else SPACE_ADVANCE
	var cols: int = 16
	var rows: int = int(ceil(chars.size() / float(cols)))
	var pad: int = 1
	var img := Image.create(cols * (cw + pad), rows * (chh + pad), false, Image.FORMAT_LA8)
	var f := FontFile.new()
	f.fixed_size = BASE_SIZE
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.font_name = ("Chimora Pixel Fett" if bold else "Chimora Pixel Groß") if large else "Chimora Pixel"
	var size := Vector2i(BASE_SIZE, 0)
	f.set_cache_ascent(0, BASE_SIZE, ascent)
	f.set_cache_descent(0, BASE_SIZE, descent)
	for i: int in chars.size():
		var ch: String = chars[i]
		var gx: int = (i % cols) * (cw + pad)
		var gy: int = (i / cols) * (chh + pad)
		var bitmap: Array = (bold_glyph(ch) if bold else large_glyph(ch)) if large else glyphs()[ch]
		var min_x: int = cw
		var max_x: int = -1
		for y: int in bitmap.size():
			for x: int in cw:
				if str(bitmap[y])[x] == "#":
					img.set_pixel(gx + x, gy + y, Color(1, 1, 1, 1))
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
		var code: int = ch.unicode_at(0)
		if max_x < 0:
			# Blank glyph (space).
			min_x = 0
			max_x = space - GAP - 1
		var w: int = max_x - min_x + 1
		f.set_glyph_advance(0, BASE_SIZE, code, Vector2(w + GAP, 0))
		f.set_glyph_offset(0, size, code, Vector2(0, -ascent))
		f.set_glyph_size(0, size, code, Vector2(w, chh))
		f.set_glyph_uv_rect(0, size, code, Rect2(gx + min_x, gy, w, chh))
		f.set_glyph_texture_idx(0, size, code, 0)
	f.set_texture_image(0, size, 0, img)
	return f

const GLYPHS: Dictionary[String, Array] = {
	" ": [".....", ".....", ".....", ".....", ".....", ".....", ".....", ".....", "....."],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#", ".....", "....."],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####.", ".....", "....."],
	"C": [".####", "#....", "#....", "#....", "#....", "#....", ".####", ".....", "....."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####.", ".....", "....."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####", ".....", "....."],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#....", ".....", "....."],
	"G": [".####", "#....", "#....", "#.###", "#...#", "#...#", ".###.", ".....", "....."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#", ".....", "....."],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####", ".....", "....."],
	"J": ["..###", "....#", "....#", "....#", "....#", "#...#", ".###.", ".....", "....."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#", ".....", "....."],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####", ".....", "....."],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#", ".....", "....."],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#", ".....", "....."],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###.", ".....", "....."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#....", ".....", "....."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#", ".....", "....."],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#", ".....", "....."],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####.", ".....", "....."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..", ".....", "....."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###.", ".....", "....."],
	"V": ["#...#", "#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#..", ".....", "....."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#", ".....", "....."],
	"X": ["#...#", ".#.#.", ".#.#.", "..#..", ".#.#.", ".#.#.", "#...#", ".....", "....."],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#..", ".....", "....."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####", ".....", "....."],
	"a": [".....", ".....", ".###.", "....#", ".####", "#...#", ".####", ".....", "....."],
	"b": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "####.", ".....", "....."],
	"c": [".....", ".....", ".####", "#....", "#....", "#....", ".####", ".....", "....."],
	"d": ["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####", ".....", "....."],
	"e": [".....", ".....", ".###.", "#...#", "#####", "#....", ".####", ".....", "....."],
	"f": ["..##.", ".#...", "####.", ".#...", ".#...", ".#...", ".#...", ".....", "....."],
	"g": [".....", ".....", ".####", "#...#", "#...#", ".####", "....#", "#...#", ".###."],
	"h": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "#...#", ".....", "....."],
	"i": ["..#..", ".....", ".##..", "..#..", "..#..", "..#..", ".###.", ".....", "....."],
	"j": ["...#.", ".....", "..##.", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"k": ["#....", "#....", "#..#.", "#.#..", "##...", "#.#..", "#..#.", ".....", "....."],
	"l": [".##..", "..#..", "..#..", "..#..", "..#..", "..#..", ".###.", ".....", "....."],
	"m": [".....", ".....", "##.#.", "#.#.#", "#.#.#", "#.#.#", "#...#", ".....", "....."],
	"n": [".....", ".....", "####.", "#...#", "#...#", "#...#", "#...#", ".....", "....."],
	"o": [".....", ".....", ".###.", "#...#", "#...#", "#...#", ".###.", ".....", "....."],
	"p": [".....", ".....", "####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"q": [".....", ".....", ".####", "#...#", "#...#", ".####", "....#", "....#", "....#"],
	"r": [".....", ".....", "#.##.", "##..#", "#....", "#....", "#....", ".....", "....."],
	"s": [".....", ".....", ".####", "#....", ".###.", "....#", "####.", ".....", "....."],
	"t": [".#...", ".#...", "####.", ".#...", ".#...", ".#...", "..##.", ".....", "....."],
	"u": [".....", ".....", "#...#", "#...#", "#...#", "#...#", ".####", ".....", "....."],
	"v": [".....", ".....", "#...#", "#...#", ".#.#.", ".#.#.", "..#..", ".....", "....."],
	"w": [".....", ".....", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#.", ".....", "....."],
	"x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", ".....", "....."],
	"y": [".....", ".....", "#...#", "#...#", "#...#", ".####", "....#", "#...#", ".###."],
	"z": [".....", ".....", "#####", "...#.", "..#..", ".#...", "#####", ".....", "....."],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###.", ".....", "....."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###.", ".....", "....."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####", ".....", "....."],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####.", ".....", "....."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#.", ".....", "....."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###.", ".....", "....."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###.", ".....", "....."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#...", ".....", "....."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###.", ".....", "....."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###.", ".....", "....."],
	".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##..", ".....", "....."],
	",": [".....", ".....", ".....", ".....", ".....", ".##..", ".##..", "..#..", ".#..."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#..", ".....", "....."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#..", ".....", "....."],
	":": [".....", ".##..", ".##..", ".....", ".##..", ".##..", ".....", ".....", "....."],
	";": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "..#..", ".#...", "....."],
	"'": ["..#..", "..#..", ".#...", ".....", ".....", ".....", ".....", ".....", "....."],
	"\"": [".#.#.", ".#.#.", ".....", ".....", ".....", ".....", ".....", ".....", "....."],
	"-": [".....", ".....", ".....", ".###.", ".....", ".....", ".....", ".....", "....."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", ".....", ".....", "....."],
	"=": [".....", ".....", "#####", ".....", "#####", ".....", ".....", ".....", "....."],
	"/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#....", ".....", "....."],
	"\\": ["#....", ".#...", ".#...", "..#..", "...#.", "...#.", "....#", ".....", "....."],
	"(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#.", ".....", "....."],
	")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#...", ".....", "....."],
	"[": [".###.", ".#...", ".#...", ".#...", ".#...", ".#...", ".###.", ".....", "....."],
	"]": [".###.", "...#.", "...#.", "...#.", "...#.", "...#.", ".###.", ".....", "....."],
	"<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#.", ".....", "....."],
	">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#...", ".....", "....."],
	"%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##", ".....", "....."],
	"&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#", ".....", "....."],
	"#": [".#.#.", ".#.#.", "#####", ".#.#.", "#####", ".#.#.", ".#.#.", ".....", "....."],
	"*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", ".....", ".....", "....."],
	"_": [".....", ".....", ".....", ".....", ".....", ".....", ".....", "#####", "....."],
	"^": ["..#..", ".#.#.", "#...#", ".....", ".....", ".....", ".....", ".....", "....."],
	"~": [".....", ".....", ".#...", "#.#.#", "...#.", ".....", ".....", ".....", "....."],
	"@": [".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".####", ".....", "....."],
	"$": ["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#..", ".....", "....."],
	"€": ["..###", ".#...", "####.", ".#...", "####.", ".#...", "..###", ".....", "....."],
	"≈": [".....", ".....", ".#..#", "#.##.", ".....", ".#..#", "#.##.", ".....", "....."],
	"|": ["..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "....."],
	"`": [".#...", "..#..", ".....", ".....", ".....", ".....", ".....", ".....", "....."],
	"{": ["...#.", "..#..", "..#..", ".#...", "..#..", "..#..", "...#.", ".....", "....."],
	"}": [".#...", "..#..", "..#..", "...#.", "..#..", "..#..", ".#...", ".....", "....."],
	"Ä": ["#...#", ".###.", "#...#", "#####", "#...#", "#...#", "#...#", ".....", "....."],
	"Ö": ["#...#", ".###.", "#...#", "#...#", "#...#", "#...#", ".###.", ".....", "....."],
	"Ü": ["#...#", ".....", "#...#", "#...#", "#...#", "#...#", ".###.", ".....", "....."],
	"ä": [".#.#.", ".....", ".###.", "....#", ".####", "#...#", ".####", ".....", "....."],
	"ö": [".#.#.", ".....", ".###.", "#...#", "#...#", "#...#", ".###.", ".....", "....."],
	"ü": [".#.#.", ".....", "#...#", "#...#", "#...#", "#...#", ".####", ".....", "....."],
	"ß": [".##..", "#..#.", "#..#.", "#.#..", "#..#.", "#...#", "#.##.", ".....", "....."],
	# Waymark (U+E001, private use): a small standing waystone with a carved notch.
	"\ue001": ["..#..", ".###.", ".#.#.", ".###.", ".#.#.", ".###.", "#####", ".....", "....."],
	# Star (U+E002): a bonded species grown to ring 30 in the Spirlog.
	"\ue002": [".....", "..#..", "..#..", "#####", ".###.", ".#.#.", "#...#", ".....", "....."],
	# Backpack (U+E004): a Spirling away on a roaming trip.
	"\ue004": [".....", ".###.", "#...#", "#####", "#.#.#", "#####", "#####", ".....", "....."],
	# Knot (U+E005): a run in the chronicle with kept vows.
	"\ue005": [".....", ".##..", "#..#.", ".##..", ".#.#.", "#...#", ".....", ".....", "....."],
	# Gleam star (U+E006): a four-point sparkle beside a Gleam Spirling (GleamRules.STAR).
	"\ue006": [".....", "..#..", "..#..", "##.##", "..#..", "..#..", ".....", ".....", "....."],
	# Chain (U+E003): a save slot under the Iron Oath.
	"\ue003": [".....", "##...", "#.#..", ".###.", "..#.#", "...##", ".....", ".....", "....."],
}
