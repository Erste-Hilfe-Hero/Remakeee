extends GutTest
## Era III: unlocks after Era II via data/eras.json, and its sprites resolve from art/era3/.

var _unlocked: int
var _retro: int

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter

func after_each() -> void:
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)

func _set_era(e: int) -> void:
	EraManager.unlocked_era = e
	EraManager.set_retro_filter(0)

func _flags(names: Array) -> Callable:
	return func(f: String) -> bool: return names.has(f)

func test_flags_come_from_data() -> void:
	var flags: Dictionary = EraManager.unlock_flags()
	assert_eq(str(flags.get("2", "")), EraManager.STORY_COMPLETE_FLAG)
	assert_false(str(flags.get("3", "")).is_empty())

func test_era3_follows_era2() -> void:
	var era2_flag: String = str(EraManager.unlock_flags()["3"])
	_set_era(EraManager.Era.INK)
	EraManager.unlock_from_flags(_flags([era2_flag]))
	assert_eq(EraManager.unlocked_era, EraManager.Era.INK, "no Era III before Era II")
	EraManager.unlock_from_flags(_flags([EraManager.STORY_COMPLETE_FLAG]))
	assert_eq(EraManager.unlocked_era, EraManager.Era.WASH)
	EraManager.unlock_from_flags(_flags([EraManager.STORY_COMPLETE_FLAG, era2_flag]))
	assert_eq(EraManager.unlocked_era, EraManager.Era.ETCHED)

func test_era3_art_paths_and_fallback() -> void:
	_set_era(EraManager.Era.ETCHED)
	assert_eq(EraManager.art_path("spirlings/vesk_front.png"), "res://art/era3/spirlings/vesk_front.png")
	assert_eq(EraManager.art_path("tiles/overworld.png"), "res://art/era2/tiles/overworld.png")
	assert_eq(EraManager.battle_sprite_size(), 64)

func test_starting_set_sprites_exist() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/eras.json"))
	var starting: Array = d["era3"]["starting_set"]
	assert_eq(starting.size(), 9)
	for sp: Dictionary in starting:
		for facing: String in ["front", "back"]:
			var path: String = "res://art/era3/spirlings/%s_%s.png" % [sp["id"], facing]
			assert_true(ResourceLoader.exists(path) or FileAccess.file_exists(path), path)
