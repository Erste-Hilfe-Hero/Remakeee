class_name StoryBattles
extends RefCounted
## Story duels that start from a dialogue or scene step ("battle <id>", plan item 1340).
## data/story_battles.json maps an id to a Wayfarer definition in the map format (see
## TrainerData): "trainer", "team" or "team_by_starter", "front", "partner", "ai", "money",
## plus "defeat" / "lose" (dialogue refs played after a win / a loss) and "win_flags".

const PATH: String = "res://data/story_battles.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {}
	return _data

static func has(id: String) -> bool:
	return data().get(id) is Dictionary

static func get_def(id: String) -> Dictionary:
	var d: Variant = data().get(id)
	return d if d is Dictionary else {}

## Flag set once the story duel [param id] is won.
static func beaten_flag(id: String) -> String:
	return str(get_def(id).get("beaten_flag", "beat_story_%s" % id))
