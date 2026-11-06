class_name SpirlogLore
extends RefCounted
## Second Spirlog line per species (plan item 1706): read from data/spirlog_lore.json and
## shown in the Spirlog once the species is bonded. It ties each species to the Rifts and
## the regions of the story.

const PATH: String = "res://data/spirlog_lore.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {}
	return _data

## The line for [param species], or "" if it has none.
static func line(species: String) -> String:
	var v: Variant = data().get(species)
	return str(v) if v is String else ""
