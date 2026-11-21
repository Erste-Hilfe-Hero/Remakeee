class_name BondRings
extends Control
## The bond's own animation (KAMPF_PLAN_1000 "Bond-Erfolg-Animation eigenständig"): three echo
## rings swell out of a Spirling that answered the call and fade, in every era. Drawn only.

const RINGS: int = 3
const TIME: float = 0.7
const COLOR: Color = Color(1.0, 0.88, 0.55)

## 0 at the start, 1 when the rings have faded.
var progress: float = 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Radius and alpha of ring [param i] at [param p] (0..1); each ring starts a little later.
static func ring_at(i: int, p: float, reach: float) -> Vector2:
	var local: float = clampf(p * 1.6 - i * 0.3, 0.0, 1.0)
	return Vector2(reach * (0.25 + 0.75 * local), (1.0 - local) if local > 0.0 else 0.0)

func _draw() -> void:
	var reach: float = maxf(size.x, size.y) * 0.75
	for i: int in RINGS:
		var r: Vector2 = ring_at(i, progress, reach)
		if r.y > 0.0:
			draw_arc(size / 2.0, r.x, 0.0, TAU, 32, Color(COLOR, r.y), 2.0)
