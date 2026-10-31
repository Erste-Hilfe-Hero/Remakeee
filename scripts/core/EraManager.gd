extends Node
## Each region = a visual generation jump (Era I Mono -> IV Dual).
signal era_changed(era: int)
enum Era { MONO = 1, COLOR = 2, ADVANCED = 3, DUAL = 4 }
const REGION_ERA := {"veydal": Era.MONO, "corvane": Era.COLOR, "ashmere": Era.ADVANCED, "solenne": Era.DUAL}
const RESOLUTION := {Era.MONO: Vector2i(144, 256), Era.COLOR: Vector2i(144, 256), Era.ADVANCED: Vector2i(180, 320), Era.DUAL: Vector2i(270, 480)}

var unlocked_era: int = Era.MONO
var retro_filter: int = 0   # 0 = use newest unlocked era

func active_era() -> int:
	return retro_filter if retro_filter > 0 else unlocked_era

func unlock_region(region: String) -> void:
	var e: int = REGION_ERA.get(region, Era.MONO)
	if e > unlocked_era:
		unlocked_era = e
		_apply()

func set_retro_filter(e: int) -> void:
	retro_filter = clamp(e, 0, unlocked_era)
	_apply()

func sprite_path(species: String) -> String:
	return "res://art/era%d/spirlings/%s.png" % [active_era(), species.to_lower()]

func _apply() -> void:
	get_window().content_scale_size = RESOLUTION[active_era()]
	era_changed.emit(active_era())
