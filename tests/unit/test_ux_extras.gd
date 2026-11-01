extends GutTest
## UX: team reorder, storage sort/filter, save slots, battery saver, high contrast.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_all() -> void:
	GameState.battery_saver = false
	GameState.high_contrast = false
	GameState.apply_display()

func test_move_party_shifts_others() -> void:
	for sp: String in ["Zippit", "Puddlet", "Mossling"]:
		GameState.receive_spirling(Spirling.new(Database.species(sp), 5))
	GameState.move_party(3, 0)
	var names: Array[String] = []
	for s: Spirling in GameState.party:
		names.append(s.data.species_name)
	assert_eq(names, ["Mossling", "Kindlop", "Zippit", "Puddlet"] as Array[String])

func test_storage_view_sorts_and_filters() -> void:
	GameState.storage.clear()
	GameState.storage.append(Spirling.new(Database.species("Zippit"), 9))
	GameState.storage.append(Spirling.new(Database.species("Breezel"), 20))
	GameState.storage.append(Spirling.new(Database.species("Glimmerax"), 30))
	assert_eq(GameState.storage_view(0), [0, 1, 2] as Array[int])
	assert_eq(GameState.storage_view(1), [2, 1, 0] as Array[int], "by level, high first")
	assert_eq(GameState.storage_view(2), [1, 2, 0] as Array[int], "by name")
	assert_eq(GameState.storage_view(0, Elements.E.VOLT), [0, 2] as Array[int])
	assert_eq(GameState.storage_view(0, -1, "glim"), [2] as Array[int])

func test_slot_paths() -> void:
	assert_eq(SaveManager.path_for_slot(1), SaveManager.SLOT_PATH, "slot 1 keeps the old file")
	assert_eq(SaveManager.path_for_slot(3), "user://save_3.json")
	assert_eq(SaveManager.path_for_slot(9), "user://save_3.json", "clamped")

func test_battery_saver_caps_fps() -> void:
	GameState.battery_saver = true
	GameState.apply_display()
	assert_eq(Engine.max_fps, GameState.FPS_BATTERY)
	GameState.battery_saver = false
	GameState.apply_display()
	assert_eq(Engine.max_fps, GameState.FPS_NORMAL)

func test_high_contrast_swaps_palette_and_back() -> void:
	var normal_bg: Color = UITheme.BG
	GameState.high_contrast = true
	GameState.apply_display()
	assert_eq(UITheme.BG, Color.WHITE)
	assert_eq(UITheme.INK, Color.BLACK)
	assert_not_null(UITheme.get_theme())
	GameState.high_contrast = false
	GameState.apply_display()
	assert_eq(UITheme.BG, normal_bg)

func test_display_settings_round_trip() -> void:
	GameState.reduce_motion = true
	var d: Dictionary = GameState.settings_to_dict()
	GameState.reduce_motion = false
	GameState.settings_from_dict(d)
	assert_true(GameState.reduce_motion)
	GameState.reduce_motion = false
