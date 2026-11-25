extends GutTest
## Chimora 200 list items 27 (door glow), 30 (smooth diagonal walking), 38 (soft day-night).

const NIGHT: float = 23.0
const NOON: float = 12.5
const TILE: float = 16.0

var _settings: Dictionary
var _keep: Array[int] = []

func before_each() -> void:
	_settings = GameState.settings_to_dict()
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	GameState.day_night = true

func after_each() -> void:
	for a: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		Input.action_release(a)
	GameState.settings_from_dict(_settings)
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	EraLight.debug_era = 0
	EraLight.debug_hour = -1.0
	EraLight.debug_weather = ""
	MusicDirector.update_world(true, false, 0.0)

func _open(_d: String) -> bool:
	return true

# Item 30: picking the direction for held buttons.

func test_single_direction_is_kept() -> void:
	assert_eq(Player.pick_direction(["left"] as Array[String], "down", _open), "left")
	assert_eq(Player.pick_direction([] as Array[String], "down", _open), "")

func test_diagonal_alternates_axes() -> void:
	var held: Array[String] = ["up", "right"]
	assert_eq(Player.pick_direction(held, "down", _open), "up", "from standing, vertical first")
	assert_eq(Player.pick_direction(held, "up", _open), "right")
	assert_eq(Player.pick_direction(held, "right", _open), "up")

func test_diagonal_slides_along_a_wall() -> void:
	var held: Array[String] = ["up", "right"]
	var no_up: Callable = func(d: String) -> bool: return d != "up"
	assert_eq(Player.pick_direction(held, "right", no_up), "right", "blocked up gives way to right")
	var none: Callable = func(_d: String) -> bool: return false
	assert_eq(Player.pick_direction(held, "right", none), "up", "both blocked: turns toward the first")

func test_walking_round_a_corner_has_no_turn_pause() -> void:
	var p := Player.new()
	autofree(p)
	p.place(Vector2i(5, 5), "right")
	p._walking = true
	Input.action_press("ui_up")
	p._process(0.0)
	assert_true(p.moving, "steps on at once")
	assert_eq(p.facing, "up")
	assert_eq(p.cell, Vector2i(5, 4))

func test_standing_turn_still_waits() -> void:
	var p := Player.new()
	autofree(p)
	p.place(Vector2i(5, 5), "right")
	Input.action_press("ui_up")
	p._process(0.0)
	assert_false(p.moving, "a tap from standing only turns")
	assert_eq(p.facing, "up")
	assert_almost_eq(p._turn_timer, Player.TURN_GRACE, 0.001)

func test_corner_into_a_wall_turns_and_waits() -> void:
	var p := Player.new()
	autofree(p)
	p.place(Vector2i(5, 5), "right")
	p.can_probe = func(c: Vector2i) -> bool: return c != Vector2i(5, 4)
	p._walking = true
	Input.action_press("ui_up")
	p._process(0.0)
	assert_false(p.moving)
	assert_eq(p.facing, "up")

# Item 27: door glow.

func test_glow_strength_by_distance() -> void:
	assert_eq(DoorGlow.strength(0.0), 1.0)
	assert_eq(DoorGlow.strength(TILE), 1.0, "right next to the door")
	assert_eq(DoorGlow.strength(TILE * DoorGlow.NEAR_TILES), 0.0, "far enough: no glow")
	var mid: float = DoorGlow.strength(TILE * 2.0)
	assert_gt(mid, 0.0)
	assert_lt(mid, 1.0)

func test_glow_cells_are_doors_not_edge_paths() -> void:
	var m: MapData = MapData.load_map("brindlewick")
	var cells: Array[Vector2i] = DoorGlow.glow_cells(m)
	assert_false(cells.is_empty())
	for c: Vector2i in cells:
		assert_true(m.kind_at(c) in [TilesetFactory.Kind.DOOR, TilesetFactory.Kind.STAIRS], str(c))
	for w: Dictionary in m.warps:
		var c := Vector2i(int(w.x), int(w.y))
		if m.kind_at(c) == TilesetFactory.Kind.PATH:
			assert_false(c in cells, "edge path %s stays unmarked" % c)
