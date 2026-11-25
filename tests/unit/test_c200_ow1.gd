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
