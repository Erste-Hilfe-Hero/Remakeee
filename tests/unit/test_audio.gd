extends GutTest
## Audio items 66, 67, 69, 70, 71: era music lookup, element hit sounds, pinch music,
## synthesized cries and the sound test lists.

func before_all() -> void:
	Database.load_all()

func test_every_element_has_a_hit_sound() -> void:
	for el: int in Elements.E.values():
		var n: String = Sound.element_hit_name(el)
		assert_true(ResourceLoader.exists("res://audio/sfx/%s.wav" % n), n)
	assert_eq(Sound.element_hit_name(-1), "hit")

func test_era_track_prefers_newest_existing_variant() -> void:
	var have: Array[String] = ["town_era2"]
	var exists: Callable = func(t: String) -> bool: return t in have
	assert_eq(Sound.era_track("town", 1, exists), "town")
	assert_eq(Sound.era_track("town", 2, exists), "town_era2")
	assert_eq(Sound.era_track("town", 4, exists), "town_era2", "falls back to the newest older variant")
	assert_eq(Sound.era_track("route", 3, exists), "route")
	assert_eq(Sound.era_track("", 3, exists), "")

func test_pinch_track_follows_hp() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 20)
	assert_eq(BattleScene.pinch_track(s, "battle"), "battle")
	s.hp = int(s.max_hp() * 0.25)
	assert_eq(BattleScene.pinch_track(s, "warden"), "battle_pinch")
	s.hp = 0
	assert_eq(BattleScene.pinch_track(s, "battle"), "battle", "no pinch music for a fainted Spirling")
	assert_true(ResourceLoader.exists("res://audio/music/battle_pinch.ogg"))

func test_cries_are_distinct_and_stable() -> void:
	var shapes: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		var a: Dictionary = Cry.shape(sd)
		var b: Dictionary = Cry.shape(sd)
		assert_eq(a, b, "same species, same cry")
		var key: String = "%.2f|%d" % [float(a.base), (a.segments as Array).size()]
		assert_false(shapes.has(key) and shapes[key] == a.segments, sd.species_name)
		shapes[key] = a.segments

func test_evolved_forms_call_lower() -> void:
	var low_total: float = 0.0
	var high_total: float = 0.0
	var n_low: int = 0
	var n_high: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		if BalanceSim.stage(sd) == 1:
			high_total += float(Cry.shape(sd).base)
			n_high += 1
		else:
			low_total += float(Cry.shape(sd).base)
			n_low += 1
	assert_lt(low_total / n_low, high_total / n_high)

func test_cry_stream_is_short_pcm() -> void:
	var w: AudioStreamWAV = Cry.make(Database.species("Kindlop"))
	assert_eq(w.format, AudioStreamWAV.FORMAT_16_BITS)
	var seconds: float = w.data.size() / 2.0 / w.mix_rate
	assert_between(seconds, 0.1, 1.0)
	var loud: int = 0
	for i: int in range(0, w.data.size(), 2):
		if absi(w.data.decode_s16(i)) > 1000:
			loud += 1
	assert_gt(loud, 100, "the cry is audible")

func test_sound_test_lists() -> void:
	var music: Array[String] = Sound.list_sounds("res://audio/music/")
	assert_has(music, "battle")
	assert_has(music, "battle_pinch")
	var fx: Array[String] = Sound.list_sounds("res://audio/sfx/")
	assert_has(fx, "hit_volt")
	var before: Dictionary = GameState.spirlog.duplicate(true)
	GameState.spirlog.clear()
	assert_eq(MenuHost.sound_test_cries().size(), 0)
	GameState.mark_seen("Puddlet")
	GameState.mark_seen("Kindlop")
	var cries: Array[SpirlingData] = MenuHost.sound_test_cries()
	assert_eq(cries.size(), 2)
	assert_lt(cries[0].dex_id, cries[1].dex_id)
	GameState.spirlog = before
