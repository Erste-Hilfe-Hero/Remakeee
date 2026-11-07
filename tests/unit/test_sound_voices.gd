extends GutTest
## Plan area 6: ten effect voices where the least important sound gives way when all are busy
## (item 2551), and every effect loaded up front (item 2557).

func test_ten_voices() -> void:
	assert_eq(Sound.SFX_VOICES, 10)
	assert_eq(Sound._voices.size(), 10)

func test_priorities() -> void:
	assert_eq(Sound.priority_of("select"), Sound.PRIO_UI)
	assert_eq(Sound.priority_of("blip"), Sound.PRIO_UI)
	assert_eq(Sound.priority_of("step_grass_1"), Sound.PRIO_WORLD)
	assert_eq(Sound.priority_of("door_open"), Sound.PRIO_WORLD)
	assert_eq(Sound.priority_of("hit_ember"), Sound.PRIO_BATTLE)
	assert_eq(Sound.priority_of("travel_tide"), Sound.PRIO_BATTLE)
	assert_eq(Sound.priority_of("miss"), Sound.PRIO_BATTLE)

func test_free_voice_first() -> void:
	var busy: Array[bool] = [true, false, true]
	var prios: Array[int] = [1, 0, 1]
	assert_eq(Sound.pick_voice(busy, prios, 1, 0), 1)
	assert_eq(Sound.pick_voice([false, false, false] as Array[bool], [0, 0, 0] as Array[int], 2, 2), 2, "round robin from the next voice")

func test_least_important_gives_way() -> void:
	var busy: Array[bool] = [true, true, true]
	assert_eq(Sound.pick_voice(busy, [3, 1, 2] as Array[int], 3, 0), 1, "a battle hit pushes out a menu blip")
	assert_eq(Sound.pick_voice(busy, [3, 3, 2] as Array[int], 2, 0), 2, "a world sound only takes an equal one")
	assert_eq(Sound.pick_voice(busy, [3, 3, 3] as Array[int], 1, 0), -1, "a menu sound never cuts the battle")

func test_all_effects_preload() -> void:
	var n: int = Sound.preload_sfx()
	var files: int = 0
	for f: String in DirAccess.get_files_at("res://audio/sfx"):
		if f.ends_with(".wav"):
			files += 1
	assert_eq(n, files, "every effect is in the cache")

func test_effects_stay_under_two_megabytes() -> void:
	var total: int = 0
	for f: String in DirAccess.get_files_at("res://audio/sfx"):
		if f.ends_with(".wav"):
			total += FileAccess.get_file_as_bytes("res://audio/sfx/" + f).size()
	assert_lt(total, 2 * 1024 * 1024)
