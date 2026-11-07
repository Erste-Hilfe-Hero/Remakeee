extends GutTest
## Area 3 survey share, seen cells, marks and the minimap (items 1245, 1246, 1270-1273).

var _saved_cells: Dictionary
var _saved_marks: Array
var _saved_mode: String

func before_each() -> void:
	_saved_cells = GameState.map_cells
	_saved_marks = GameState.map_marks
	_saved_mode = GameState.minimap
	GameState.map_cells = {}
	GameState.map_marks = []

func after_each() -> void:
	GameState.map_cells = _saved_cells
	GameState.map_marks = _saved_marks
	GameState.minimap = _saved_mode

func _field() -> MapData:
	var rows: Array = []
	for y: int in 12:
		rows.append("." .repeat(20))
	return MapData.from_dict("field_t", {"rows": rows, "outdoor": true})

func test_reveal_marks_radius_three() -> void:
	# Item 1245.
	var m: MapData = _field()
	assert_eq(Survey.percent(m), 0)
	var added: int = Survey.reveal(m, Vector2i(10, 6))
	assert_gt(added, 20)
	assert_true(Survey.is_seen(m, Vector2i(13, 6)))
	assert_true(Survey.is_seen(m, Vector2i(10, 3)))
	assert_false(Survey.is_seen(m, Vector2i(14, 6)), "four cells away is not seen")
	assert_false(Survey.is_seen(m, Vector2i(13, 9)), "the far corner is not seen")
	assert_eq(Survey.reveal(m, Vector2i(10, 6)), 0, "nothing new the second time")
	assert_true(Survey.visited("field_t"))
	assert_false(Survey.visited("nowhere"))

func test_percent_counts_walkable_cells() -> void:
	# Item 1246: rock and water do not count.
	var m := MapData.from_dict("wet_t", {"rows": ["..~~", "..~~"]})
	Survey.reveal(m, Vector2i(0, 0), 1)
	assert_eq(Survey.percent(m), 100, "all four walkable cells seen")
	var b := MapData.from_dict("big_t", {"rows": [".".repeat(40)]})
	Survey.reveal(b, Vector2i(0, 0))
	assert_eq(Survey.percent(b), 10)

func test_cells_survive_saving() -> void:
	var m: MapData = _field()
	Survey.reveal(m, Vector2i(2, 2))
	var d: Dictionary = GameState.to_dict()
	var before: int = Survey.percent(m)
	GameState.map_cells = {}
	GameState.map_cells = Survey.cells_from_save(JSON.parse_string(JSON.stringify(d.map_cells)))
	assert_eq(Survey.percent(m), before)
	assert_true(Survey.cells_from_save("junk").is_empty())

func test_marks() -> void:
	# Item 1273: up to 30 marks with six symbols.
	assert_eq(Survey.MARK_ICONS.size(), 6)
	assert_true(Survey.add_mark("brindlewick", Vector2i(3, 4), "star"))
	assert_false(Survey.add_mark("brindlewick", Vector2i(3, 4), "skull"), "unknown symbol")
	for i: int in 40:
		Survey.add_mark("crowcrest", Vector2i(i, 0), "heart")
	assert_eq(GameState.map_marks.size(), Survey.MAX_MARKS)
	assert_eq(Survey.marks_on("brindlewick").size(), 1)
	Survey.remove_mark(0)
	assert_eq(Survey.marks_on("brindlewick").size(), 0)
	var back: Array = Survey.marks_from_save([{"map": "a", "x": 1, "y": 2, "icon": "arrow"}, {"icon": "bad"}, "x"])
	assert_eq(back.size(), 1)

func test_minimap_modes() -> void:
	# Items 1270-1272.
	var outside: MapData = _field()
	var inside := MapData.from_dict("room_t", {"rows": ["fff"], "outdoor": false})
	GameState.minimap = "on"
	assert_true(Survey.minimap_shows(inside))
	GameState.minimap = "outdoor"
	assert_true(Survey.minimap_shows(outside))
	assert_false(Survey.minimap_shows(inside))
	GameState.minimap = "off"
	assert_false(Survey.minimap_shows(outside))
	GameState.minimap = "on"
	var mm := Minimap.new()
	add_child_autofree(mm)
	Survey.reveal(outside, Vector2i(10, 6))
	mm.refresh(outside, Vector2i(10, 6))
	assert_eq(Minimap.SIDE, 36)
	assert_eq(mm.origin(), Vector2i(4, 0))
	assert_eq(mm.cell_color(Vector2i(10, 6)), UITheme.BG)
	assert_ne(mm.cell_color(Vector2i(0, 0)), UITheme.BG, "unseen cells stay dark")
	assert_eq(mm.cell_color(Vector2i(-1, 0)), UITheme.INK, "off the map")
