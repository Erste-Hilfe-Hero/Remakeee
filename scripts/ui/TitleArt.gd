class_name TitleArt
extends Control
## Title illustration: Brindlewick lighthouse on its rock at night, the beam sweeping across
## the lake, and the three Spirlings that sheltered there from the first Rift storm.
## Built from the Era I tiles and sprites plus primitives; no extra image files.

const LOGO: String = "CHIMORA"
const LOGO_SCALE: int = 3
const BEAM_SPEED: float = 0.6
const STARTERS: Array[String] = ["mossling", "kindlop", "puddlet"]
const TILE: int = 16

var _t: float = 0.0
var _sprites: Array[Texture2D] = []
var _atlas: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for sp: String in STARTERS:
		var p: String = "res://art/era1/spirlings/%s_front.png" % sp
		_sprites.append(load(p) if ResourceLoader.exists(p) else null)
	if ResourceLoader.exists(TilesetFactory.ATLAS_PATH):
		_atlas = load(TilesetFactory.ATLAS_PATH)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var lake_y: float = floorf(h * 0.62)
	# Night sky: ink with a dithered band toward the horizon.
	draw_rect(Rect2(0, 0, w, lake_y), UITheme.INK)
	for y: int in range(int(lake_y) - 14, int(lake_y)):
		for x: int in int(w):
			if (x + y) % 2 == 0 and y > lake_y - 14 + (x % 3):
				draw_rect(Rect2(x, y, 1, 1), UITheme.MID)
	for i: int in 22:
		var sx: float = fmod(i * 53.0 + 11.0, w)
		var sy: float = fmod(i * 31.0 + 5.0, lake_y - 20)
		if int(_t * 2.0 + i) % 7 != 0:
			draw_rect(Rect2(sx, sy, 1, 1), UITheme.BG)
	# Moon with a bite taken out.
	draw_circle(Vector2(w - 22, 58), 6, UITheme.BG)
	draw_circle(Vector2(w - 19, 56), 5, UITheme.INK)
	# Far shore.
	var shore := PackedVector2Array([Vector2(0, lake_y)])
	for x: int in range(0, int(w) + 8, 8):
		shore.append(Vector2(x, lake_y - 4 - 3 * absf(sin(x * 0.09))))
	shore.append(Vector2(w, lake_y))
	draw_colored_polygon(shore, UITheme.MID)
	# Lake with moving glints.
	draw_rect(Rect2(0, lake_y, w, h - lake_y), UITheme.MID)
	for i: int in 10:
		var gy: float = lake_y + 4 + (i % 5) * 6
		var gx: float = fmod(i * 41.0 + _t * (4.0 + i % 3), w + 20) - 10
		draw_rect(Rect2(roundf(gx), gy, 6 + i % 3 * 2, 1), UITheme.ACCENT)
	_draw_lighthouse(Vector2(12, lake_y - 3 * TILE + 2), lake_y)
	_draw_logo(Vector2(w / 2.0, 6))
	# The three storm guests on the near shore.
	var shore_y: float = h - 6
	draw_rect(Rect2(0, shore_y - 2, w, h - shore_y + 2), UITheme.ACCENT)
	draw_rect(Rect2(0, shore_y - 2, w, 1), UITheme.INK)
	for i: int in _sprites.size():
		if _sprites[i] == null:
			continue
		var bob: float = roundf(sin(_t * 2.0 + i * 2.1))
		var x: float = w * 0.5 - 60 + i * 42
		draw_texture_rect(_sprites[i], Rect2(x, shore_y - 44 + bob, 40, 40), false)

func _draw_lighthouse(at: Vector2, lake_y: float) -> void:
	# Rock.
	var rock := PackedVector2Array([Vector2(at.x - 10, lake_y + 6), Vector2(at.x - 4, at.y + 3 * TILE - 6),
		Vector2(at.x + TILE + 6, at.y + 3 * TILE - 8), Vector2(at.x + TILE + 14, lake_y + 6)])
	draw_colored_polygon(rock, UITheme.INK)
	if _atlas == null:
		return
	var col: Dictionary[int, int] = {0: TilesetFactory.Kind.LAMP, 1: TilesetFactory.Kind.TOWER, 2: TilesetFactory.Kind.DOOR}
	for row: int in 3:
		var src := Rect2(col[row] * TILE, 0, TILE, TILE)
		var dst := Rect2(at + Vector2(0, row * TILE), Vector2(TILE, TILE))
		if row != 1:
			# Those tiles have a ground background; draw only the middle columns.
			src = Rect2(src.position + Vector2(2, 0), Vector2(12, TILE))
			dst = Rect2(dst.position + Vector2(2, 0), Vector2(12, TILE))
		draw_texture_rect_region(_atlas, dst, src)
	# Sweeping beam from the lamp.
	var lamp := at + Vector2(8, 8)
	var a: float = sin(_t * BEAM_SPEED) * 0.5 + 0.1
	var len: float = size.x * 1.2
	var p1: Vector2 = lamp + Vector2(cos(a - 0.08), sin(a - 0.08)) * len
	var p2: Vector2 = lamp + Vector2(cos(a + 0.08), sin(a + 0.08)) * len
	draw_colored_polygon(PackedVector2Array([lamp, p1, p2]), Color(UITheme.ACCENT, 0.35))

func _draw_logo(center: Vector2) -> void:
	var font: Font = get_theme_default_font()
	var fs: int = PixelFont.BASE_SIZE * LOGO_SCALE
	var width: float = font.get_string_size(LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(roundf(center.x - width / 2.0), center.y + PixelFont.ASCENT * LOGO_SCALE)
	# Ink outline (8 offsets), a mid drop shadow, then paper letters.
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
		draw_string(font, pos + o + Vector2(2, 2), LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
	draw_string(font, pos + Vector2(2, 2), LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.MID)
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, pos + o, LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
	draw_string(font, pos, LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.BG)
	var sub: String = Loc.t("The Hush of Veydal")
	var sw: float = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE).x
	draw_string(font, Vector2(roundf(center.x - sw / 2.0), center.y + PixelFont.ASCENT * LOGO_SCALE + 14), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE, UITheme.ACCENT)
