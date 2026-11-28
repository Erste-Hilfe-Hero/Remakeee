class_name ShopArt
extends RefCounted
## Pixel icons and tag colours of the shop screen (ShopScreen). Drawn from 12x12 letter grids in
## the era's palette, so every era's shop keeps its own ink and paper. Own art, no store assets.

const SIZE: int = 12
## Letters of the grids: "." is empty, k/w/a/m are the era's ink, paper, accent and mid tone,
## "j" is the colour of the offer (jackets), the rest are fixed colours.
const FIXED: Dictionary[String, Color] = {"c": Color("5fc8e0"), "d": Color("2f7f9a"), "g": Color("e8b830"),
	"o": Color("a0701a"), "r": Color("c0392b"), "s": Color("c8ced6"), "n": Color("8a5a2a"), "G": Color("5aa84a"),
	"D": Color("2f6a2a"), "p": Color("7a4a9a")}

const GRIDS: Dictionary[String, Array] = {
	"gem": ["............", "...kkkkkk...", "..kwwccccdk.", ".kwwccccccdk", ".kkkkkkkkkkk", "..kcccccddk.",
		"...kccccdk..", "....kccdk...", ".....kdk....", "......k.....", "............", "............"],
	"gem_bag": ["....kkkk....", ".....kk.....", "....kwwk....", "...knnnnk...", "..knnnnnnk..", ".knnccnnnnk.",
		".knccccnnnk.", ".knnccnnnnk.", ".knnnnnnnnk.", "..knnnnnnk..", "...kkkkkk...", "............"],
	"star": [".....kk.....", "....kwgk....", "....kggk....", "kkkkkggkkkkk", "kggggggggggk", ".kggggggggk.",
		"..kggggggk..", "..kggggggk..", ".kgggkkgggk.", ".kggk..kggk.", "kggk....kggk", "kkk......kkk"],
	"sword": ["..........kk", ".........kwk", "........kwsk", ".......kwsk.", "......kwsk..", ".k...kwsk...",
		".kk.kwsk....", "..kkwsk.....", "..kgkk......", ".knk........", "knk.........", "kk.........."],
	"shield": ["............", ".kkkkkkkkkk.", ".kwsssssssk.", ".kwsssgsssk.", ".ksssgggssk.", ".kssssgsssk.",
		"..kssssssk..", "..kssssssk..", "...kssssk...", "....kssk....", ".....kk.....", "............"],
	"chest": ["............", "............", ".kkkkkkkkkk.", ".knwnnnnnnk.", ".knnnnnnnnk.", "kkkkkkkkkkkk",
		"knnnkggknnnk", "knnnnkknnnnk", "knnnnnnnnnnk", "kgnnnnnnnngk", "kkkkkkkkkkkk", "............"],
	"scroll": ["............", "..kkkkkkkk..", "..kwwwwwwk..", "..kwkkkkwk..", "..kwwwwwwk..", "..kwkkkkwk..",
		"..kwwwwwwk..", "..kwkkkwwk..", "..kwwwwwwk..", "..kwwwwrrk..", "..kkkkkrrk..", "............"],
	"hat": ["............", "............", "............", "....kkkk....", "...knwnnk...", "...knnnnk...",
		"...krrrrk...", "..kknnnnkk..", ".knnnnnnnnk.", "kkkkkkkkkkkk", "............", "............"],
	"dots": ["............", "............", "............", "............", "............", ".kk..kk..kk.",
		".kk..kk..kk.", "............", "............", "............", "............", "............"],
	"crystal": [".....kk.....", "....kwGk....", "...kwGGGk...", "...kwGGGk...", "..kwGGGGDk..", "..kwGGGGDk..",
		"..kGGGGGDk..", "...kGGGDk...", "...kGGGDk...", "....kGDk....", ".....kk.....", "............"],
	"potion": ["....knnk....", "....kwwk....", "....kwwk....", "...kkwwkk...", "..kwwwwwwk..", ".kwrrrrrrrk.",
		".krrrrrrrrk.", ".krwrrrrrrk.", ".krrrrrrrrk.", "..krrrrrrk..", "...kkkkkk...", "............"],
	"coin": ["............", "...kkkkkk...", "..kwgggggk..", ".kwgggggggk.", ".kggokkoggk.", ".kggoggoggk.",
		".kggoggoggk.", ".kggokkoggk.", ".kgggggggok.", "..kggggook..", "...kkkkkk...", "............"],
	"crown": ["............", "............", "k....kk....k", "kk..kggk..kk", "kgkkggggkkgk", "kggggggggggk",
		"kggrggggrggk", "kggggggggggk", "kkkkkkkkkkkk", "............", "............", "............"],
	"box": ["............", "............", ".kkkkkkkkkk.", ".kaaaaaaaak.", ".kkkkkkkkkk.", ".kaaakkaaak.",
		".kaaaaaaaak.", ".kaaaaaaaak.", ".kaaaaaaaak.", ".kkkkkkkkkk.", "............", "............"],
	"boot": ["............", "...kkkk.....", "...knnk.....", "...knnk.....", "...knnk.....", "...knnk.....",
		"...knnkkk...", "...knnnnnk..", "..knnnnnnnk.", "..kkkkkkkkk.", "............", "............"],
	"book": ["............", ".kkkkkkkk...", ".kpppppppk..", ".kpwwwwwpk..", ".kpppppppk..", ".kpppppppk..",
		".kpppppppk..", ".kpppppppk..", ".kpppppppk..", ".kkkkkkkkk..", ".kwwwwwwwk..", ".kkkkkkkkk.."],
	"jacket": ["............", "...kkkkkk...", "..kjjkkjjk..", ".kjjjkkjjjk.", "kjjjjkkjjjjk", "kjkjjkkjjkjk",
		"kjkjjkkjjkjk", "kkkjjkkjjkkk", "..kjjkkjjk..", "..kjjkkjjk..", "..kkkkkkkk..", "............"],
	"picture": ["............", "kkkkkkkkkkkk", "kcccccccccck", "kcccccccggck", "kcccccccggck", "kccGccccccck",
		"kcGGGcccGcck", "kGGGGGcGGGGk", "kGGGGGGGGGGk", "kkkkkkkkkkkk", "............", "............"],
	"frame": ["............", "............", "kkkkkkkkkkkk", "kaaaaaaaaaak", "kawwwwwwwwak", "kawkkkkkkwak",
		"kawwwwwwwwak", "kawkkkkwwwak", "kawwwwwwwwak", "kaaaaaaaaaak", "kkkkkkkkkkkk", "............"],
	"card": ["............", "............", "kkkkkkkkkkkk", "kwkwwwwwwkwk", "kwwkwwwwkwwk", "kwwwkwwkwwwk",
		"kwwwwkkwwwwk", "kwwwwwwwwwwk", "kwwwwwwwrrwk", "kkkkkkkkkkkk", "............", "............"],
	# Bond charms (1.3.2): one look per charm of the family, held out before Mine!, never thrown.
	"charm_kin": ["....kkkk....", "...k....k...", "...k....k...", "....k..k....", ".....kk.....", "....kaak....", "...kaawak...", "..kaawwaak..", "...kaaaak...", "....kaak....", ".....kk.....", "............"],
	"charm_quill": ["..........kk", ".........kpk", "........kppk", ".......kppk.", "......kppk..", ".....kppk...", "....kppk....", "...kwpk.....", "..kwk.......", ".kk.........", "kk..........", "k..kkk......"],
	"charm_thread": ["............", ".rrr....rrr.", "r...r..r...r", "r....rr....r", "r....rr....r", "r...r..r...r", ".rrr....rrr.", "......r.....", ".....r......", "......r.....", ".....r......", "............"],
	"charm_wick": [".....s...gg.", "....sws..g..", "....sws..gg.", ".....s......", ".....k......", "...kkkkk....", "...kwwmk....", "...kwwmk....", "...kwwmk....", "...kwwmk....", ".kkkkkkkkk..", "............"],
	"charm_bell": [".....kk.....", "....kggk....", "...kgwggk...", "...kgwggk...", "..kgwgggok..", "..kggggggk..", ".kgggggggok.", "kkkkkkkkkkkk", ".....kk.....", "............", "..c.....c...", ".c.....c...."],
	"charm_ribbon": [".kk......kk.", ".kGk....kGk.", ".kGGk..kGGk.", ".kGGGkkGGGk.", ".kGGGkkGGGk.", ".kGGk..kGGk.", ".kGk.kk.kGk.", ".kk.kGGk.kk.", "...kGk.kGk..", "..kGk...kGk.", "..kk.....kk.", "............"],
	"charm_feather": [".........kk.", "........kwck", ".......kwwck", "......kwwck.", ".....kwwcck.", "....kwwcck..", "...kwwcck...", "..kwwcck....", "..kwcck.....", ".kkkk.......", ".k..........", "k..........."],
	"charm_leaf": ["............", ".......kkk..", "......kGGGk.", ".....kGGGDk.", "....kGGGDGk.", "...kGGGDGGk.", "..kGGDGGGk..", "..kGDGGGk...", "..kDkkkk....", ".kk.........", "k.....m.m.m.", "............"],
	"charm_lantern": [".....kk.....", "....k..k....", "..kkkkkkkk..", "..kwccccdk..", "..kcwccdck..", "..kccwdcck..", "..kccdwcck..", "..kcdccwck..", "..kdccccwk..", "..kkkkkkkk..", "...knnnnk...", "....kkkk...."],
	"charm_crest": [".g...gg...g.", "..g..gg..g..", "kkkkkkkkkkkk", "kppppggppppk", "kpppggggpppk", "kppgwggggppk", "kpgwggggggpk", ".kppppppppk.", "..kppppppk..", "...kppppk...", "....kppk....", ".....kk....."],
	"charm_page": ["............", ".kkkkk.kkkkk", "kwwwwwkwwwwk", "kwmmmwkwmmwk", "kwwwwwkwwwwk", "kwmmmwkwmmmk", "kwwwwwkwwwwk", "kwmmwwkwmmwk", "kkkkkkkkkkkk", ".....kr.....", ".....rr.....", "....r..r...."],
	"charm_tag": [".....kk.....", "....k..k....", ".....kk.....", "...kkkkkk...", "...kmmmmk...", "...kmwwmk...", "...kmmmmk...", "...kmwwmk...", "...kmmmmk...", "....kmmk....", ".....kk.....", "............"],
}

## Icon of each shop tab, in ShopScreen.TABS order.
const TAB_ICONS: Dictionary[String, String] = {"featured": "star", "advantages": "sword", "packs": "chest",
	"pass": "scroll", "looks": "hat", "riftglass": "gem", "more": "dots"}

static var _cache: Dictionary[String, ImageTexture] = {}

## Grids that are not 12x12 or use a letter without a colour (empty = fine). Used by the tests.
static func problems() -> Array[String]:
	var out: Array[String] = []
	for k: String in GRIDS:
		var g: Array = GRIDS[k]
		if g.size() != SIZE:
			out.append("%s: %d rows" % [k, g.size()])
		for row: Variant in g:
			if str(row).length() != SIZE:
				out.append("%s: row %s" % [k, row])
			for ch: String in str(row):
				if ch != "." and not ch in ["k", "w", "a", "m", "j"] and not FIXED.has(ch):
					out.append("%s: letter %s" % [k, ch])
	for t: String in TAB_ICONS:
		if not GRIDS.has(TAB_ICONS[t]):
			out.append("missing_tab_icon:" + t)
	return out

## The colour of one grid letter in the current era palette.
static func color_of(ch: String, offer_color: Color) -> Color:
	match ch:
		"k": return UITheme.INK
		"w": return UITheme.BG
		"a": return UITheme.ACCENT
		"m": return UITheme.MID
		"j": return offer_color
	return FIXED.get(ch, Color(0, 0, 0, 0))

## Icon [param key] scaled by [param scale], cached per palette.
static func icon(key: String, scale: int = 1, offer_color: Color = Color("3a5a9a")) -> ImageTexture:
	var grid: Array = GRIDS.get(key, GRIDS["star"])
	var ck: String = "%s:%d:%s:%s:%s" % [key, scale, offer_color.to_html(), UITheme.INK.to_html(), UITheme.BG.to_html()]
	if _cache.has(ck):
		return _cache[ck]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in SIZE:
		var row: String = str(grid[y])
		for x: int in mini(SIZE, row.length()):
			if row[x] != ".":
				img.set_pixel(x, y, color_of(row[x], offer_color))
	if scale > 1:
		img.resize(SIZE * scale, SIZE * scale, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

## Which icon an offer gets: its own "icon" file when it exists, else one picked by what it is.
static func icon_key(o: Dictionary) -> String:
	var id: String = str(o.get("id", ""))
	var tab: String = str(o.get("tab", ""))
	# Charm offers show the charm they hold (the first charm among the grants).
	for g: Dictionary in ShopCatalog.contents(o):
		if str(g.get("t", "")) == "item" and Database.item(str(g.get("id", ""))).has("charm"):
			return charm_icon_key(str(g.id))
	if tab == "riftglass" or str(o.get("kind", "")) == "currency":
		var n: int = 0
		for e: Dictionary in ShopCatalog.contents(o):
			if str(e.t) == "rg":
				n += int(e.n)
		return "gem_bag" if n >= 1000 else "gem"
	if tab == "packs":
		return "chest"
	if tab == "pass" or str(o.get("store_type", "")) == "subscription":
		return "scroll"
	if tab == "looks":
		var key: String = ShopMenu.look_key(o)
		if key.begins_with("hat_"):
			return "hat"
		if key.begins_with("backdrop_"):
			return "picture"
		if key.begins_with("frame_") or key.begins_with("card_frame_"):
			return "frame"
		if str(o.get("slot", "")) == "gift_card":
			return "card"
		return "jacket" if o.has("color") else "frame"
	for pair: Array in [["power_seal", "sword"], ["guard_seal", "shield"], ["glass_shield", "shield"], ["speed_seal", "boot"],
			["swift", "boot"], ["crit_seal", "star"], ["ring_crown", "crown"], ["coin", "coin"], ["merchant", "coin"],
			["vault", "coin"], ["storage", "box"], ["team_slot", "box"], ["box", "box"], ["script", "book"],
			["memory", "book"], ["lore", "book"], ["atlas", "book"], ["tonic", "potion"], ["elixir", "potion"],
			["breath", "potion"], ["crystal", "crystal"], ["growth", "crystal"], ["prism", "crystal"], ["spark", "crystal"],
			["gleam", "crystal"], ["mend", "potion"], ["purse", "coin"], ["compass", "book"], ["seal", "shield"]]:
		if id.contains(str(pair[0])):
			return str(pair[1])
	return "star"

## Grid key of the bond charm [param item_id]: its own look from items.json "charm.icon", or the
## plain tag for the other bond items (lures, seals, Echo Shell).
static func charm_icon_key(item_id: String) -> String:
	var c: Variant = Database.item(item_id).get("charm")
	if c is Dictionary and GRIDS.has(str((c as Dictionary).get("icon", ""))):
		return str(c.icon)
	return "charm_tag"

## The picture of an offer: the file named in "icon" when it exists, else the drawn icon.
static func offer_icon(o: Dictionary, scale: int = 1) -> Texture2D:
	var path: String = str(o.get("icon", ""))
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var t: Texture2D = load(path) as Texture2D
		if t != null:
			return t
	return icon(icon_key(o), scale, Color(str(o.get("color", "#3a5a9a"))))

# --- Tags ------------------------------------------------------------------------------------

## Background and text colour of each tag kind. Text reaches 4.5:1 on its background (tests).
const TAG_COLORS: Dictionary[String, Array] = {
	"bestseller": [Color("e8b830"), Color("2a1e2c")],
	"best_value": [Color("2f6a2a"), Color("f4f1e6")],
	"hot": [Color("a8322a"), Color("f4f1e6")],
	"new": [Color("2a5a8a"), Color("f4f1e6")],
	"limited": [Color("6a3a8a"), Color("f4f1e6")],
	"discount": [Color("a8322a"), Color("f4f1e6")],
	"bonus": [Color("2f6a2a"), Color("f4f1e6")],
	"double": [Color("e8b830"), Color("2a1e2c")],
	"time": [Color("2a1e2c"), Color("f4f1e6")],
	"owned": [Color("7d5f5f"), Color("f4f1e6")],
}

## [background, text] of a tag; high contrast turns every tag into ink on paper.
static func tag_colors(kind: String) -> Array:
	if UITheme.high_contrast:
		return [UITheme.INK, UITheme.BG]
	return TAG_COLORS.get(kind, [UITheme.INK, UITheme.BG])

## A small tag label ("Bestseller", "-20 %").
static func tag(text: String, kind: String) -> Label:
	var l := Label.new()
	var c: Array = tag_colors(kind)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c[0]
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_color_override("font_color", c[1])
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.name = "tag_" + kind
	return l
