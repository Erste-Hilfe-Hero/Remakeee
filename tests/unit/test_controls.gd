extends GutTest
## Tap-to-move path finding, touch-control settings, Continue summary.

## 6x5 room with a wall column at x=2 (gap at y=4).
func _room() -> Callable:
	return func(c: Vector2i) -> bool:
		if c.x < 0 or c.y < 0 or c.x >= 6 or c.y >= 5:
			return false
		return not (c.x == 2 and c.y < 4)

func test_find_goes_around_walls() -> void:
	var p: Array[Vector2i] = PathFinder.find(Vector2i(0, 0), Vector2i(4, 0), _room())
	assert_eq(p.back(), Vector2i(4, 0))
	assert_true(Vector2i(2, 4) in p, "must pass the gap")
	var prev := Vector2i(0, 0)
	for c: Vector2i in p:
		assert_true(PathFinder.is_adjacent(prev, c))
		prev = c
	assert_eq(p.size(), 12)

func test_find_unreachable_or_blocked_goal() -> void:
	assert_eq(PathFinder.find(Vector2i(0, 0), Vector2i(2, 1), _room()).size(), 0)
	var walled: Callable = func(c: Vector2i) -> bool: return c.x < 2 and c.x >= 0 and c.y >= 0 and c.y < 5
	assert_eq(PathFinder.find(Vector2i(0, 0), Vector2i(4, 0), walled).size(), 0)
	assert_eq(PathFinder.find(Vector2i(1, 1), Vector2i(1, 1), _room()).size(), 0)

func test_find_adjacent_stops_next_to_target() -> void:
	var p: Array[Vector2i] = PathFinder.find_adjacent(Vector2i(0, 0), Vector2i(2, 1), _room())
	assert_true(PathFinder.is_adjacent(p.back(), Vector2i(2, 1)))
	assert_eq(p.size(), 2, "(1,1) is two steps from (0,0)")

func test_player_follows_path_then_interacts() -> void:
	var pl := Player.new()
	add_child_autofree(pl)
	pl.place(Vector2i(0, 0))
	var talked: Array[Vector2i] = []
	pl.interact.connect(func(c: Vector2i) -> void: talked.append(c))
	pl.follow([Vector2i(1, 0)] as Array[Vector2i], Vector2i(2, 0))
	for i: int in 40:
		pl._process(0.05)
	assert_eq(pl.cell, Vector2i(1, 0))
	assert_eq(pl.facing, "right")
	assert_eq(talked, [Vector2i(2, 0)] as Array[Vector2i])
	assert_true(pl.path.is_empty())

func test_frozen_player_drops_path() -> void:
	var pl := Player.new()
	add_child_autofree(pl)
	pl.place(Vector2i(0, 0))
	pl.follow([Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	pl.frozen = true
	pl._process(0.05)
	assert_true(pl.path.is_empty())

func test_control_settings_round_trip_and_defaults() -> void:
	GameState.settings_from_dict({"pad_size": 2, "pad_opacity": 0, "left_handed": true, "tap_to_move": false})
	var d: Dictionary = GameState.settings_to_dict()
	assert_eq(d.pad_size, 2)
	assert_eq(d.pad_opacity, 0)
	assert_true(d.left_handed)
	assert_false(d.tap_to_move)
	GameState.settings_from_dict({"pad_size": 99})
	assert_eq(GameState.pad_size, GameState.PAD_SIZE_NAMES.size() - 1)
	assert_true(GameState.tap_to_move)
	assert_false(GameState.left_handed)
	VirtualPad.apply_settings()

func test_save_summary_line() -> void:
	var line: String = SaveManager.summary_line({"map": "brindlewick", "play_time": 3725.0})
	assert_string_contains(line, "1:02")
	assert_false(line.begins_with("brindlewick"), "uses the map's display name")
