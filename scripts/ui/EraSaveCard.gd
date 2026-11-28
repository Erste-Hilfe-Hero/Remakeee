class_name EraSaveCard
extends Control
## The save card on the title, the Continue row and the slot lists (docs/ERA_LOOK_TITLE.md):
## a frame in the style of the era the save is in, a small picture of that era's lake scene,
## the era's name and the save's place and play time. A save from Era I shows four inks next
## to a save from Era IV in full colour, so the player sees at a glance how far a journey is.

## Card height and picture size at UI scale 1.
const HEIGHT: int = 26
const THUMB: Vector2 = Vector2(30, 20)

var era: int = 0
var slot: int = 0
var _thumb: Control
var _name: Label
var _line: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	_thumb = Control.new()
	_thumb.clip_contents = true
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumb.draw.connect(func() -> void:
		if era > 0:
			EraBackdrop.paint(_thumb, Rect2(Vector2.ZERO, _thumb.size), era, 0.0, true))
	add_child(_thumb)
	_name = _label()
	_line = _label()
	resized.connect(_layout)
	_layout()
	visible = era > 0

func _label() -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _layout() -> void:
	var k: int = EraMomentLayer.ui_scale(get_viewport_rect().size.x) if is_inside_tree() else 1
	_thumb.position = Vector2(4, 3) * k
	_thumb.size = THUMB * k
	var x: float = (THUMB.x + 8.0) * k
	for l: Label in [_name, _line]:
		l.add_theme_font_size_override("font_size", PixelFont.BASE_SIZE * k)
		l.size = Vector2(maxf(size.x - x - 4.0 * k, 10.0), 10.0 * k)
	_name.position = Vector2(x, 3.0 * k)
	_line.position = Vector2(x, 13.0 * k)

## Card height on a screen [param width] px wide.
static func height_for(width: float) -> int:
	return HEIGHT * EraMomentLayer.ui_scale(width)

## True when a screen of [param size] has room for the card between the title picture and a
## five-row menu. 16:9 phones and tablets have none: there the card lies over the picture's
## lower edge, and only while a slot list is open.
static func fits_band(size: Vector2, art_h: int = -1) -> bool:
	var k: int = EraMomentLayer.ui_scale(size.x)
	return size.y >= (art_h if art_h >= 0 else EraTitleArt.art_height(size.x)) + (HEIGHT + 110) * k

## The two lines of a card: the era ("Era II: Wash") and the save's summary line.
static func card_lines(e: int, summary: String) -> Array[String]:
	return [EraMoments.era_label(e), summary]

## Shows slot [param n]; hides the card for an empty slot.
func show_slot(n: int) -> void:
	if n == slot and visible == (era > 0):
		return
	slot = n
	var used: bool = n >= 1 and n <= SaveManager.SLOTS
	show_save(EraMoments.slot_era(n) if used else 0, SaveManager.slot_summary(n) if used else "")

func show_save(e: int, summary: String) -> void:
	era = clampi(e, 0, 5)
	visible = era > 0
	if era <= 0:
		return
	var lines: Array[String] = card_lines(era, summary)
	_name.text = lines[0]
	_line.text = lines[1]
	# A line too long for the doubled font on the wide screens keeps the plain size.
	var k: int = EraMomentLayer.ui_scale(get_viewport_rect().size.x) if is_inside_tree() else 1
	for l: Label in [_name, _line]:
		var font: Font = l.get_theme_font("font")
		l.add_theme_font_size_override("font_size", PixelFont.BASE_SIZE * EraMomentLayer.fit_scale(font, l.text, k, l.size.x))
	var ink: Color = EraMoments.col(era, "ink")
	_name.add_theme_color_override("font_color", EraMoments.col(era, "accent").darkened(0.35) if era > 1 else ink)
	_line.add_theme_color_override("font_color", ink)
	_thumb.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if era <= 0:
		return
	EraBackdrop.draw_frame(self, Rect2(Vector2.ZERO, size), era)
	draw_rect(Rect2(_thumb.position - Vector2.ONE, _thumb.size + Vector2(2, 2)), EraMoments.col(era, "ink"), false, 1.0)

## A 10 px badge of era [param e] for list rows: the era's sky over its water with its sun.
static func badge(e: int) -> ImageTexture:
	e = clampi(e, 1, 5)
	if _badges.has(e):
		return _badges[e]
	var img: Image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(EraMoments.col(e, "ink"))
	for y: int in range(1, 9):
		for x: int in range(1, 9):
			var c: Color = EraMoments.col(e, "sky_top") if y < 4 else (EraMoments.col(e, "sky_low") if y < 6 else EraMoments.col(e, "water"))
			if y == 7 and x % 3 == 0:
				c = EraMoments.col(e, "glint")
			img.set_pixel(x, y, c)
	for p: Vector2i in [Vector2i(6, 2), Vector2i(7, 2), Vector2i(6, 3), Vector2i(7, 3)]:
		img.set_pixelv(p, EraMoments.col(e, "sun"))
	_badges[e] = ImageTexture.create_from_image(img)
	return _badges[e]

static var _badges: Dictionary[int, ImageTexture] = {}

## Size of the team lead's picture on the Continue row (200 list item 2).
const LEAD_SIZE: int = 14

## Species of the first Spirling in the team of save [param d], or "" without one.
static func lead_species(d: Dictionary) -> String:
	var party: Variant = d.get("party", [])
	if party is Array and not (party as Array).is_empty() and (party as Array)[0] is Dictionary:
		return str(((party as Array)[0] as Dictionary).get("species", ""))
	return ""

## The Continue row's icon (200 list item 2): the era badge of [param e] and, beside it, the
## team lead [param species] as a small picture. Only the badge when there is no picture.
static func continue_icon(e: int, species: String) -> Texture2D:
	var pic: Texture2D = MiniSprite.of(species, LEAD_SIZE) if not species.is_empty() and Database.species(species) != null else null
	if pic == null:
		return badge(e)
	var lead: Image = pic.get_image()
	if lead == null:
		return badge(e)
	lead = lead.duplicate()
	if lead.is_compressed():
		lead.decompress()
	lead.convert(Image.FORMAT_RGBA8)
	var b: Image = badge(e).get_image()
	var img: Image = Image.create(b.get_width() + 2 + LEAD_SIZE, LEAD_SIZE, false, Image.FORMAT_RGBA8)
	img.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, (LEAD_SIZE - b.get_height()) / 2))
	img.blit_rect(lead, Rect2i(Vector2i.ZERO, lead.get_size()), Vector2i(b.get_width() + 2, 0))
	return ImageTexture.create_from_image(img)
