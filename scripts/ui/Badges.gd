class_name Badges
extends RefCounted
## 16x16 achievement badges (plan area 8), drawn in code like the rest of Chimora's UI art:
## a round plate with a rim in the tier colour (bronze, silver, gold, or ink for single
## achievements) and a motif per category. Locked badges are drawn in greys.

const SIZE: int = 16
## 10x10 motifs, one per category.
const MOTIFS: Dictionary = {
	"bond": [
		"..........",
		".##....##.",
		"####..####",
		"##########",
		"##########",
		".########.",
		"..######..",
		"...####...",
		"....##....",
		"..........",
	],
	"battle": [
		"#........#",
		".#......#.",
		"..#....#..",
		"...#..#...",
		"....##....",
		"....##....",
		"...#..#...",
		".##....##.",
		".##....##.",
		"..........",
	],
	"explore": [
		"....##....",
		"...####...",
		"..##..##..",
		"....##....",
		"....##....",
		"....##....",
		"..######..",
		".##....##.",
		".########.",
		"..........",
	],
	"collect": [
		"..........",
		"..######..",
		".##.##.##.",
		"##########",
		".########.",
		"..######..",
		"...####...",
		"....##....",
		"..........",
		"..........",
	],
	"events": [
		"....##....",
		"....##....",
		"##########",
		".########.",
		"..######..",
		"..######..",
		".###..###.",
		".##....##.",
		"..........",
		"..........",
	],
	"challenge": [
		".#.#..#.#.",
		".######.##",
		".########.",
		"..######..",
		"..##..##..",
		"..##..##..",
		"..######..",
		".########.",
		".########.",
		"..........",
	],
}
const RIMS: Dictionary = {"bronze": Color("a0643a"), "silver": Color("b8c0c8"), "gold": Color("e0b040"), "": Color("2f7f7a")}
const PLATES: Dictionary = {"bond": Color("6a3f6e"), "battle": Color("a2502e"), "explore": Color("3f6e4a"),
	"collect": Color("2f5f8a"), "events": Color("b08a2e"), "challenge": Color("3a3550")}
const INK: Color = Color("f4ead2")
const LOCKED_RIM: Color = Color("6b6b6b")
const LOCKED_PLATE: Color = Color("3c3c3c")
const LOCKED_INK: Color = Color("7d7d7d")

static var _cache: Dictionary = {}

## The badge image for achievement [param a] (a row of data/achievements.json).
static func image(a: Dictionary, unlocked: bool) -> Image:
	var cat: String = str(a.get("cat", "challenge"))
	var tier: String = str(a.get("tier", ""))
	var rim: Color = RIMS.get(tier, RIMS[""]) if unlocked else LOCKED_RIM
	var plate: Color = PLATES.get(cat, PLATES.challenge) if unlocked else LOCKED_PLATE
	var ink: Color = INK if unlocked else LOCKED_INK
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = (SIZE - 1) / 2.0
	for y: int in SIZE:
		for x: int in SIZE:
			var d: float = Vector2(x - c, y - c).length()
			if d <= 7.6:
				img.set_pixel(x, y, rim if d > 6.3 else plate)
	var motif: Array = MOTIFS.get(cat, MOTIFS.challenge)
	for y: int in motif.size():
		var row: String = motif[y]
		for x: int in row.length():
			if row[x] == "#":
				img.set_pixel(3 + x, 3 + y, ink)
	return img

static func texture(a: Dictionary, unlocked: bool) -> ImageTexture:
	var key: String = "%s:%s" % [a.get("id", ""), unlocked]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(image(a, unlocked))
	return _cache[key]
