extends GutTest
## Plan area 6: own volume for voices and ambience (item 2556), and a mono mix for one-sided
## hearing (item 2555).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()

func after_each() -> void:
	GameState.settings_from_dict(_saved)

func _db(bus: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))

func test_voice_and_ambience_have_own_levels() -> void:
	GameState.voice_volume = 0.5
	GameState.ambience_volume = 0.2
	GameState.apply_volume()
	assert_almost_eq(_db(GameState.BUS_VOICE), linear_to_db(0.5), 0.01)
	assert_almost_eq(_db(GameState.BUS_AMBIENCE), linear_to_db(0.2), 0.01)

func test_levels_are_saved() -> void:
	GameState.voice_volume = 0.3
	GameState.ambience_volume = 0.6
	GameState.mono_audio = true
	var d: Dictionary = GameState.settings_to_dict()
	GameState.voice_volume = 1.0
	GameState.ambience_volume = 1.0
	GameState.mono_audio = false
	GameState.settings_from_dict(d)
	assert_almost_eq(GameState.voice_volume, 0.3, 0.001)
	assert_almost_eq(GameState.ambience_volume, 0.6, 0.001)
	assert_true(GameState.mono_audio)

func test_old_saves_keep_full_levels() -> void:
	var d: Dictionary = GameState.settings_to_dict()
	d.erase("voice_volume")
	d.erase("ambience_volume")
	d.erase("mono_audio")
	GameState.settings_from_dict(d)
	assert_almost_eq(GameState.voice_volume, 0.9, 0.001, "one step under full, so a tap turns it up")
	assert_almost_eq(GameState.ambience_volume, 0.9, 0.001)
	assert_false(GameState.mono_audio)

func test_mono_folds_to_the_middle() -> void:
	GameState.ensure_buses()
	var i: int = GameState.mono_effect_index()
	assert_gte(i, 0, "Master has the mono mix")
	GameState.mono_audio = true
	GameState.apply_volume()
	assert_true(AudioServer.is_bus_effect_enabled(0, i))
	GameState.mono_audio = false
	GameState.apply_volume()
	assert_false(AudioServer.is_bus_effect_enabled(0, i))
	GameState.ensure_buses()
	assert_eq(GameState.mono_effect_index(), i, "added only once")

func test_settings_show_the_new_rows() -> void:
	var keys: Array[String] = []
	for r: Array in MenuHost.settings_rows("sound"):
		keys.append(str(r[0]))
	for k: String in ["voice_volume", "ambience", "mono"]:
		assert_has(keys, k)
	assert_has(MenuHost.SLIDER_KEYS, "voice_volume")
	assert_has(MenuHost.SLIDER_KEYS, "ambience")
