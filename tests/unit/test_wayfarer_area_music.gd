extends GutTest
## KAMPF_PLAN_1000 item 560: a map Wayfarer's battle plays its area's own tune, in that area's era,
## after the Warden, challenge, festival and night themes of items 713-717.

func before_all() -> void:
	Database.load_all()

func _table() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/music.json"))

func test_every_region_has_a_small_wayfarer_tune() -> void:
	var t: Dictionary = _table()
	var way: Dictionary = t.wayfarer
	for region: String in (t.regions as Dictionary).keys():
		assert_true(way.has(region), "%s has a Wayfarer tune" % region)
	var seen: Dictionary = {}
	for region: String in way.keys():
		var track: String = str(way[region])
		assert_false(seen.has(track), "%s is used once" % track)
		seen[track] = true
		assert_true(ResourceLoader.exists(Sound.MUSIC_DIR % track), track)
		assert_between(FileAccess.get_file_as_bytes(Sound.MUSIC_DIR % track).size(), 1, 40 * 1024, track)
		assert_true(MusicDirector.is_battle_track(track), "%s counts as battle music" % track)
		assert_eq(BattleScene.pinch_track(null, track), track)
		assert_false(track in BattleAudio.THEMES, "%s is not one of the challenge themes" % track)
		assert_false(track in ["battle", "warden", "battle_pinch"])

func test_area_tune_only_in_the_region_era() -> void:
	var t: Dictionary = _table()
	assert_eq(BattleAudio.area_theme(t, "veydal", EraManager.Era.INK), "battle_wf_veydal")
	assert_eq(BattleAudio.area_theme(t, "veydal", EraManager.Era.WASH), "", "Era II keeps its era battle song")
	assert_eq(BattleAudio.area_theme(t, "vellmarch", EraManager.Era.WASH), "battle_wf_vellmarch")
	assert_eq(BattleAudio.area_theme(t, "quivermoor", EraManager.Era.LIVING), "battle_wf_quivermoor")
	assert_eq(BattleAudio.area_theme(t, "nowhere", EraManager.Era.INK), "")
	assert_eq(BattleAudio.area_theme({}, "veydal", EraManager.Era.INK), "")

func test_area_tune_comes_after_the_other_themes() -> void:
	var a: String = "battle_wf_corvane"
	assert_eq(BattleAudio.theme("", true, true, true, a), "warden", "a Warden keeps its own")
	assert_eq(BattleAudio.theme("tower", false, false, false, a), "battle_tower")
	assert_eq(BattleAudio.theme("", false, true, false, a), "battle_fest")
	assert_eq(BattleAudio.theme("", false, false, true, a), "battle_night")
	assert_eq(BattleAudio.theme("", false, false, false, a), a)
	assert_eq(BattleAudio.theme("", false, false, false), "battle", "no area tune, the plain song")

func test_only_map_wayfarers_ask_for_the_area_tune() -> void:
	var rng := RandomNumberGenerator.new()
	var bram: Dictionary = {"id": "bram", "trainer": "Ridgewalker Bram", "team": [{"species": "Shalebat", "level": 7}]}
	assert_true(bool(TrainerData.battle_info(bram, TrainerData.build_team(bram, "Kindlop", rng), 1).get("area_music", false)))
	var warden: Dictionary = bram.merged({"warden": "cinder"})
	assert_false(TrainerData.battle_info(warden, TrainerData.build_team(warden, "Kindlop", rng), 1).has("area_music"))
	var horde: Dictionary = bram.merged({"wild": true})
	assert_false(TrainerData.battle_info(horde, TrainerData.build_team(horde, "Kindlop", rng), 1).has("area_music"))
