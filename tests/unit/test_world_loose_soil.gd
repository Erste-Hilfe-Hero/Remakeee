extends GutTest
## Area 3 item 1089: buried finds under loose soil. The patch shows on the ground and is dug
## up with A, without a Spirling.

const SOIL: Dictionary = {"saltmarsh": Vector2i(10, 9), "woadfen": Vector2i(3, 21),
	"saltglass": Vector2i(9, 13), "lantern_steps": Vector2i(10, 11)}

func before_all() -> void:
	Database.load_all()

func test_soil_finds_on_open_ground() -> void:
	for mid: String in SOIL:
		var m: MapData = MapData.load_map(mid)
		var sc: Dictionary = m.secret_at(SOIL[mid], {})
		assert_true(bool(sc.get("soil", false)), mid + " has loose soil")
		assert_true(m.is_walkable(SOIL[mid]), mid)
		assert_false(Database.item(str(sc.item)).is_empty(), str(sc.item))

func test_soil_shows_until_dug() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	ow.load_map("saltmarsh", Vector2i(10, 9), "down")
	await wait_process_frames(1)
	var before_glints: int = ow._world.glint_count()
	assert_eq(ow._world.soil_count(), 1, "the patch is drawn")
	GameState.set_flag("dig_saltmarsh")
	ow._world._build_glints(ow.map)
	assert_eq(ow._world.soil_count(), 0, "dug up, the patch is gone")
	assert_eq(ow._world.glint_count(), before_glints, "loose soil never glints")
