extends GutTest
## Era sound sets (docs/ERA_FEEL_AUDIO.md, data/era_audio.json): every era defines every sound
## and its file exists, later eras never lose a sound, cries keep their origin era, the
## low-health alarm, Era V battle layers, biome ambience and footsteps.

var _saved_retro: int
var _saved_unlocked: int

func before_each() -> void:
	_saved_retro = EraManager.retro_filter
	_saved_unlocked = EraManager.unlocked_era

func after_each() -> void:
	EraManager.retro_filter = _saved_retro
	EraManager.unlocked_era = _saved_unlocked
	Sound.low_hp_alarm(false)

func _keys() -> Array:
	var keys: Array = Sound.era_audio().get("sfx_keys", [])
	assert_gt(keys.size(), 10, "sfx_keys listed")
	return keys

func _sfx(era: int) -> Dictionary:
	return Sound.era_spec(era).get("sfx", {})

func _exists(f: String) -> bool:
	return ResourceLoader.exists(Sound.SFX_DIR % f)

func test_every_era_defines_every_key_and_the_file_exists() -> void:
	for era: int in range(1, EraManager.NEWEST + 1):
		var table: Dictionary = _sfx(era)
		for key: String in _keys():
			assert_true(table.has(key), "era %d has no %s" % [era, key])
			assert_true(_exists(str(table.get(key, ""))), "era %d %s: audio/sfx/%s.wav" % [era, key, table.get(key, "")])

func test_the_required_sounds_are_listed() -> void:
	for key: String in ["select", "confirm", "cancel", "blip", "bump", "door_open", "heal", "level_up", "bond", "faint", "low_hp", "evolve"]:
		assert_has(_keys(), key)

func test_later_eras_never_lose_a_sound() -> void:
	for era: int in range(2, EraManager.NEWEST + 1):
		var before: Dictionary = _sfx(era - 1)
		var now: Dictionary = _sfx(era)
		for key: String in before:
			assert_true(now.has(key), "era %d drops %s" % [era, key])
			assert_true(_exists(str(now.get(key, ""))), "era %d %s file" % [era, key])

func test_each_era_sounds_different() -> void:
	for key: String in _keys():
		var seen: Dictionary = {}
		for era: int in range(1, EraManager.NEWEST + 1):
			var f: String = str(_sfx(era).get(key, ""))
			assert_false(seen.has(f), "%s: era %d reuses %s" % [key, era, f])
			seen[f] = true

func test_era_one_keeps_the_older_files() -> void:
	for key: String in ["select", "confirm", "cancel", "bump", "heal", "level_up", "faint", "door_open"]:
		assert_eq(str(_sfx(1).get(key, "")), key)

func test_sfx_resolves_to_the_active_era() -> void:
	var yes: Callable = func(_f: String) -> bool: return true
	assert_eq(Sound.era_sfx_name("confirm", 1, yes), "confirm")
	assert_eq(Sound.era_sfx_name("confirm", 4, yes), "confirm_era4")
	var no: Callable = func(_f: String) -> bool: return false
	assert_eq(Sound.era_sfx_name("confirm", 4, no), "confirm", "missing file falls back to the plain name")
	var only_two: Callable = func(f: String) -> bool: return f == "heal_era2"
	assert_eq(Sound.era_sfx_name("heal", 5, only_two), "heal_era2", "newest era with a file")
	assert_eq(Sound.era_sfx_name("not_a_sound", 5, yes), "not_a_sound")
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = 3
	Sound.sfx("cancel")
	assert_eq(Sound.last_sfx, "cancel", "logical name kept")
	assert_eq(Sound.last_sfx_file, "cancel_era3")
	EraManager.retro_filter = 1
	Sound.sfx("cancel")
	assert_eq(Sound.last_sfx_file, "cancel")

func test_era_five_footsteps_per_ground() -> void:
	var yes: Callable = func(f: String) -> bool: return ResourceLoader.exists(Sound.SFX_DIR % f)
	for g: String in ["grass", "path", "wood", "sand", "stone", "shore"]:
		for take: int in [1, 2]:
			var key: String = "step_%s_%d" % [g, take]
			assert_eq(Sound.era_sfx_name(key, 5, yes), key + "_era5")
			assert_eq(Sound.era_sfx_name(key, 4, yes), key, "Era IV keeps the plain steps")
			assert_lt((load(Sound.SFX_DIR % (key + "_era5")) as AudioStream).get_length(), 0.2, key)

func test_cry_uses_the_origin_era() -> void:
	assert_eq(Sound.cry_era_for(1, true, 5), 1, "an Era I Spirling keeps its chip cry")
	assert_eq(Sound.cry_era_for(4, true, 2), 4)
	assert_eq(Sound.cry_era_for(1, false, 5), 5, "wild and rival Spirlings sound like the era on screen")
	assert_eq(Sound.cry_era_for(9, true, 1), EraManager.NEWEST)

func test_cry_spec_grows_with_the_era() -> void:
	assert_true(Sound.cry_spec(1).is_empty(), "Era I is the plain chip cry")
	for era: int in range(2, EraManager.NEWEST + 1):
		assert_false(Sound.cry_spec(era).is_empty(), "era %d processes the cry" % era)
	assert_eq(str(Sound.cry_spec(EraManager.NEWEST).get("wave", "")), "rich")

func test_era_cries_differ_and_get_longer() -> void:
	var sd: SpirlingData = Database.species("Kindlop")
	var plain: AudioStreamWAV = Cry.make(sd)
	assert_eq(Cry.make(sd, Sound.cry_spec(1)).data, plain.data, "Era I is unchanged")
	var prev: int = plain.data.size()
	for era: int in range(2, EraManager.NEWEST + 1):
		var w: AudioStreamWAV = Cry.make(sd, Sound.cry_spec(era))
		assert_ne(w.data, plain.data, "era %d" % era)
		assert_true(w.data.size() >= prev, "era %d cry is not shorter" % era)
		prev = w.data.size()
		var loud: int = 0
		for i: int in range(0, w.data.size(), 2):
			if absi(w.data.decode_s16(i)) > 1000:
				loud += 1
		assert_gt(loud, 100, "era %d cry is audible" % era)
	assert_lt(prev / 2.0 / Cry.RATE, 2.5, "Era V cry stays short")

func test_cry_cache_is_per_era() -> void:
	var sd: SpirlingData = Database.species("Kindlop")
	var a: AudioStreamWAV = Cry.stream_for(sd, 1, Sound.cry_spec(1))
	var b: AudioStreamWAV = Cry.stream_for(sd, 5, Sound.cry_spec(5))
	assert_ne(a, b)
	assert_eq(Cry.stream_for(sd, 5, Sound.cry_spec(5)), b)

func test_low_hp_alarm_per_era() -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	for era: int in range(1, EraManager.NEWEST + 1):
		var lh: Dictionary = Sound.era_spec(era).get("low_hp", {})
		assert_true(lh.has("repeat") and lh.has("max"), "era %d low_hp" % era)
	assert_gt(float(Sound.era_spec(1).low_hp.repeat), 0.0, "Era I beeps on a loop")
	assert_eq(float(Sound.era_spec(5).low_hp.repeat), 0.0, "Era V leaves it to the music")
	EraManager.retro_filter = 1
	Sound.last_sfx = ""
	Sound.battle_state(0.2, 1.0)
	assert_true(Sound.alarm_on)
	assert_eq(Sound.last_sfx, "low_hp")
	assert_eq(Sound.last_sfx_file, "low_hp")
	Sound.battle_state(0.6, 1.0)
	assert_false(Sound.alarm_on, "healed above the line")
	Sound.battle_state(0.2, 1.0)
	assert_true(Sound.alarm_on)
	Sound.music("route")
	assert_false(Sound.alarm_on, "leaving the battle music stops it")
	EraManager.retro_filter = 5
	Sound.battle_state(0.1, 0.9)
	assert_eq(Sound.last_sfx_file, "low_hp_era5")

func test_battle_intensity() -> void:
	assert_eq(Sound.battle_intensity(1.0, 1.0), 0)
	assert_eq(Sound.battle_intensity(0.8, 1.0), 1)
	assert_eq(Sound.battle_intensity(1.0, 0.4), 2)
	assert_eq(Sound.battle_intensity(0.3, 0.9), 2)

func test_era_five_battle_layers() -> void:
	assert_true(bool(Sound.era_spec(5).get("battle_layers", false)))
	for era: int in range(1, 5):
		assert_false(bool(Sound.era_spec(era).get("battle_layers", false)), "era %d" % era)
	for t: String in ["battle_era5", "warden_era5"]:
		assert_true(MusicDirector.has_stems(t), "%s has stems" % t)
	var saved_battle: bool = MusicDirector.battle
	var saved_level: int = MusicDirector.intensity
	var saved_stream: AudioStreamSynchronized = MusicDirector.active()
	MusicDirector.battle = false
	MusicDirector.set_active(MusicDirector.stream_for("battle_era5"), "battle_era5")
	assert_eq(MusicDirector.intensity, 0, "a new fight opens quietly")
	assert_eq(MusicDirector.target_gains(), PackedFloat32Array([1, 1, 0, 0]))
	MusicDirector.set_intensity(1)
	assert_eq(MusicDirector.target_gains(), PackedFloat32Array([1, 1, 1, 0]))
	MusicDirector.set_active(null, "battle_pinch_era5")
	assert_eq(MusicDirector.intensity, 1, "the pinch switch keeps the intensity")
	MusicDirector.set_intensity(5)
	assert_eq(MusicDirector.target_gains(), PackedFloat32Array([1, 1, 1, 1]))
	MusicDirector.set_active(saved_stream, "")
	assert_false(MusicDirector.battle)
	MusicDirector.battle = saved_battle
	MusicDirector.intensity = saved_level

func test_biome_ambience_for_eras_four_and_five() -> void:
	var yes: Callable = func(a: String) -> bool: return ResourceLoader.exists(Sound.AMBIENCE_DIR % a)
	for biome: String in ["town", "route", "marsh"]:
		assert_eq(Sound.biome_ambience(biome, true, 4, yes), "%s_era4" % biome)
		assert_eq(Sound.biome_ambience(biome, true, 5, yes), "%s_era5" % biome)
		assert_eq(Sound.biome_ambience(biome, true, 3, yes), "", "no biome loop before Era IV")
		assert_eq(Sound.biome_ambience(biome, false, 5, yes), "", "indoors stays quiet")
	assert_eq(Sound.biome_ambience("rift", true, 5, yes), "")
	var none: Callable = func(_a: String) -> bool: return false
	assert_eq(Sound.biome_ambience("town", true, 5, none), "", "missing file: no loop")

func test_halcyra_and_quivermoor_maps_get_ambience() -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = 4
	assert_eq(Sound.ambience_for_map("brightledge"), "town_era4")
	EraManager.retro_filter = 5
	assert_eq(Sound.ambience_for_map("hymnmarsh"), "marsh_era5")
	assert_eq(Sound.ambience_for_map("mossgate_moss_inn"), "", "interiors have no loop")
	assert_eq(Sound.ambience_for_map("lighthouse"), "sea", "a map's own loop wins")
	EraManager.retro_filter = 1
	assert_eq(Sound.ambience_for_map("brightledge"), "")

func test_era_files_are_logged_and_small() -> void:
	var log_text: String = FileAccess.get_file_as_string("res://docs/ASSET_LOG.md")
	var total: int = 0
	for era: int in range(2, EraManager.NEWEST + 1):
		for f: Variant in _sfx(era).values():
			var path: String = "audio/sfx/%s.wav" % f
			assert_string_contains(log_text, path)
			total += FileAccess.get_file_as_bytes("res://" + path).size()
	assert_lt(total, 2 * 1024 * 1024, "era sound sets are %d bytes" % total)
