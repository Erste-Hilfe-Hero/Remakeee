class_name WindowGlow
extends Node2D
## Lit windows at dusk and night (buildings plan items 8, 54). Sits on its own CanvasLayer that
## follows the camera, so the overworld's CanvasModulate night tint does not darken it.
## Window panes per town style match tools/art/buildings.py (pixels inside a 16 px WALL tile).

const PANES: Dictionary[String, Array] = {
	"veydal": [Rect2i(5, 4, 2, 2), Rect2i(9, 4, 2, 2), Rect2i(5, 7, 2, 2), Rect2i(9, 7, 2, 2)],
	"corvane": [Rect2i(6, 3, 4, 3)],
	"ashmere": [Rect2i(5, 5, 6, 3)],
	"solenne": [Rect2i(6, 4, 1, 3), Rect2i(9, 4, 1, 3)],
}
const GLOW: Color = Color(1.0, 0.92, 0.7)

var _cells: Array[Vector2i] = []
var _panes: Array = []

## WALL cells of [param m] that show a window (every outdoor wall tile does).
static func window_cells(m: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not m.outdoor:
		return out
	for y: int in m.height:
		for x: int in m.rows[y].length():
			if m.rows[y][x] == "H":
				out.append(Vector2i(x, y))
	return out

## Lit at dusk and night outdoors, when the day-night option is on.
static func lit(outdoor: bool, phase: int, enabled: bool) -> bool:
	return outdoor and enabled and (phase == DayCycle.Phase.DUSK or phase == DayCycle.Phase.NIGHT)

func show_for(m: MapData, on: bool) -> void:
	_cells = window_cells(m) if on else []
	_panes = PANES.get(m.region, PANES["veydal"])
	visible = not _cells.is_empty()
	queue_redraw()

func _draw() -> void:
	var t: int = TilesetFactory.TILE
	for c: Vector2i in _cells:
		for r: Rect2i in _panes:
			draw_rect(Rect2(c.x * t + r.position.x, c.y * t + r.position.y, r.size.x, r.size.y), GLOW)
