class_name EraActivities
extends RefCounted
## data/era_activities.json: tuning of Kinship (Era II), the Showcase (Era III), the Dig site
## (Era IV) and wheel battles (Era V).

const PATH: String = "res://data/era_activities.json"

static var _data: Dictionary = {}

static func section(key: String) -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = raw if raw is Dictionary else {}
	var d: Variant = _data.get(key, {})
	return d if d is Dictionary else {}

static func wheel_size() -> int:
	return clampi(int(section("wheel").get("size", 3)), 2, BattleModel.MAX_PARTY)
