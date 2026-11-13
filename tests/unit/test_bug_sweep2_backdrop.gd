extends GutTest
## Bug sweep 2: the era battle shots logged "Invalid polygon data, triangulation failed" from
## BattleBackdrop._hills ten times; the hill outline crossed the horizon and lost its fill.

const WIDTHS: Array[float] = [144.0, 160.0, 240.0, 256.0, 270.0, 320.0, 400.0, 480.0]
const HEIGHTS: Array[float] = [90.0, 144.0, 160.0, 256.0, 480.0]
## Every amp/freq pair BattleBackdrop draws hills with.
const HILLS: Array = [[4.0, 0.09], [6.0, 0.08], [3.0, 0.05], [5.0, 0.11], [9.0, 0.07]]

func test_every_hill_outline_can_be_filled() -> void:
	var bad: Array = []
	for w: float in WIDTHS:
		for h: float in HEIGHTS:
			var hy: float = floorf(h * BattleBackdrop.HORIZON)
			for k: Array in HILLS:
				var pts: PackedVector2Array = BattleBackdrop.hill_points(w, hy, k[0], k[1])
				if Geometry2D.triangulate_polygon(pts).is_empty():
					bad.append([w, h, k])
	assert_eq(bad, [], "hill outlines that cannot be triangulated")

func test_hill_stays_on_screen_and_above_the_horizon() -> void:
	var pts: PackedVector2Array = BattleBackdrop.hill_points(270.0, 100.0, 9.0, 0.07)
	for i: int in range(1, pts.size() - 1):
		assert_between(pts[i].x, 0.0, 270.0, "point %d inside the width" % i)
		assert_lt(pts[i].y, 100.0, "point %d above the horizon" % i)
