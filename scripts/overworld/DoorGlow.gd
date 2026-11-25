class_name DoorGlow
extends Node2D
## Doors, stairs and cave mouths glow softly when the Wayfarer comes near (200 list item 27):
## a thin accent frame around the warp cell, stronger the closer the Wayfarer is. Map-edge
## paths stay unmarked. UITheme colours, so it takes each era's accent.

## Distance in tiles at which the glow starts to show.
const NEAR_TILES: float = 3.0
## Frame opacity with the Wayfarer right next to the door.
const MAX_ALPHA: float = 0.55

var ow: Node
var _map: MapData
var _cells: Array[Vector2i] = []
## Glow per cell (0 to 1), in steps of 0.1 so it redraws only when it shows.
var _glow: Dictionary[Vector2i, float] = {}

## Warp cells of [param m] that are doors or stairs (cave entrances use the door tile).
static func glow_cells(m: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if m == null:
		return out
	for w: Dictionary in m.warps:
		var c := Vector2i(int(w.x), int(w.y))
		if m.in_bounds(c) and m.kind_at(c) in [TilesetFactory.Kind.DOOR, TilesetFactory.Kind.STAIRS]:
			out.append(c)
	return out

## Glow strength (0 to 1) for a Wayfarer [param dist_px] pixels from the door cell.
static func strength(dist_px: float) -> float:
	var k: float = clampf(1.0 - (dist_px - GridWalker.TILE) / ((NEAR_TILES - 1.0) * GridWalker.TILE), 0.0, 1.0)
	return snappedf(k, 0.1)

func _process(_delta: float) -> void:
	if ow == null or ow.player == null:
		return
	if ow.map != _map:
		_map = ow.map
		_cells = glow_cells(_map)
		_glow.clear()
		queue_redraw()
	var p: Vector2 = (ow.player as Node2D).position
	var changed: bool = false
	for c: Vector2i in _cells:
		var s: float = strength(p.distance_to(GridWalker.cell_to_pos(c)))
		if not is_equal_approx(float(_glow.get(c, 0.0)), s):
			_glow[c] = s
			changed = true
	if changed:
		queue_redraw()

func _draw() -> void:
	for c: Vector2i in _glow:
		var s: float = _glow[c]
		if s <= 0.0:
			continue
		var o: Vector2 = GridWalker.cell_to_pos(c)
		draw_rect(Rect2(o, Vector2(GridWalker.TILE, GridWalker.TILE)), Color(UITheme.ACCENT, s * MAX_ALPHA * 0.3))
		draw_rect(Rect2(o + Vector2(0.5, 0.5), Vector2(GridWalker.TILE - 1, GridWalker.TILE - 1)), Color(UITheme.ACCENT, s * MAX_ALPHA), false, 1.0)
