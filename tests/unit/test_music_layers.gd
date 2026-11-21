extends GutTest
## Place songs, stems and the MusicDirector layers (plan area 6, items 2443, 2475 to 2479).

var _saved_motion: int
var _saved_dialogue: bool

func before_each() -> void:
	get_tree().paused = false
	_saved_motion = MusicDirector.motion
	_saved_dialogue = MusicDirector.dialogue

func after_each() -> void:
	MusicDirector.motion = _saved_motion as MusicDirector.Motion
	MusicDirector.dialogue = _saved_dialogue

## Maps with their own song in data/music.json. Maps added later play "default" until they get
## a song (test_sound checks that every map has some music).
func _maps() -> Array[String]:
	var out: Array[String] = []
	for k: String in (Sound._map_music.get("maps", {}) as Dictionary).keys():
		out.append(k)
	assert_gt(out.size(), 10)
	return out

func test_every_map_has_its_own_song() -> void:
	var seen: Dictionary = {}
	for map_id: String in _maps():
		var entry: Variant = Sound.map_entry(map_id)
		var track: String = str((entry as Dictionary).get("track", "")) if entry is Dictionary else str(entry)
		assert_ne(track, "route", "%s still plays the shared route song" % map_id)
		assert_false(seen.has(track), "%s shares %s with %s" % [map_id, track, seen.get(track, "")])
		seen[track] = map_id

func test_every_place_song_has_four_stems() -> void:
	for map_id: String in _maps():
		var track: String = Sound.track_for_map(map_id)
		assert_true(MusicDirector.has_stems(track), "%s has no stems" % track)
		for stem: String in MusicDirector.STEMS:
			assert_true(ResourceLoader.exists(MusicDirector.STEM_DIR % [track, stem]), "%s_%s missing" % [track, stem])

func test_stream_for_builds_looping_sync() -> void:
	var s: AudioStreamSynchronized = MusicDirector.stream_for("lighthouse")
	assert_not_null(s)
	assert_eq(s.stream_count, 4)
	for i: int in 4:
		var st: AudioStreamOggVorbis = s.get_sync_stream(i) as AudioStreamOggVorbis
		assert_not_null(st)
		assert_true(st.loop)
	assert_same(MusicDirector.stream_for("lighthouse"), s, "cached")
	assert_null(MusicDirector.stream_for("battle"), "battle music has no stems")

func test_track_for_map_reads_dict_entries() -> void:
	var saved: Dictionary = Sound._map_music
	Sound._map_music = {"default": "route", "maps": {"x": {"track": "town", "ambience": "wind"}, "y": "title"}}
	assert_eq(Sound.track_for_map("x"), "town")
	assert_eq(Sound.track_for_map("y"), "title")
	assert_eq(Sound.track_for_map("nowhere"), "route")
	Sound._map_music = saved

func test_motion_layers() -> void:
	MusicDirector.dialogue = false
	MusicDirector.motion = MusicDirector.Motion.IDLE
	assert_eq(Array(MusicDirector.target_gains()), [1.0, 1.0, 0.0, 0.0])
	MusicDirector.motion = MusicDirector.Motion.WALK
	assert_eq(Array(MusicDirector.target_gains()), [1.0, 1.0, 1.0, 0.0])
	MusicDirector.motion = MusicDirector.Motion.RUN
	assert_eq(Array(MusicDirector.target_gains()), [1.0, 1.0, 1.0, 1.0])

func test_dialogue_dips_melody_and_drums() -> void:
	MusicDirector.motion = MusicDirector.Motion.RUN
	MusicDirector.dialogue = true
	var g: PackedFloat32Array = MusicDirector.target_gains()
	assert_eq(g[0], 1.0)
	assert_almost_eq(linear_to_db(g[2]), MusicDirector.DIALOGUE_DB, 0.1)
	assert_almost_eq(linear_to_db(g[3]), MusicDirector.DIALOGUE_DB, 0.1)

func test_single_step_keeps_melody() -> void:
	MusicDirector.motion = MusicDirector.Motion.WALK
	MusicDirector.update_world(false, false, 0.2)
	assert_eq(MusicDirector.motion, MusicDirector.Motion.WALK)
	MusicDirector.update_world(false, false, 0.3)
	assert_eq(MusicDirector.motion, MusicDirector.Motion.IDLE)
	MusicDirector.update_world(true, true, 0.016)
	assert_eq(MusicDirector.motion, MusicDirector.Motion.RUN)

func test_fade_takes_fade_time() -> void:
	var saved: AudioStreamSynchronized = MusicDirector.active()
	MusicDirector.dialogue = false
	MusicDirector.motion = MusicDirector.Motion.RUN
	MusicDirector.set_active(MusicDirector.stream_for("lighthouse"))
	assert_almost_eq(MusicDirector.stem_db(3), 0.0, 0.01)
	MusicDirector.motion = MusicDirector.Motion.IDLE
	MusicDirector.step(MusicDirector.FADE_TIME / 2.0)
	assert_almost_eq(MusicDirector.gains[3], 0.5, 0.01, "half way after half the fade")
	assert_almost_eq(MusicDirector.gains[0], 1.0, 0.01, "bass stays")
	MusicDirector.step(MusicDirector.FADE_TIME / 2.0)
	assert_eq(MusicDirector.stem_db(3), MusicDirector.SILENT_DB)
	MusicDirector.set_active(saved)
