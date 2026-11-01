extends GutTest
## Every sound the code asks for exists, and every map has a music track.

func _scripts(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(d), out)

func test_every_named_sound_exists() -> void:
	var files: Array[String] = []
	_scripts("res://scripts", files)
	var re := RegEx.create_from_string("Sound\\.(sfx|music|jingle)\\(\"([a-z_]+)\"")
	var checked: int = 0
	for path: String in files:
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			var kind: String = m.get_string(1)
			var file: String = (Sound.SFX_DIR if kind == "sfx" else Sound.MUSIC_DIR) % m.get_string(2)
			assert_true(ResourceLoader.exists(file), "%s asks for missing %s" % [path.get_file(), file])
			checked += 1
	assert_gt(checked, 10)

func test_every_map_has_music() -> void:
	for f: String in DirAccess.get_files_at("res://data/maps"):
		var map_id: String = f.get_basename()
		var track: String = Sound.track_for_map(map_id)
		assert_true(ResourceLoader.exists(Sound.MUSIC_DIR % track), "%s -> %s missing" % [map_id, track])

func test_volume_settings_round_trip() -> void:
	GameState.settings_from_dict({"music_volume": 0.4, "sfx_volume": 1.0})
	var d: Dictionary = GameState.settings_to_dict()
	assert_almost_eq(float(d.music_volume), 0.4, 0.001)
	assert_almost_eq(float(d.sfx_volume), 1.0, 0.001)
	assert_true(AudioServer.get_bus_index(GameState.BUS_MUSIC) >= 0)
	assert_true(AudioServer.get_bus_index(GameState.BUS_SFX) >= 0)
	GameState.settings_from_dict({})
	assert_almost_eq(GameState.music_volume, 0.7, 0.001)
