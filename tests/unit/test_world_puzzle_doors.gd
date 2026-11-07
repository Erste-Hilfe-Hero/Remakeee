extends GutTest
## Area 3 item 1028: a door opened by a solved puzzle stays open, also after saving and loading.

const DUNGEONS: Array[String] = ["bellstone_ruins", "lanternwell"]

var _snapshot: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_snapshot = GameState.to_dict()

func after_each() -> void:
	GameState.from_dict(_snapshot)

func test_solved_rooms_stay_open_after_a_save_round_trip() -> void:
	for file: String in DUNGEONS:
		for f: String in WorldAtlas.room_flags(file):
			GameState.set_flag(f)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.flags.clear()
	GameState.from_dict(saved)
	for file: String in DUNGEONS:
		var top: MapData = MapData.load_map(file)
		var doors: int = 0
		for i: int in top.floor_count:
			var m: MapData = MapData.load_map(MapData.floor_id(file, i))
			m.apply_blocks(GameState.flags)
			for b: Dictionary in m.blocks:
				doors += 1
				assert_true(m.is_walkable(Vector2i(int(b.x), int(b.y))), "%s door %s,%s stays open" % [m.id, b.x, b.y])
		assert_gt(doors, 0, file)

func test_unsolved_rooms_are_closed() -> void:
	for file: String in DUNGEONS:
		for f: String in WorldAtlas.room_flags(file):
			GameState.flags.erase(f)
	var m: MapData = MapData.load_map("lanternwell")
	m.apply_blocks(GameState.flags)
	var b: Dictionary = m.blocks[0]
	assert_false(m.is_walkable(Vector2i(int(b.x), int(b.y))))
