extends GutTest
## Plan area 6: door and stairs sounds (items 2507, 2508), the pause menu page (2509), Energy
## ticks at round start (2537) and the art pick pitch by element (2539).

const NEW_SOUNDS: Array[String] = ["door_open", "door_close", "stairs_up", "stairs_down", "page_open", "page_close", "energy_tick"]

func test_new_sounds_exist_and_are_logged() -> void:
	var log_text: String = FileAccess.get_file_as_string("res://docs/ASSET_LOG.md")
	for n: String in NEW_SOUNDS:
		assert_true(ResourceLoader.exists(Sound.SFX_DIR % n), n)
		assert_string_contains(log_text, "audio/sfx/%s.wav" % n)

func test_door_opens_and_shuts() -> void:
	assert_eq(Overworld.warp_sounds(TilesetFactory.Kind.DOOR, "up"), ["door_open", "door_close"] as Array[String])

func test_stairs_follow_the_facing() -> void:
	assert_eq(Overworld.warp_sounds(TilesetFactory.Kind.STAIRS, "up")[0], "stairs_up")
	assert_eq(Overworld.warp_sounds(TilesetFactory.Kind.STAIRS, "down")[0], "stairs_down")
	assert_eq(Overworld.warp_sounds(TilesetFactory.Kind.PATH, "up"), ["warp", ""] as Array[String])

func test_pause_pages_differ_and_use_the_ui_bus() -> void:
	assert_ne(FileAccess.get_file_as_bytes("res://audio/sfx/page_open.wav"), FileAccess.get_file_as_bytes("res://audio/sfx/page_close.wav"))
	assert_eq(Sound.bus_for("page_open"), GameState.BUS_UI)

func test_energy_ticks_at_most_three() -> void:
	assert_eq(Sound.energy_ticks(0), 0)
	assert_eq(Sound.energy_ticks(-2), 0, "spending makes no tick")
	assert_eq(Sound.energy_ticks(2), 2)
	assert_eq(Sound.energy_ticks(5), 3)

func test_art_pick_climbs_a_scale() -> void:
	var last: float = 0.0
	for el: int in Elements.E.size():
		var p: float = Sound.art_pick_pitch(el)
		assert_gt(p, last, "each element a step higher")
		last = p
	assert_eq(Sound.art_pick_pitch(0), 1.0)
	assert_almost_eq(Sound.art_pick_pitch(Elements.E.ECHO), 2.0, 0.001, "Echo, the last Era II element of the first set, is the octave")
	assert_eq(Sound.art_pick_pitch(-1), 1.0)

func test_grass_rustles_every_third_step() -> void:
	assert_true(ResourceLoader.exists(Sound.SFX_DIR % "rustle"))
	var due: Array[int] = []
	for n: int in range(1, 10):
		if Overworld.rustle_due(n):
			due.append(n)
	assert_eq(due, [1, 4, 7] as Array[int])
	assert_false(Overworld.rustle_due(0))
