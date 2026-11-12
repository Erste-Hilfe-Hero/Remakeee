extends GutTest
## Era audio: every map has a valid music entry, the new dungeons and regions have their own
## themes, battle music follows the era (battle_era2 to battle_era5) and the Music bus effects
## grow with the era like the art does.

const MAPS_DIR: String = "res://data/maps"

func _table() -> Dictionary:
	return Sound._map_music

func _track_of(entry: Variant) -> String:
	return str((entry as Dictionary).get("track", "")) if entry is Dictionary else str(entry)

func test_every_map_has_a_valid_music_entry() -> void:
	var listed: Dictionary = {}
	listed.merge(_table().get("maps", {}))
	listed.merge(_table().get("themes", {}))
	var checked: int = 0
	for f: String in DirAccess.get_files_at(MAPS_DIR):
		if not f.ends_with(".json"):
			continue
		var map_id: String = f.get_basename()
		var region: String = str((JSON.parse_string(FileAccess.get_file_as_string(MAPS_DIR.path_join(f))) as Dictionary).get("region", ""))
		assert_true(listed.has(map_id) or (_table().get("regions", {}) as Dictionary).has(region),
			"%s (region %s) has no entry in data/music.json maps, themes or regions" % [map_id, region])
		var track: String = _track_of(Sound.entry_in(_table(), map_id, region))
		assert_ne(track, "", map_id)
		assert_true(ResourceLoader.exists(Sound.MUSIC_DIR % track), "%s -> %s.ogg missing" % [map_id, track])
		checked += 1
	assert_gt(checked, 50)

func test_every_listed_track_and_ambience_exists() -> void:
	for list: String in ["maps", "themes", "regions"]:
		var d: Dictionary = _table().get(list, {})
		for key: String in d.keys():
			var entry: Variant = d[key]
			assert_true(ResourceLoader.exists(Sound.MUSIC_DIR % _track_of(entry)), "%s %s -> %s" % [list, key, _track_of(entry)])
			if entry is Dictionary and (entry as Dictionary).has("ambience"):
				assert_true(ResourceLoader.exists(Sound.AMBIENCE_DIR % str(entry.ambience)), "%s ambience %s" % [key, entry.ambience])

func test_new_dungeons_have_their_own_theme() -> void:
	for map_id: String in ["pawn_vault", "rook_vault", "veil_cistern", "soot_vaults"]:
		assert_eq(_track_of(Sound.entry_in(_table(), map_id, "")), map_id)

func test_regions_have_their_own_theme() -> void:
	var seen: Dictionary = {}
	for region: String in ["corvane", "ashmere", "solenne", "vellmarch", "quillmarch", "halcyra"]:
		var track: String = _track_of(Sound.entry_in(_table(), "unknown_" + region, region))
		assert_ne(track, _table().get("default", ""), region)
		assert_false(seen.has(track), "%s shares %s" % [region, track])
		seen[track] = region

func test_region_fallback_before_default() -> void:
	var t: Dictionary = {"default": "route", "maps": {"a": "town"}, "themes": {"b": {"track": "cave"}}, "regions": {"r": "rift"}}
	assert_eq(_track_of(Sound.entry_in(t, "a", "r")), "town")
	assert_eq(_track_of(Sound.entry_in(t, "b", "r")), "cave")
	assert_eq(_track_of(Sound.entry_in(t, "a@2", "")), "town", "instanced map ids use the base map")
	assert_eq(_track_of(Sound.entry_in(t, "c", "r")), "rift")
	assert_eq(_track_of(Sound.entry_in(t, "c", "x")), "route")

func test_battle_theme_per_era() -> void:
	var exists: Callable = func(t: String) -> bool: return ResourceLoader.exists(Sound.MUSIC_DIR % t)
	assert_eq(Sound.era_track("battle", 1, exists), "battle")
	for era: int in range(2, EraManager.NEWEST + 1):
		assert_eq(Sound.era_track("battle", era, exists), "battle_era%d" % era)
	assert_eq(Sound.era_track("warden", 3, exists), "warden", "no era variant: the plain track")

func test_era_tracks_stay_small() -> void:
	for t: String in ["battle_era2", "battle_era3", "battle_era4", "battle_era5", "pawn_vault", "rook_vault", "veil_cistern"]:
		var size: int = FileAccess.get_file_as_bytes(Sound.MUSIC_DIR % t).size()
		assert_between(size, 1, 100 * 1024, t)

func test_era_fx_grow_with_the_era() -> void:
	var fx: Dictionary = _table().get("era_fx", {})
	assert_eq(Sound.era_effects(fx.get("1", {})).size(), 0, "Era I stays dry")
	var prev: int = 0
	for era: int in range(1, EraManager.NEWEST + 1):
		var n: int = Sound.era_effects(fx.get(str(era), {})).size()
		assert_true(n >= prev, "era %d has fewer effects than the one before" % era)
		prev = n
	assert_gt(prev, 0)

func test_apply_era_fx_replaces_its_own_effects() -> void:
	GameState.ensure_buses()
	var bus: int = AudioServer.get_bus_index(GameState.BUS_MUSIC)
	var base: int = AudioServer.get_bus_effect_count(bus) - Sound.apply_era_fx(1)
	var n: int = Sound.apply_era_fx(5)
	assert_gt(n, 0)
	assert_eq(AudioServer.get_bus_effect_count(bus), base + n)
	Sound.apply_era_fx(5)
	assert_eq(AudioServer.get_bus_effect_count(bus), base + n, "no doubled effects")
	Sound.apply_era_fx(EraManager.active_era())
