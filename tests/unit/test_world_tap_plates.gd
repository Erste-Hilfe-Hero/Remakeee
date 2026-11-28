extends GutTest
## Plan item 901: tap walks keep off pressure plates unless the plate is the goal.

func _open(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < 5 and c.y >= 0 and c.y < 3

func _plate(c: Vector2i) -> bool:
	return c == Vector2i(1, 0) or c == Vector2i(2, 0) or c == Vector2i(3, 0)

func test_way_goes_around_plates() -> void:
	var p: Array[Vector2i] = PathFinder.find_avoiding(Vector2i(0, 0), Vector2i(4, 0), _open, _plate)
	assert_eq(p.back(), Vector2i(4, 0))
	for c: Vector2i in p:
		assert_false(_plate(c), "stepped on plate %s" % c)
	assert_eq(p.size(), 6, "one row down and back up")

func test_plate_as_goal_is_walked_onto() -> void:
	var p: Array[Vector2i] = PathFinder.find_avoiding(Vector2i(0, 0), Vector2i(2, 0), _open, _plate)
	assert_eq(p.back(), Vector2i(2, 0))

func test_falls_back_when_only_plates_lead_there() -> void:
	var corridor: Callable = func(c: Vector2i) -> bool: return c.y == 0 and c.x >= 0 and c.x < 5
	var p: Array[Vector2i] = PathFinder.find_avoiding(Vector2i(0, 0), Vector2i(4, 0), corridor, _plate)
	assert_eq(p.size(), 4, "plain way across the plates")

func test_adjacent_search_keeps_off_plates() -> void:
	var p: Array[Vector2i] = PathFinder.find_avoiding(Vector2i(0, 0), Vector2i(4, 1), _open, _plate, true)
	assert_true(PathFinder.is_adjacent(p.back(), Vector2i(4, 1)))
	for c: Vector2i in p:
		assert_false(_plate(c))
