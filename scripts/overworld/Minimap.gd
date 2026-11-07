class_name Minimap
extends Control
## Small map in the top right corner (area 3 items 1270-1272): 12 x 12 cells around the player,
## 3 pixels per cell, 36 x 36 pixels. Ground is paper, solid cells grey, water mid brown;
## cells not yet seen stay dark. Single pixels mark warps (accent), the rest point and
## Wayfarers still to meet (ink); the player is a full ink cell. A hidden find already taken
## stays as a filled cross over its cell (plan item 1097). UITheme colours only.

const CELLS: int = 12
const PX: int = 3
const SIDE: int = CELLS * PX

var map: MapData
var center: Vector2i = Vector2i.ZERO
## Cells of Wayfarers the player has not beaten yet.
var wayfarers: Array[Vector2i] = []

func _ready() -> void:
	name = "minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -SIDE - 6
	offset_right = -6
	offset_top = 24
	offset_bottom = 24 + SIDE
	custom_minimum_size = Vector2(SIDE, SIDE)

## Flags used for taken finds (GameState.flags in the game, tests pass their own).
var flags: Dictionary = {}

func refresh(m: MapData, cell: Vector2i, trainers: Array[Vector2i] = [], f: Variant = null) -> void:
	flags = f if f is Dictionary else GameState.flags
	map = m
	center = cell
	wayfarers = trainers
	visible = Survey.minimap_shows(m)
	queue_redraw()

## Top left cell shown (the player sits at cell 6, 6 of the 12 x 12 window).
func origin() -> Vector2i:
	return center - Vector2i(CELLS / 2, CELLS / 2)

## Colour of one shown cell.
func cell_color(c: Vector2i) -> Color:
	if map == null or not map.in_bounds(c):
		return UITheme.INK
	if not Survey.is_seen(map, c):
		return Color(UITheme.INK, 0.6)
	if map.kind_at(c) == TilesetFactory.Kind.WATER:
		return UITheme.MID
	return UITheme.BG if map.is_walkable(c) else UITheme.DISABLED

func _draw() -> void:
	draw_rect(Rect2(-1, -1, SIDE + 2, SIDE + 2), UITheme.INK)
	if map == null:
		return
	var o: Vector2i = origin()
	for y: int in CELLS:
		for x: int in CELLS:
			draw_rect(Rect2(x * PX, y * PX, PX, PX), cell_color(o + Vector2i(x, y)))
	for w: Dictionary in map.warps:
		_dot(Vector2i(int(w.x), int(w.y)), UITheme.ACCENT)
	if map.heal_point.x >= 0:
		_dot(map.heal_point, UITheme.INK)
	for c: Vector2i in wayfarers:
		_dot(c, UITheme.INK)
	for c: Vector2i in taken_finds():
		_cross(c, UITheme.MID)
	var p: Vector2i = center - o
	draw_rect(Rect2(p.x * PX, p.y * PX, PX, PX), UITheme.INK)

func _dot(c: Vector2i, col: Color) -> void:
	var l: Vector2i = c - origin()
	if l.x < 0 or l.y < 0 or l.x >= CELLS or l.y >= CELLS or not Survey.is_seen(map, c):
		return
	draw_rect(Rect2(l.x * PX + 1, l.y * PX + 1, 1, 1), col)

## Cells of hidden finds on this map that are already taken (plan item 1097).
func taken_finds() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if map == null:
		return out
	for sc: Dictionary in map.secrets:
		if bool(flags.get(str(sc.get("flag", "")), false)):
			out.append(Vector2i(int(sc.x), int(sc.y)))
	return out

## A filled cross (plus) over the whole 3 x 3 cell.
func _cross(c: Vector2i, col: Color) -> void:
	var l: Vector2i = c - origin()
	if l.x < 0 or l.y < 0 or l.x >= CELLS or l.y >= CELLS or not Survey.is_seen(map, c):
		return
	draw_rect(Rect2(l.x * PX + 1, l.y * PX, 1, PX), col)
	draw_rect(Rect2(l.x * PX, l.y * PX + 1, PX, 1), col)
