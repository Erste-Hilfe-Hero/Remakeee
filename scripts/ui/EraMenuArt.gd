class_name EraMenuArt
extends RefCounted
## Own pixel symbols for the menu screens of Era II and later (docs/ERA_FEEL_MENUS.md): one
## 9x9 symbol per start-menu entry, settings group, satchel pocket and Spirlog tool, the pocket
## pictures of Era III, the mark rosettes and the coloured element badges. Drawn in code like
## ElementIcons; "#" is the outline ink, "+" the fill: the paper's mid tone in Era II (limited
## colour), the symbol's own colour from Era III on.

const SIZE: int = 9
## Pocket picture of the satchel (Era III and later).
const POCKET_ART: Vector2i = Vector2i(40, 22)
const BADGE_H: int = 9

const GLYPHS: Dictionary[String, Array] = {
	"Goals": ["....#....", "...###...", "..#+++#..", ".#++#++#.", ".#+###+#.", ".#++#++#.", "..#+++#..", "...###...", "....#...."],
	"Map book": [".........", ".###.###.", "#+++#+++#", "#+++#+++#", "#+++#+++#", "#+++#+++#", "#+++#+++#", ".###.###.", "....#...."],
	"Ledger": [".#######.", ".#+++++#.", ".#+###+#.", ".#+++++#.", ".#+###+#.", ".#+++++#.", ".#+##++#.", ".#+++++#.", ".#######."],
	"Map": [".........", "##..###..", "#+##+++##", "#+#++#++#", "#+#+#+#+#", "#+#++#++#", "#+##+++##", "##..###..", "........."],
	"Room": ["..#####..", ".#+++++#.", ".#+++++#.", ".#+++++#.", ".#+++#+#.", ".#+++++#.", ".#+++++#.", ".#+++++#.", "#########"],
	"Team": [".........", ".##...##.", ".##.#.##.", "...###...", "..#+++#..", ".#+++++#.", ".#+++++#.", "..#####..", "........."],
	"Satchel": ["...###...", "..#...#..", ".#######.", "#+++++++#", "#++###++#", "#++#+#++#", "#+++++++#", "#+++++++#", ".#######."],
	"Shop": [".........", "..#####..", ".#++#++#.", "#++###++#", ".#++#++#.", "..#+++#..", "...#+#...", "....#....", "........."],
	"Spirlog": [".........", "..#####..", ".#+++++#.", "#++###++#", "#+#+++#+#", "#++###++#", ".#+++++#.", "..#####..", "........."],
	"Travel": ["....#....", "...##....", "..###....", ".####....", "#########", ".#+++++#.", "..#+++#..", "...###...", "........."],
	"Friends": [".##...##.", ".##...##.", ".........", "####.####", "#++#.#++#", "#++#.#++#", "#++#.#++#", "####.####", "........."],
	"Leagues": ["#########", "#+#+++#+#", "#+#+++#+#", ".##+++##.", "...#+#...", "...#+#...", "..#####..", ".#+++++#.", ".#######."],
	"Records": [".........", "......###", "......#+#", "...####+#", "...#+##+#", "####+##+#", "#+##+##+#", "#+##+##+#", "#########"],
	"Storage": [".........", "#########", "#+++++++#", "#########", "#+++#+++#", "#++###++#", "#+++++++#", "#+++++++#", "#########"],
	"Save": [".......##", "......#+#", ".....#+#.", "....#+#..", "...#+#...", "..###....", ".##......", ".#.......", "#########"],
	"Save and to title": ["#####....", "#+++#..#.", "#+++#...#", "#+++#####", "#+++#...#", "#+++#..#.", "#####....", ".........", "........."],
	"Photo": [".........", "..###....", "#########", "#+++++++#", "#++###++#", "#++#.#++#", "#++###++#", "#+++++++#", "#########"],
	"Settings": ["...###...", ".#.#+#.#.", ".#######.", "###+++###", "#++#.#++#", "###+++###", ".#######.", ".#.#+#.#.", "...###..."],
	"Shortcuts": ["....#....", "...#+#...", "...#+#...", "####+####", ".#+++++#.", "..#+++#..", ".#++#++#.", ".#+#.#+#.", ".##...##."],
	"game": ["#########", "#+++++++#", "#+#+++#+#", "#+++++++#", "#+++#+++#", "#+++++++#", "#+#+++#+#", "#+++++++#", "#########"],
	"sound": ["...#####.", "...#+++#.", "...#####.", "...#...#.", "...#...#.", ".###.###.", "#++#.#+#.", "#++#.###.", ".##......"],
	"controls": ["...###...", "...#+#...", "...#+#...", "####+####", "#+++++++#", "####+####", "...#+#...", "...#+#...", "...###..."],
	"display": ["#########", "#+++++++#", "#+++++++#", "#+++++++#", "#+++++++#", "#########", "...###...", "..#####..", "........."],
	"wardrobe": [".##...##.", "#++###++#", "#+++++++#", ".##+++##.", "..#+++#..", "..#+++#..", "..#+++#..", "..#+++#..", "..#####.."],
	"account": ["...###...", "..#+++#..", "..#+++#..", "...###...", ".#######.", "#+++++++#", "#+++++++#", "#+++++++#", "#########"],
	"legal": ["....#....", "#########", ".#..#..#.", "###.#.###", "#+#.#.#+#", ".#..#..#.", "....#....", "...###...", ".#######."],
	"place": ["....#....", "...#+#...", "..#+++#..", ".#+++++#.", "#########", ".#+++++#.", ".#+##++#.", ".#+##++#.", ".#######."],
	"dot": [".........", ".........", "...###...", "..#+++#..", "..#+++#..", "..#+++#..", "...###...", ".........", "........."],
	"pocket0": ["...###...", "...#+#...", "..#####..", ".#+++++#.", ".#++#++#.", ".#+###+#.", ".#++#++#.", ".#+++++#.", "..#####.."],
	"pocket1": ["..#####..", ".#.....#.", ".#.....#.", "..#...#..", "...###...", "..#+++#..", ".#+++++#.", "..#+++#..", "...###..."],
	"pocket2": ["....#....", "...#+#...", "..#+++#..", ".#++#++#.", "#++###++#", ".#++#++#.", "..#+++#..", "...#+#...", "....#...."],
	"pocket3": [".#####...", ".#+++##..", ".#####+#.", "...#.###.", "...#+#...", "...#+#...", "...#+#...", "...#+#...", "...###..."],
	"pocket4": ["..###....", ".#+++#...", ".#+.+#...", ".#+++#...", "..###....", "...#.....", "...###...", "...#.....", "...###..."],
	"mark": ["..#####..", ".#+++++#.", "#++###++#", "#+#+++#+#", "#++###++#", ".#+++++#.", "..##.##..", "..#+.+#..", "..##.##.."],
	"search": ["..###....", ".#+++#...", "#+++++#..", "#+++++#..", "#+++++#..", ".#+++#...", "..####...", ".....##..", "......##."],
	"cry": ["....#....", "...##..#.", ".###.#..#", "#++#..#.#", "#++#..#.#", "#++#..#.#", ".###.#..#", "...##..#.", "....#...."],
	"size": ["#.......#", "##.....##", "#########", "##.....##", "#.......#", ".........", "#.#.#.#.#", "#########", "........."],
}

const COLORS: Dictionary[String, String] = {
	"Goals": "c4432f", "Map book": "8a5a2e", "Ledger": "6a4256", "Map": "3e9a52", "Room": "9a7b55", "Team": "d6a227", "Satchel": "a8582e", "Shop": "3a7be0", "Spirlog": "8a5a80", "Travel": "3a9ab0", "Friends": "e0603a", "Leagues": "e8c050", "Records": "4b6aa6", "Storage": "9a7b55", "Save": "4caf50", "Save and to title": "7d5f5f", "Photo": "8ab8ec", "Settings": "808890", "Shortcuts": "f2d03b", "game": "c4432f", "sound": "8a5a80", "controls": "3a7be0", "display": "3a9ab0", "wardrobe": "e0603a", "account": "d6a227", "legal": "7d5f5f", "place": "a8582e", "dot": "3e9a52", "pocket0": "4caf50", "pocket1": "e8c050", "pocket2": "8ab8ec", "pocket3": "9a7b55", "pocket4": "c4432f", "mark": "e8c050", "search": "8ab8ec", "cry": "e0603a", "size": "3e9a52",
}
## Mark rosette colours by mark id (Era III and later).
const MARK_COLORS: Dictionary[String, String] = {"leader": "c4432f", "gleam": "f2d03b", "favourite": "e0603a",
	"ring10": "9a7b55", "ring25": "b8c0c8", "ring50": "e8c050", "unfurled": "4caf50", "keepsake": "3a7be0", "loyal": "8a5a80"}

static var _cache: Dictionary[String, ImageTexture] = {}

static func has(id: String) -> bool:
	return GLYPHS.has(id)

## The symbol [param id] for era [param era] at [param size] pixels (a multiple of SIZE), or
## null in Era I (no icons) and for an unknown id. [param tint] replaces the symbol's colour.
static func icon(id: String, era: int, size: int = SIZE, tint: Variant = null) -> ImageTexture:
	if era < 2 or not GLYPHS.has(id):
		return null
	var fill: Color = UITheme.MID.lerp(UITheme.BG, 0.45)
	if era >= 3:
		fill = tint as Color if tint is Color else Color(str(COLORS.get(id, "808890")))
	var key: String = "%s:%d:%s:%s" % [id, size, fill.to_html(), UITheme.INK.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_paint(img, id, Vector2i.ZERO, UITheme.INK, fill)
	if size != SIZE:
		img.resize(size, size, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _paint(img: Image, id: String, at: Vector2i, ink: Color, fill: Color) -> void:
	var rows: Array = GLYPHS.get(id, [])
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "#":
				img.set_pixel(at.x + x, at.y + y, ink)
			elif row[x] == "+":
				img.set_pixel(at.x + x, at.y + y, fill)

## The rosette of mark [param mark_id].
static func mark_icon(mark_id: String, era: int, size: int = SIZE) -> ImageTexture:
	return icon("mark", maxi(era, 2), size, Color(str(MARK_COLORS.get(mark_id, "e8c050"))))

## The picture of satchel pocket [param pocket] (0-4): a pouch with its flap and the pocket's
## symbol twice as large on the front.
static func pocket_art(pocket: int, era: int) -> ImageTexture:
	var id: String = "pocket%d" % clampi(pocket, 0, 4)
	var tint: Color = Color(str(COLORS[id])) if era >= 3 else UITheme.MID.lerp(UITheme.BG, 0.45)
	var key: String = "art:%s:%s:%s" % [id, tint.to_html(), UITheme.INK.to_html()]
	if _cache.has(key):
		return _cache[key]
	var w: int = POCKET_ART.x
	var h: int = POCKET_ART.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cloth: Color = tint.lerp(UITheme.BG, 0.55)
	for y: int in h:
		for x: int in w:
			# Pouch: a box with the two top and two bottom corners cut.
			var corner: bool = (x + y < 3) or (w - 1 - x + y < 3) or (x + h - 1 - y < 2) or (w - 1 - x + h - 1 - y < 2)
			if corner:
				continue
			var edge: bool = x == 0 or y == 0 or x == w - 1 or y == h - 1 or (x + y == 3) or (w - 1 - x + y == 3) \
				or (x + h - 1 - y == 2) or (w - 1 - x + h - 1 - y == 2)
			img.set_pixel(x, y, UITheme.INK if edge else cloth)
	# Flap: a shallow V over the top third, with a stitch line under it.
	for x: int in range(1, w - 1):
		var fy: int = 2 + int(6.0 * (1.0 - absf(x - (w - 1) / 2.0) / ((w - 1) / 2.0)))
		img.set_pixel(x, fy, UITheme.INK)
		for y: int in range(1, fy):
			img.set_pixel(x, y, tint.lerp(UITheme.BG, 0.25))
		if x % 2 == 0 and fy + 2 < h - 1:
			img.set_pixel(x, fy + 2, tint.darkened(0.2))
	var glyph := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_paint(glyph, id, Vector2i.ZERO, UITheme.INK, tint)
	img.blend_rect(glyph, Rect2i(0, 0, SIZE, SIZE), Vector2i((w - SIZE) / 2, h - SIZE - 2))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Width of the badge of [param element] in [param style] ("icon" or "colour").
static func badge_width(style: String, text_w: float = 0.0) -> float:
	return ElementIcons.SIZE + 4.0 + (text_w + 3.0 if style == "colour" and text_w > 0.0 else 0.0)

## Draws the element badge at [param at] on [param ci]: Era II the plain symbol, Era III and
## later a chip in the element's colour with the symbol in ink, so it never rests on colour
## alone. Returns the width used.
static func draw_badge(ci: CanvasItem, element: int, at: Vector2, style: String, ink: Color) -> float:
	if style != "colour":
		ci.draw_texture(ElementIcons.texture(element, ink), at + Vector2(0, 1))
		return ElementIcons.SIZE + 1.0
	var w: float = ElementIcons.SIZE + 4.0
	var chip: Color = Elements.color(element)
	ci.draw_rect(Rect2(at, Vector2(w, BADGE_H)), chip)
	ci.draw_rect(Rect2(at, Vector2(w, BADGE_H)), UITheme.INK, false, 1.0)
	var on: Color = Color("1a1420") if chip.get_luminance() > 0.45 else Color("f8f4ea")
	ci.draw_texture(ElementIcons.texture(element, on), at + Vector2(2, 1))
	return w + 1.0
