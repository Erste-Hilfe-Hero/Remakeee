extends GutTest
## Plan item 1300: survey share, finds and cartographer's stones are counted per region.

var _saved_cells: Dictionary

func before_each() -> void:
	_saved_cells = GameState.map_cells
	GameState.map_cells = {}

func after_each() -> void:
	GameState.map_cells = _saved_cells

func test_stones_are_counted_per_region() -> void:
	var t: Dictionary = RegionStats.totals({MarkerStones.flag(3): true, MarkerStones.flag(3, "corvane"): true, MarkerStones.flag(7, "corvane"): true})
	assert_eq(t.veydal.stones, Vector2i(1, MarkerStones.TOTAL))
	assert_eq(t.corvane.stones, Vector2i(2, MarkerStones.TOTAL))

func test_survey_share_is_per_region() -> void:
	var t: Dictionary = RegionStats.totals({})
	assert_gt((t.corvane.mapped as Vector2i).y, 0, "Corvane has walkable cells")
	assert_eq(RegionStats.mapped_percent(t.corvane), 0, "nothing seen on a fresh save")
	var m: MapData = MapData.load_map("corvane_quay")
	Survey.reveal(m, Vector2i(m.width / 2, m.height / 2))
	var after: Dictionary = RegionStats.totals({})
	assert_gt((after.corvane.mapped as Vector2i).x, 0, "walking the quay maps Corvane")
	assert_eq((after.veydal.mapped as Vector2i).x, 0, "Veydal is untouched")

func test_survey_cells_match_percent() -> void:
	var m: MapData = MapData.load_map("corvane_quay")
	Survey.reveal(m, Vector2i(m.width / 2, m.height / 2))
	var c: Vector2i = Survey.cells(m)
	assert_eq(Survey.percent(m), c.x * 100 / c.y)

func test_lines_show_each_regions_counters() -> void:
	var l: Array[String] = RegionStats.lines({MarkerStones.flag(2, "corvane"): true})
	var i: int = l.find("Corvane")
	assert_gt(i, -1)
	var block: Array[String] = l.slice(i, i + 5)
	assert_true(block.has("  Mapped: 0%"), str(block))
	assert_true(block.has("  Cartographer's stones: 1/12"), str(block))
