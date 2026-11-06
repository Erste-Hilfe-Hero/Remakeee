class_name StoryPlacements
extends RefCounted
## Story figures and signs placed on maps from outside the map files (plan area 4):
## data/story_npcs.json maps a map id to {"npcs": [...], "signs": [...]} in the map format.
## Area 3 builds the maps; the story adds its people and triggers here, so a figure appears
## as soon as its map exists, and nobody has to edit someone else's map file.

const PATH: String = "res://data/story_npcs.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {}
	return _data

static func for_map(map_id: String) -> Dictionary:
	var d: Variant = data().get(map_id)
	return d if d is Dictionary else {}

## Adds the story figures and signs for [param m] (called by MapData.load_map).
static func apply(m: MapData) -> void:
	var extra: Dictionary = for_map(m.id)
	for n: Variant in extra.get("npcs", []):
		if n is Dictionary:
			m.npcs.append((n as Dictionary).duplicate(true))
	for s: Variant in extra.get("signs", []):
		if s is Dictionary:
			m.signs.append((s as Dictionary).duplicate(true))
