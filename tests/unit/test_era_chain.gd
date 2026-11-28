extends GutTest
## Era chain I -> V: Era V in EraManager, the Era II finale flag, Era IV breath frames.

var _unlocked: int
var _retro: int

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter

func after_each() -> void:
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)

func _flags(names: Array) -> Callable:
	return func(f: String) -> bool: return names.has(f)

func test_era5_has_resolution_size_and_line() -> void:
	var e: int = EraManager.Era.LIVING
	assert_eq(e, 5)
	assert_true(EraManager.RESOLUTION.has(e))
	assert_true(EraManager.BATTLE_SPRITE_SIZE.has(e))
	assert_eq(EraManager.ERA_LINES[e], BattleAnim.UNLOCK_LINE)

func test_save_load_keeps_era5() -> void:
	EraManager.from_dict({"unlocked_era": 5, "retro_filter": 0})
	assert_eq(EraManager.unlocked_era, 5)
	assert_eq(EraManager.active_era(), 5)
	EraManager.from_dict({"unlocked_era": 9})
	assert_eq(EraManager.unlocked_era, 5)

func test_flags_chain_to_era5() -> void:
	var f: Dictionary = EraManager.unlock_flags()
	var all: Array = []
	for e: int in range(2, 6):
		assert_false(str(f.get(str(e), "")).is_empty(), "era %d flag" % e)
		all.append(str(f[str(e)]))
	EraManager.unlocked_era = EraManager.Era.INK
	EraManager.set_retro_filter(0)
	EraManager.unlock_from_flags(_flags(all))
	assert_eq(EraManager.unlocked_era, 5)

func test_era2_finale_sets_era3_flag() -> void:
	var flags: Dictionary = {}
	EraManager.mark_finales(flags)
	assert_false(flags.has("era2_finale_done"))
	flags["vellmarch_done"] = true
	EraManager.mark_finales(flags)
	assert_true(flags.get("era2_finale_done", false))
	assert_eq(str(EraManager.unlock_flags()["3"]), "era2_finale_done")

func test_breath_path() -> void:
	assert_eq(SpirlingSprite.breath_path("res://art/era4/spirlings/a_front.png"), "res://art/era4/spirlings/a_front_b.png")
	assert_eq(SpirlingSprite.breath_path("res://art/era3/spirlings/a_front.png"), "")
	assert_eq(SpirlingSprite.breath_path(""), "")
