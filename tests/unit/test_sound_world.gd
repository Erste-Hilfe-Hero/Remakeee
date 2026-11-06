extends GutTest
## Buses, limiter, ambience, footsteps, text voice and sound captions (plan area 6, items
## 2501 to 2504, 2547 to 2550, 2569 to 2571, 2653).

func before_each() -> void:
	get_tree().paused = false

func test_sub_buses_feed_sfx() -> void:
	GameState.ensure_buses()
	for bus: StringName in [GameState.BUS_UI, GameState.BUS_VOICE, GameState.BUS_AMBIENCE]:
		var i: int = AudioServer.get_bus_index(bus)
		assert_true(i >= 0, "%s bus missing" % bus)
		assert_eq(AudioServer.get_bus_send(i), GameState.BUS_SFX)

func test_master_limiter_once() -> void:
	GameState.ensure_buses()
	GameState.ensure_buses()
	var limiters: int = 0
	for i: int in AudioServer.get_bus_effect_count(0):
		var e: AudioEffect = AudioServer.get_bus_effect(0, i)
		if e is AudioEffectHardLimiter:
			limiters += 1
			assert_almost_eq((e as AudioEffectHardLimiter).ceiling_db, -1.0, 0.01)
	assert_eq(limiters, 1)

func test_ios_session_is_ambient() -> void:
	assert_eq(int(ProjectSettings.get_setting("audio/general/ios/session_category")), 0, "Ambient")
	assert_true(bool(ProjectSettings.get_setting("audio/general/ios/mix_with_others")))

func test_bus_routing() -> void:
	assert_eq(Sound.bus_for("confirm"), GameState.BUS_UI)
	assert_eq(Sound.bus_for("blip"), GameState.BUS_VOICE)
	assert_eq(Sound.bus_for("hit"), GameState.BUS_SFX)

func test_pause_mutes_and_resume_fades_in() -> void:
	var vol: float = GameState.volume
	Sound.app_paused()
	assert_eq(GameState.master_fade, 0.0)
	assert_lt(AudioServer.get_bus_volume_db(0), -70.0)
	Sound.app_resumed()
	await wait_seconds(Sound.RESUME_FADE + 0.15)
	assert_almost_eq(GameState.master_fade, 1.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(0), linear_to_db(vol), 0.05)

func test_outdoor_maps_have_ambience_files() -> void:
	var outdoor: Array[String] = ["lighthouse", "brindlewick", "fernstair", "crowcrest", "saltmarsh", "thornridge"]
	for map_id: String in outdoor:
		var a: String = Sound.ambience_for_map(map_id)
		assert_ne(a, "", "%s has no ambience" % map_id)
		assert_true(ResourceLoader.exists(Sound.AMBIENCE_DIR % a), "%s missing" % a)
		assert_eq(Sound.track_for_map(map_id), map_id, "dict entry still names the song")
	assert_eq(Sound.ambience_for_map("map_house"), "")
	assert_eq(Sound.ambience_for_map("tide_rift"), "")

func test_ambience_loop_lengths() -> void:
	for f: String in ResourceLoader.list_directory("res://audio/ambience"):
		if not f.ends_with(".ogg"):
			continue
		var s: AudioStream = load("res://audio/ambience/" + f)
		assert_between(s.get_length(), 30.0, 45.5, f)

func test_footstep_grounds() -> void:
	var K := TilesetFactory.Kind
	assert_eq(Sound.ground_for(K.GRASS, false), "grass")
	assert_eq(Sound.ground_for(K.PATH, false), "path")
	assert_eq(Sound.ground_for(K.FLOOR, false), "wood")
	assert_eq(Sound.ground_for(K.PATH, true), "sand")
	assert_eq(Sound.ground_for(K.SCREE, false), "stone")
	assert_eq(Sound.ground_for(K.REEDS, false), "shore")
	for g: String in ["grass", "path", "wood", "sand", "stone", "shore"]:
		for take: int in [1, 2]:
			var path: String = Sound.SFX_DIR % ("step_%s_%d" % [g, take])
			assert_true(ResourceLoader.exists(path), path)
			assert_lt((load(path) as AudioStream).get_length(), 0.06, path)

func test_voice_per_speaker() -> void:
	assert_eq(Sound.voice_for(""), "player")
	assert_eq(Sound.voice_for("kestra_dock"), "kestra")
	assert_eq(Sound.voice_for("aldo"), "aldo")
	assert_eq(Sound.voice_for("warden_orrin"), "warden")
	assert_eq(Sound.voice_for("fisher"), "villager")
	assert_eq(TextBox.voice_for_line("Kestra: Oh, hello.", "villager"), "kestra")
	assert_eq(TextBox.voice_for_line("Mirela: A note.", "player"), "mirela")
	assert_eq(TextBox.voice_for_line("Note: nothing here.", "player"), "player")
	var pitches: Dictionary = {}
	for k: String in Sound.VOICE_PITCH:
		pitches[Sound.VOICE_PITCH[k]] = k
	assert_eq(pitches.size(), Sound.VOICE_PITCH.size(), "every speaker sounds different")
	var blip: AudioStream = load(Sound.SFX_DIR % "blip")
	assert_almost_eq(blip.get_length(), 0.015, 0.003)

func test_captions_only_when_on() -> void:
	var saved: bool = GameState.sound_captions
	Sound.captions.clear()
	GameState.sound_captions = false
	Sound.caption("encounter")
	assert_eq(Sound.captions.size(), 0)
	GameState.sound_captions = true
	Sound.caption("encounter")
	Sound.caption("hit")
	assert_eq(Sound.captions, ["[Rustling in the grass]"])
	GameState.sound_captions = saved

func test_new_settings_round_trip() -> void:
	GameState.settings_from_dict({"sound_captions": true, "text_voice": false})
	var d: Dictionary = GameState.settings_to_dict()
	assert_true(bool(d.sound_captions))
	assert_false(bool(d.text_voice))
	GameState.settings_from_dict({})
	assert_false(GameState.sound_captions)
	assert_true(GameState.text_voice)

func test_battle_music_ducks_ambience() -> void:
	var track: String = Sound.current_track
	Sound.enter_map("lighthouse")
	assert_eq(Sound.current_ambience, "sea")
	assert_false(Sound.ambience_ducked)
	Sound.music("battle")
	assert_eq(Sound.current_ambience, "sea", "kept, only lowered")
	assert_true(Sound.ambience_ducked)
	Sound.enter_map("lighthouse")
	assert_false(Sound.ambience_ducked)
	Sound.music("title")
	assert_eq(Sound.current_ambience, "")
	Sound.music(track)
